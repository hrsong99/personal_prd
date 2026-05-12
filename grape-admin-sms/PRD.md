# PRD: Grape Admin SMS 발송 기능

## Overview

Internal teams currently have no way to send a one-off SMS to a specific student from inside grape admin — for CS escalations, payment reminders, or any moment a Kakao Alimtalk template doesn't fit. This PRD adds a single-entry "문자 보내기" capability on the student details page, plus the admin pages needed to make that flow auditable and maintainable.

The feature **wraps the existing NHN Cloud SMS sender** (`inc/podo_sms_sender.php`) rather than building a new integration. Grape already speaks to NHN for SMS, LMS, and Alimtalk; this PRD layers a UI-driven send path and an audit log on top.

This is a **net-new admin capability, not a replacement** of anything. The existing alimtalk flow (`admin/marketing/manual_alimtalk.php`) and the existing programmatic SMS calls (from sales process, payment flows, etc.) are unchanged.

---

## Goals

1. From the student details page (`admin/podo_students.php?USER_ID=X&mode=U`), any grape admin can open a "문자 보내기" popup and send an SMS to that student in 2–3 clicks.
2. Templates with variable substitution (`{{student_name}}`, `{{phone}}`, `{{user_id}}`, `{{수강권_name}}`) let the team send consistent messages quickly, while the body remains freely editable before send.
3. Messages over the 90-byte SMS limit auto-upgrade to LMS transparently, with a UI badge so the admin knows the cost tier.
4. Every send is recorded — recipient, body, sender number, sending admin, delivery status — and is browsable on a Sent SMS Log page with filters (date, user_id, user_name, sending admin).
5. SMS templates and sender numbers are admin-manageable through dedicated CRUD pages, so the team can self-serve without code deploys.
6. The feature is fully contained inside grape (PHP) — no podo-backend (Kotlin) involvement.

## Non-Goals (V1)

- **No additional entry points.** The "문자 보내기" button only appears on the student details page. No bulk send, no list-page send, no scheduled send.
- **No MMS / image attachments.** Text-only.
- **No role-based permission gating.** All grape admins can send and view logs. (Existing grape access control = sufficient.)
- **No per-team / per-role default sender number.** One shared default for everyone in V1.
- **No new podo-backend service or API.** Grape calls NHN directly via the existing wrapper.
- **No retention policy / auto-purge.** Sent-SMS log records are kept indefinitely.
- **No webhook endpoint for delivery callbacks.** Mechanism is deferred to dev (likely polling for V1, see §10).
- **No email as a template variable.** Variable set is the fixed shortlist above.
- **No expanded variable namespace.** Only the four listed variables substitute; anything else stays literal.

---

## Glossary

| Term | Meaning |
|---|---|
| **Grape admin** | The internal PHP admin tool at `grape.re-speak.com/admin/`. Procedural PHP 7+, mysqli, Bootstrap 3 + jQuery. |
| **NHN Toast SMS** | NHN Cloud's SMS/LMS service. Endpoint pattern: `https://api-sms.cloud.toast.com/sms/v2.3/appKeys/<appKey>/sender/{sms,lms}`. Credentials live in `.env` as `CONF_TOAST_APP_KEY` and `CONF_TOAST_SECRET_KEY`. |
| **SMS** | Short message, ≤ 90 bytes (~45 한글 / ~90 English chars). Cheaper rate. |
| **LMS** | Long message, > 90 bytes up to ~2,000 bytes (~1,000 한글). Different NHN endpoint, ~3× the per-message rate. |
| **Sender number** | A phone number pre-registered with NHN that can appear in the SMS "From" field. Grape will store these in a new DB table. |
| **Template variable** | A `{{...}}` placeholder in a template body that is replaced with student data at the moment the admin selects the template. |
| **Sending admin** | The grape user account that triggered the send (`$_SESSION['user_admin_id']`, `$_SESSION['user_admin_email']`). |

---

## User Stories

| As a... | I want to... | So that... |
|---|---|---|
| Grape admin on a student page | Click a single "문자 보내기" button | I can text that student without leaving the page |
| Grape admin in the send popup | See the student's name, user_id, and phone pre-filled and read-only | I don't risk sending to the wrong person |
| Grape admin in the send popup | Pick a sender number from a dropdown (with a sensible default) | I don't have to remember which number is registered |
| Grape admin in the send popup | Pick a template from a dropdown and have the body auto-fill with the student's data already substituted in | I can send a consistent, personalized message in seconds |
| Grape admin in the send popup | Edit the body after a template is applied | I can tweak wording for the specific student |
| Grape admin sending a long message | See a character counter and an "LMS" badge when I'm past the SMS limit | I know I'm about to send the more expensive tier and can decide whether to trim |
| Grape admin clicking Send | See a confirmation dialog before the SMS actually goes out | I'm protected from accidental clicks |
| Grape admin when a send fails | See an inline error in the popup and a Retry button that re-uses my current body | I can recover without re-typing |
| Grape admin auditing past sends | Open a Sent SMS Log page and filter by date / user_id / user_name / sending admin | I can answer "did we already text this person?" or "what did Alice send yesterday?" |
| Grape admin maintaining templates | Add, edit, and soft-delete templates on a dedicated page | The team keeps a curated library without code deploys |
| Grape admin maintaining sender numbers | Add, edit, set-default, and toggle-active sender numbers on a dedicated page | The team can self-serve when NHN-registered numbers change |

---

## Functional Requirements

### 1. Entry point: 문자 보내기 button

- A **"문자 보내기"** button is added to the top-row button strip of the student details page (`admin/podo_students.php`, around lines 1170–1173, alongside "포도계정 생성" / "QA 계정 일괄 생성").
- Click opens a **Bootstrap modal popup** in-page (same pattern as other inline actions like `notification_manual_send.php`). No `window.open`, no navigation.
- The modal is keyed by `USER_ID` from the page's `$_REQUEST['USER_ID']`.

### 2. Send popup contents

The modal renders, top to bottom:

1. **Recipient block (read-only)**
   - 이름 (student_name)
   - User ID
   - 휴대폰 (phone number, normalized)
2. **Sender number dropdown** — list of `is_active = 1` rows from `SMS_SENDER_NUMBER`; the `is_default = 1` row is pre-selected.
3. **Template dropdown** — list of `is_active = 1` rows from `SMS_TEMPLATE`. Selecting a template:
   - Loads the template body into the message textarea
   - Replaces each supported variable with the student's data
   - Variable set in V1: `{{student_name}}`, `{{phone}}`, `{{user_id}}`, `{{수강권_name}}`
   - If a variable's source field is null/empty for that student, the literal `{{...}}` placeholder is left in the body so the admin sees it and can edit
   - Unrecognized variables (anything outside the fixed shortlist) are left literal — no error
4. **Message textarea** — editable. Default state is empty (no template selected); selecting a template overwrites it.
5. **Character counter + tier badge** — shows current byte count and either an "SMS" or "LMS" badge:
   - 0–90 bytes → **SMS** badge
   - 91+ bytes → **LMS** badge (with a small "LMS — 약 3배 요금" hint on hover)
   - At 2,000 bytes the Send button is disabled
6. **Send button** — triggers the confirm dialog (§3).
7. **Cancel button** — closes the modal, discarding the draft.

### 3. Confirmation dialog

- After clicking Send, a second modal asks **"정말 발송하시겠습니까?"** with the recipient's name + phone visible.
- Buttons: **발송** (primary) and **취소** (secondary).
- Only on **발송** click does the SMS actually fire.

### 4. Sending mechanism

- The PHP send handler **wraps `inc/podo_sms_sender.php`** rather than reimplementing the NHN call.
- The wrapper chooses the right NHN endpoint based on body length:
  - ≤ 90 bytes → SMS endpoint (`/sender/sms`)
  - > 90 bytes → LMS endpoint (`/sender/lms`)
- The wrapper must add LMS endpoint support if `podo_sms_sender.php` currently exposes SMS only. (Existing code review during implementation will confirm scope.)
- Credentials are reused from `.env` (`CONF_TOAST_APP_KEY`, `CONF_TOAST_SECRET_KEY`). No new credentials.
- On NHN HTTP success, the row is written to `SMS_SENT_LOG` with status `pending` (delivery not yet confirmed).
- On NHN HTTP failure (non-2xx response, network error, timeout), the row is still written with status `api_failed` and the NHN error code/message captured, **and** an inline error is rendered in the popup with a Retry button. Retry re-submits with the current form values; no new draft state is required.

### 5. Sent SMS log page

- New page at `admin/sms/sent_log.php` (path TBD by dev — see §8).
- Linked from the new top-level **SMS** sidebar section in `inc/admin_sidebar.php`.
- Default view: most recent 50 sends, paginated.
- **Filters** (combinable):
  - Sent date range (from / to)
  - User ID (exact match)
  - User name (LIKE)
  - Sending admin (dropdown of admins who have sent at least once)
  - Delivery status (sent / delivered / failed / pending / api_failed)
- **Columns**:
  - 발송 일시 (created_at)
  - 보낸 사람 (sending admin email/name)
  - 받는 사람 (student name + user_id + phone)
  - 발신 번호
  - 본문 (truncated, click to expand)
  - 유형 (SMS / LMS)
  - 발송 상태 (delivered / failed / pending / api_failed)
  - 템플릿 (template name if used, else "직접 작성")
- Each row is read-only; no edit, no resend from log page in V1.

### 6. SMS template management page

- New page at `admin/sms/templates.php` (path TBD).
- Linked from the SMS sidebar section.
- List view shows: 템플릿 이름, 본문 미리보기, 생성자, 마지막 수정자, 마지막 수정 일시, 활성 여부.
- Filter: active only (toggle), search by name.
- CRUD actions: **추가** (modal), **수정** (modal), **비활성화** (soft-delete: sets `is_active = 0`).
- A soft-deleted template is hidden from the send popup's dropdown but its name remains resolvable from the log (via FK; see §9.2).
- Variable picker UI: while editing a template body, an "변수 추가" helper shows the four supported variable tokens that can be inserted.

### 7. Sender number management page

- New page at `admin/sms/sender_numbers.php` (path TBD).
- Linked from the SMS sidebar section.
- List view: 발신 번호, 설명/라벨, 기본 여부, 활성 여부.
- CRUD: **추가**, **수정**, **활성/비활성 토글**, **기본 지정** (radio; setting one as default un-defaults the others atomically).
- Only `is_active = 1` numbers appear in the send popup dropdown.
- Exactly one `is_default = 1` row at any time (enforced in app code; see §9.1).

### 8. Sidebar nav placement

- A new top-level **SMS** section in `inc/admin_sidebar.php`, with three sub-links:
  1. 발송 로그 (sent log)
  2. 템플릿 관리 (templates)
  3. 발신 번호 관리 (sender numbers)
- The new section is sibling to existing top-level sections (마케팅, 영업, etc.); the exact ordering is dev's call.

---

## Data Model

All new tables live in grape's existing DB. Schema migration is hand-applied SQL files in `admin/sql/` per grape convention (see §11).

### 9.1 `SMS_SENDER_NUMBER`

| Column | Type | Notes |
|---|---|---|
| `id` | INT AUTO_INCREMENT PK | |
| `phone_number` | VARCHAR(20) NOT NULL UNIQUE | Pre-registered with NHN; stored in NHN-accepted format (e.g. `15881234`, `010-1234-5678`) |
| `label` | VARCHAR(100) NOT NULL | Human-readable description (e.g. "CS 대표번호") |
| `is_default` | TINYINT(1) NOT NULL DEFAULT 0 | Exactly one row has `1` at any time; enforced in app code |
| `is_active` | TINYINT(1) NOT NULL DEFAULT 1 | |
| `created_at` | DATETIME NOT NULL | |
| `updated_at` | DATETIME NOT NULL | |

### 9.2 `SMS_TEMPLATE`

| Column | Type | Notes |
|---|---|---|
| `id` | INT AUTO_INCREMENT PK | |
| `name` | VARCHAR(100) NOT NULL | Displayed in the send popup dropdown |
| `body` | TEXT NOT NULL | Contains `{{variable}}` placeholders |
| `is_active` | TINYINT(1) NOT NULL DEFAULT 1 | Soft-delete flag |
| `created_by` | INT NOT NULL | FK → `GT_ADMIN.id` (the admin_id) |
| `updated_by` | INT NOT NULL | FK → `GT_ADMIN.id` |
| `created_at` | DATETIME NOT NULL | |
| `updated_at` | DATETIME NOT NULL | |

### 9.3 `SMS_SENT_LOG`

| Column | Type | Notes |
|---|---|---|
| `id` | BIGINT AUTO_INCREMENT PK | |
| `recipient_user_id` | INT NOT NULL | Snapshot of the target's `USER_ID` |
| `recipient_name` | VARCHAR(100) | Snapshot at send time (student may rename later) |
| `recipient_phone` | VARCHAR(20) NOT NULL | The actual number we sent to |
| `sender_number` | VARCHAR(20) NOT NULL | The "from" number used |
| `body` | TEXT NOT NULL | The rendered body (after variable substitution + admin edits) — the actual text NHN received |
| `message_type` | ENUM('SMS','LMS') NOT NULL | Determined by body length at send time |
| `template_id` | INT NULL | FK → `SMS_TEMPLATE.id`; NULL if admin sent a freeform message |
| `delivery_status` | ENUM('pending','delivered','failed','api_failed') NOT NULL DEFAULT 'pending' | `api_failed` = NHN call itself failed; `failed` = NHN accepted but the carrier reported non-delivery |
| `nhn_request_id` | VARCHAR(100) NULL | NHN's message ID for status lookup |
| `nhn_error_code` | VARCHAR(50) NULL | On api_failed or failed |
| `nhn_error_message` | TEXT NULL | On api_failed or failed |
| `sent_by_admin_id` | INT NOT NULL | FK → `GT_ADMIN.id`; the audit anchor |
| `sent_by_admin_email` | VARCHAR(255) NOT NULL | Snapshot at send time |
| `created_at` | DATETIME NOT NULL | Send timestamp |
| `delivery_checked_at` | DATETIME NULL | Last time we polled / received status from NHN |

**Indexes**: `(created_at)`, `(recipient_user_id)`, `(sent_by_admin_id)`, `(delivery_status)` — to support the filter combinations on the log page.

**Audit principle**: this table IS the audit. The existing grape `insert_log()` mechanism in `inc/db_class.php` is **not** also called for SMS sends.

---

## Integration with Existing Grape Code

### 10. Reuse, not rebuild

- The new send handler calls into `inc/podo_sms_sender.php` (existing). The existing function/class is extended (or wrapped) to:
  - Accept an explicit sender number argument (today it may rely on a single default).
  - Route to NHN's SMS or LMS endpoint based on body byte length.
  - Return enough information for the caller to populate `SMS_SENT_LOG` (NHN request_id, status code, error info).
- Auth/session: the send handler trusts `$_SESSION['user_admin_id']` and `$_SESSION['user_admin_email']` (set by `inc/check_admin.php`); no separate auth flow.
- DB: uses the existing mysqli connection from `inc/db_conn.php`.
- The hardcoded `appKey` currently inlined in `podo_sms_sender.php` (security note from code scan) is **out of scope** to refactor here, but flagging for a follow-up — credentials should live only in `.env`.

### 11. Schema deployment

- Schema changes ship as SQL files in `admin/sql/`, named:
  - `create_sms_sender_number_table.sql`
  - `create_sms_template_table.sql`
  - `create_sms_sent_log_table.sql`
- Seed data: at least one row in `SMS_SENDER_NUMBER` with `is_default = 1` and `is_active = 1`. (Either bundled in a `seed_sms_sender_number.sql` or applied by DevOps post-deploy.)

### 12. Delivery status — deferred to dev

PM left the delivery-status mechanism to dev. Two viable approaches:

- **Polling (recommended for V1)**: a cron job runs every N minutes, picks up `SMS_SENT_LOG` rows with `delivery_status = 'pending'` from the past 24h, calls NHN's status-lookup API, and updates the row. Simpler infra; no public callback URL needed.
- **Webhook**: register a callback URL with NHN (grape itself is publicly reachable as `grape.re-speak.com`), expose a thin PHP endpoint that ingests delivery callbacks, and update the row. Near-real-time but requires endpoint hardening and signature verification.

**Spec contract regardless of mechanism**: the `delivery_status` column moves from `pending` → `delivered` or `failed` for every row within a reasonable window (target: < 1 hour, hard ceiling: 24 hours, after which rows stuck at `pending` are surfaced visually in the log).

---

## Acceptance Criteria

A grape admin can:

1. **Open the popup** by clicking "문자 보내기" on `podo_students.php?USER_ID=X&mode=U`, and see the student's name/user_id/phone pre-filled and read-only.
2. **Pick a sender number** from a dropdown that defaults to the `is_default = 1` row of `SMS_SENDER_NUMBER`.
3. **Pick a template** from the dropdown of `is_active = 1` templates and watch the body auto-fill with `{{student_name}}`, `{{phone}}`, `{{user_id}}`, `{{수강권_name}}` correctly substituted from the student's record.
4. **See the literal `{{...}}` placeholder** remain in the body for any variable whose source field is null/empty.
5. **Edit the body** after template application.
6. **See an LMS badge** appear when the body exceeds 90 bytes, and an SMS badge when within.
7. **Click 보내기**, see the "정말 발송하시겠습니까?" confirm modal, click 발송, and have the SMS actually fire.
8. **See a new row in `SMS_SENT_LOG`** with `sent_by_admin_id` = their admin id, `body` = the exact rendered text NHN received, `message_type` = SMS or LMS matching the chosen endpoint, `delivery_status` = `pending` initially.
9. **On NHN API failure**, see an inline error in the popup with a 재시도 button, and see an `api_failed` row in `SMS_SENT_LOG`.
10. **Open the Sent SMS Log page**, apply each filter (date range, user_id, user_name, sending admin, delivery status) individually and in combination, and see results restricted correctly.
11. **Open the SMS Template Management page**, add a template, edit it, soft-delete it, and observe that soft-deleted templates disappear from the send popup but their names still appear in historical log rows.
12. **Open the Sender Number Management page**, add a number, mark it default (and observe the previous default is un-defaulted atomically), and toggle active/inactive.
13. **The Sent SMS Log persists indefinitely** — no auto-purge.
14. **Delivery status moves from `pending` to `delivered`/`failed`** within the polling window (or via webhook), at which point the log row reflects the new status without any admin action.

---

## Decisions Captured (Locked)

| # | Decision | Source |
|---|---|---|
| 1 | Single entry point: student details page only | PM |
| 2 | Same NHN Cloud vendor as Alimtalk | PM |
| 3 | Standalone schema / UI (no shared tables with alimtalk) | PM |
| 4 | All grape admins can send + view log (no role gating) | PM |
| 5 | No MMS / images | PM |
| 6 | Fixed variable shortlist: name, phone, user_id, 수강권_name | PM |
| 7 | One shared default sender number | PM |
| 8 | SMS→LMS auto-upgrade at 90 bytes | PM (reconfirmed during dev interview) |
| 9 | Character counter + LMS badge in UI | PM |
| 10 | Confirm dialog before fire | PM |
| 11 | Audit every send with admin id | PM |
| 12 | Inline error + retry on API failure | PM |
| 13 | Wrap existing `inc/podo_sms_sender.php` (do not rewrite) | Dev interview |
| 14 | Bootstrap popup modal (in-page), not new window / new page | Dev interview |
| 15 | 100% grape PHP — no podo-backend involvement | Dev interview |
| 16 | Sender numbers stored in new `SMS_SENDER_NUMBER` table | Dev interview |
| 17 | Audit lives only in `SMS_SENT_LOG`; do not double-write to `insert_log()` | Dev interview |
| 18 | New top-level **SMS** section in admin sidebar | Dev interview |
| 19 | Sent-SMS log retention: indefinite | Dev interview |
| 20 | Template lifecycle: soft-delete (`is_active = 0`) | Dev interview |
| 21 | Sender-number admin UI ships in V1 | Dev interview |
| 22 | Empty template variables render as literal `{{...}}` placeholder | Dev interview |
| 23 | Templates track `created_by` / `updated_by` (+ timestamps) | Dev interview |

## Decisions Deferred to Dev

| # | Item | Note |
|---|---|---|
| D1 | Delivery status mechanism: webhook vs polling | §10. PM and dev interview both deferred. Default leans polling for V1. |
| D2 | Exact file paths under `admin/sms/` (or another folder) | Dev's call within the convention. |
| D3 | Whether existing `podo_sms_sender.php` is refactored to support both SMS and LMS endpoints, or extended via a thin wrapper | Implementation detail; same outward behavior. |
| D4 | Pagination size & sort defaults on the log page | Standard grape conventions apply. |

## Open Assumptions (Validated With User)

- Grape uses NHN Cloud (Toast) as the SMS provider, with credentials in `.env` (`CONF_TOAST_APP_KEY`, `CONF_TOAST_SECRET_KEY`). ✓ Confirmed via codebase scan.
- NHN supports both SMS and LMS via the same appKey/secret. (Standard NHN Cloud SMS product.)
- The student details page already has access to `student_name`, `phone`, `user_id`, and `수강권_name` data sources for variable substitution. (Page already renders these fields.)
- LMS costs ~3× the SMS rate per message at NHN.
- Grape admin login trust model is sufficient for sending — no extra confirmation factor (e.g. password re-entry) is required at send time.

---

## Out of Scope (Explicit V2 Candidates)

- Webhook delivery callback endpoint
- Bulk SMS send (multiple recipients from a list page)
- Scheduled / time-delayed sends
- Send from anywhere other than the student details page
- MMS / image attachment
- Role-based permission gating
- Per-team default sender numbers
- Email as a template variable
- Auto-purge / retention rules on the sent log
- Refactoring the hardcoded `appKey` in `podo_sms_sender.php` (security follow-up, not part of this PRD)

---

## Goal (one-sentence restatement)

> In grape admin, wrap the existing NHN sender to add a "문자 보내기" popup on the student details page (sender-number + template-with-variables dropdowns, SMS→LMS auto-upgrade, confirm dialog, inline retry) plus a sent-SMS audit log page, an SMS template CRUD page, and a sender-number management page — all under a new top-level SMS sidebar section, with every send recorded to a single new sent-SMS table.
