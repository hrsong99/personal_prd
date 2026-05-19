# Grape Admin SMS 발송 기능

*Created At: 2026-05-12T09:25:12.301430+00:00*

## Goal

Add SMS sending capability to grape admin so internal teams can text users directly from the student details page, with full audit logging of all sent messages.

## User Stories

1. **As a** Grape admin user (internal team member), **I want to** Click a '문자 보내기' button on the student details page to open an SMS send UI, **so that** Can initiate SMS to a specific user in 1 click without leaving the student context.
2. **As a** Grape admin user, **I want to** Select a template from a dropdown that auto-populates the message body with variable substitution (e.g., {{student_name}}), then freely edit the text before sending, **so that** Can send consistent yet personalized messages quickly without retyping common content.
3. **As a** Grape admin user, **I want to** Choose a sender number from a dropdown with a pre-selected default, **so that** Can send SMS from the correct registered number without manual entry.
4. **As a** Grape admin user, **I want to** See an inline error message and retry button when an SMS send fails at the API level, **so that** Can recover from send failures immediately without re-entering the message.
5. **As a** Grape admin user, **I want to** View a confirmation dialog ('정말 발송하시겠습니까?') before the SMS is actually sent, **so that** Is protected from accidental sends caused by misclicks.
6. **As a** Grape admin user, **I want to** Browse a sent-SMS log page with filters for sent date, user_id, user_name, and sending admin, **so that** Can audit all sent messages, track who sent what, and review communication history.
7. **As a** Grape admin user, **I want to** Create, edit, and delete SMS templates on a separate template management page, **so that** Can maintain a library of reusable message templates for the team.
8. **As a** Grape admin user, **I want to** See delivery status (delivered / failed / pending) for each sent SMS in the log, **so that** Can verify whether messages actually reached the recipient.

## Constraints

- Single entry point only: '문자 보내기' button on podo_students.php?USER_ID=X&mode=U — no other entry points in V1
- Must use the same SMS provider/vendor as the existing Alimtalk (KakaoTalk) system (NHN Cloud)
- Standalone system — separate DB tables and UI from alimtalk; only shared vendor SDK/credentials
- No role-based permission gating in V1 — all grape admin users can send and view logs
- No MMS / image attachment support in V1
- Template variables limited to a fixed shortlist in V1: {{student_name}}, {{phone}}, {{user_id}}, {{수강권_name}}
- One shared default sender number for all users — no per-team/role variation in V1
- Auto-upgrade from SMS to LMS when message exceeds 90 bytes (up to ~2,000 bytes for LMS)
- Must show character counter in the send UI and badge/indicate when message will be sent as LMS
- Every sent SMS must record which admin user triggered the send (admin name/ID)
- Confirmation dialog required before actual send

## Success Criteria

1. Internal team can send an SMS to a user in 2-3 clicks (open student page → click 문자 보내기 → select template → confirm send)
2. All sent messages are auditable via the sent-SMS log page with filters including sending admin
3. Delivery status (delivered / failed / pending) is tracked and visible in the sent-SMS log
4. Template variable substitution correctly replaces {{student_name}}, {{phone}}, {{user_id}}, {{수강권_name}} with student data
5. Send failures surface inline errors with a retry option in the send UI
6. Messages auto-upgrade from SMS to LMS transparently when body exceeds 90 bytes

## Assumptions

- The existing Alimtalk system uses NHN Cloud as the messaging provider, and the same account/credentials can be reused for SMS/LMS
- NHN Cloud supports both SMS and LMS sending with auto-upgrade capability
- Grape admin already has a trusted-user access model (login = authorization), making E1 (no role gating) appropriate
- The student details page (podo_students.php) has access to student_name, phone, user_id, and 수강권_name data for template variable substitution
- Sender numbers are pre-registered with NHN Cloud and the set changes infrequently
- LMS costs approximately 3× the SMS rate per message
- Grape admin users have sufficient context to understand SMS vs LMS cost differences when shown a UI badge

## Decide Later

The following items were deferred or identified as premature at this stage. They should be revisited when more context is available:

- Should the delivery status mechanism use webhook callback (NHN pushes to your endpoint) or active polling (server periodically calls NHN API)? Dev picks based on whether grape has a publicly reachable callback URL.
- Should the send UI be a popup overlay or a separate page? Dev picks based on UX and implementation preference.
- Should sender numbers be stored in a hardcoded config or a DB table? (PM leaned toward DB table for future flexibility, but left final call to dev.)
- Webhook vs polling mechanism for delivery status reporting — developer picks based on grape infra (whether a publicly reachable callback URL is feasible)
- Popup vs new page for the SMS send UI — developer picks
- Sender number storage: hardcoded config vs DB config table — developer picks (spec says DB table for future flexibility)
- MMS / image attachment support (explicitly excluded from V1)
- Per-team/role default sender number variation
- Role-based permission gating for sending or viewing logs
- Email as a template variable
- Exposing all student record fields as template variables (V1 uses fixed shortlist only)

## Existing Codebase Context

- **grape** (`/Users/johnsong/grape`)
- **podo-app** (`/Users/johnsong/podo-app`)
- **podo-backend** (`/Users/johnsong/podo-backend`)

---
*PM ID: pm_seed_interview_20260512_090357*
*Interview ID: interview_20260512_090357*
