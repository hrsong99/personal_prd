# PRD: Calendar Sync for Lesson Bookings

## Overview

We are adding an **opt-in** "내 캘린더에 자동 동기화" feature to the PODO booking flow. When a student opts in, every PODO lesson they book appears in the OS-level calendar on their device, and **stays correct** when they (or anyone — admin, the student on another device) update or cancel the lesson.

This is a **reminder reinforcement**, not a calendar product. The existing alimtalk + push notification stack remains the primary reminder channel; this is one additional surface that lives on the user's home/lock screen via their calendar app of choice.

The design is **explicitly split by platform** — iOS uses webcal subscription (server-driven, pull-based), Android uses native CalendarContract writes (device-driven, push-reconciled). This is not for elegance; it is because each platform is hostile to the other's solution. See §3 for the decision log.

This PRD covers:
- **iOS app users** — primary, cleanest path
- **Android app users** — covered, more moving parts
- **Mobile web users** (booking from Safari/Chrome without the app installed) — one-shot calendar-add, no sync
- **Desktop web users** — same one-shot path

---

## Goals

1. A student who opts in gets a calendar entry on their device for every PODO lesson they book.
2. The entry stays correct after schedule changes (time moved → calendar moves) and cancellations (lesson canceled → calendar entry removed), **regardless of which surface or device caused the change** — including admin-initiated changes.
3. The feature works across every calendar provider the user has wired into their phone — Google Calendar, iCloud Calendar, Naver Calendar (via iOS sync), Outlook, Samsung Calendar. We do not pick winners.
4. Opt-in UX is **just-in-time and recoverable** — we don't prompt at app launch, we don't soft-block users who decline, and we let them opt in later from Settings.
5. Mobile web bookers get a less powerful but still useful "Add to Calendar" experience, with no sync.
6. Zero OAuth, zero stored third-party tokens, zero Google verification process.

## Non-Goals

- **No Google Calendar API / OAuth integration.** That path was evaluated and rejected (§3) — it's Google-only and requires sensitive-scope verification.
- **No new reminder system.** Calendar entries do not replace alimtalk or push notifications; they sit alongside them. Existing reminder logic is untouched.
- **No support for shared / family calendars.** We write to or are subscribed by the user's default calendar; users can move events manually.
- **No "remind me N minutes before" knob in v1.** We set a single default reminder (15 min before) and let users edit the entry in their Calendar app.
- **No real-time sync guarantee.** The iOS webcal path refreshes on iOS's schedule (~hours). The Android path is best-effort silent-push + foreground reconciliation. Last-minute changes may not propagate before the lesson starts; the alimtalk + push reminder remains the source of truth for time-critical updates.
- **Not a v1.0 timeline doc.** Sequencing is in §11; calendar dates are out of scope here.

---

## Decision log

Five approaches were considered. The final design is a **platform-split** that combines two of them.

| # | Approach | OAuth | Server state | Naver/iCloud coverage | Cancel/change sync | Native code? | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | ICS file via alimtalk/email attachment | No | None | Partial (depends on mail client honoring METHOD updates) | Fragile | No | Rejected — too unreliable |
| 2 | "Add to Calendar" URL (Google render endpoint) | No | None | No (Google only) | **None** (one-shot add) | No | **Adopted for mobile/desktop web fallback** (§7.3) |
| 3 | Google Calendar API (OAuth + server-side writes) | Yes — sensitive scope | Refresh tokens | No (Google only) | Yes | No, but in-app OAuth | Rejected — narrow coverage, verification cost |
| 4 | Native EventKit / CalendarContract (Toss-style) | No | Per-device event-ID map | Yes (everything the OS has) | Yes (client-driven) | **Yes** | **Adopted for Android** (§7.2) |
| 5 | webcal:// subscription to server-side ICS feed | No | Per-user opaque token | Yes (everything the OS subscribes through) | Yes (server-driven, naturally cross-device) | No (just a URL handler) | **Adopted for iOS** (§7.1) |

The cross-device sync requirement (Goal 2) was the deciding constraint. The native-write approach (#4) requires per-device event-ID tracking and silent-push fanout to stay in sync across devices — workable but complex. The webcal approach (#5) sidesteps that entirely because the server is the source of truth and the OS pulls from it.

**Why not webcal everywhere?** Because `webcal://` is iOS-only in practice. Tapping a `webcal://` link on Android produces `ERR_UNKNOWN_URL_SCHEME` for the vast majority of users (Google Calendar Android doesn't register for the scheme; neither does Naver Calendar). The Google Calendar `?cid=...` web URL is a multi-tap, browser-detour workaround that completes maybe 60% of the time. Native-write is strictly better on Android.

**Why not native-write everywhere?** Because on iOS, webcal is strictly better: one OS sheet, the user picks which account, the server handles all subsequent state, and it survives uninstall, new phone, and multi-device — none of which native-write does cleanly.

So the design is: **iOS = webcal, Android = native-write, mobile/desktop web = "Add to Calendar" buttons.**

---

## Glossary

| Term | Meaning |
|---|---|
| **Webcal feed** | A server-hosted `.ics` file at a per-user URL, e.g. `webcal://api.podo.app/calendar/user/{opaqueToken}.ics`. iOS Calendar pulls it on its own schedule. |
| **Opaque token** | An unguessable per-user string in the webcal URL. Acts as auth. Rotatable and revocable. |
| **Local event ID** (Android only) | The string returned by `expo-calendar` when an event is created. Used to update/delete that event later. |
| **App bridge** | The existing JS ↔ native message channel at `apps/native/src/core/app-bridge.ts`. We extend it with calendar methods on Android only. |
| **Sync opt-in** | A user-level boolean ("yes, PODO should keep my calendar updated"). Persisted server-side (not just on-device). Default `false`; flipped `true` the first time the user accepts. |
| **Reconciliation pass** (Android only) | A foreground sweep on app open that compares the device's local event map against the current server state and fixes drift. |

---

## Architecture at a glance

```
┌──────────────────────── iOS app users ────────────────────────┐
│                                                                │
│  PODO app → tap "내 캘린더에 자동 동기화"                       │
│           → webcal://api.podo.app/calendar/user/{token}.ics    │
│           → iOS system "Subscribe?" sheet                      │
│           → user picks account (iCloud / Google / etc.)        │
│                                                                │
│  After subscribe: iOS Calendar polls server ICS feed every     │
│  few hours. Server is the source of truth. Book/change/cancel  │
│  from any surface (app, web, admin) → next feed refresh fixes  │
│  the calendar.                                                 │
└────────────────────────────────────────────────────────────────┘

┌────────────────────── Android app users ──────────────────────┐
│                                                                │
│  PODO app → tap "내 캘린더에 자동 등록"                         │
│           → bridge requests CalendarContract permission        │
│           → on first book: bridge writes to default calendar,  │
│             returns localEventId, persisted on-device          │
│                                                                │
│  After opt-in: book/change/cancel inside the app updates the   │
│  calendar inline. Book/change/cancel from elsewhere (web,      │
│  admin, other device) → server sends silent FCM → app wakes,   │
│  runs reconciliation pass. Foreground reconciliation runs on   │
│  My Lessons screen mount as a safety net.                      │
└────────────────────────────────────────────────────────────────┘

┌─────────────── Mobile web / desktop web users ────────────────┐
│                                                                │
│  Booking confirm screen → "Add to Calendar" section            │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │ Google       │ │ Apple        │ │ Outlook      │            │
│  │ Calendar     │ │ Calendar     │ │              │            │
│  └──────────────┘ └──────────────┘ └──────────────┘            │
│                                                                │
│  Google = render URL (https://calendar.google.com/...)         │
│  Apple/Outlook = downloadable .ics                             │
│                                                                │
│  iOS Safari users additionally see a "내 캘린더에 자동 동기화"  │
│  button that triggers the webcal flow (same as the app path).  │
│                                                                │
│  Android Chrome / desktop users: one-shot only, no sync.       │
└────────────────────────────────────────────────────────────────┘
```

---

## Detailed flows

### 7.1 iOS app (and iOS Safari) — webcal subscription

#### One-time setup

1. After the user's first successful booking, the booking-success screen renders an offer card:
   - **Headline:** "잊지않게 내 캘린더에 자동으로 등록해드릴까요?"
   - **Sub-copy:** "예약, 변경, 취소가 캘린더에 자동으로 반영돼요."
   - **Primary CTA:** "네, 등록할게요" → triggers webcal subscription
   - **Secondary CTA:** "아니요"
2. On "네": web calls bridge `calendar.subscribeIOS()` which does `Linking.openURL('webcal://api.podo.app/calendar/user/{token}.ics')`.
3. iOS shows the system "Subscribe to this calendar?" sheet.
4. User taps Subscribe → picks an account → returns to PODO.
5. App calls `POST /api/v1/calendar/subscription/acknowledged` with `{userId}` to flip `sync_opt_in_ios = true` on the server.

(We can't actually detect from JS whether the user completed the system sheet — iOS doesn't tell us. The acknowledgement is best-effort: we mark opt-in optimistically when they tap "네" and the OS sheet opens; if they cancel, we'll see no feed pulls and can flip it back later. Acceptable.)

#### Steady state

The iOS Calendar app polls `webcal://api.podo.app/calendar/user/{token}.ics` on its own schedule (typically every few hours; user-configurable per subscription). The server-generated ICS feed contains:
- All of the user's upcoming lessons (future, plus any in the last 24h that have not yet been completed)
- Any recently-cancelled lessons (cancelled in the last 7 days), included with `STATUS:CANCELLED`, so the OS removes the entry

The server is canonical. Book / change / cancel from **any** surface (in-app, web, admin) updates the DB → next feed refresh propagates.

#### Trade-off the user sees

Up to a few hours of lag between an update and the calendar reflecting it. We surface this in the opt-in copy:
> "캘린더 앱이 직접 동기화하기 때문에, 변경사항이 반영되기까지 몇 시간이 걸릴 수 있어요. 시간이 임박한 변경은 알림톡으로 알려드려요."

### 7.2 Android app — native-write + silent-push reconciliation

#### One-time setup

1. Same booking-success card as iOS (different sub-copy for Android since the sync semantics differ).
2. On "네": web calls bridge `calendar.requestPermission()` → bridge invokes `CalendarContract` permission request.
3. On grant: bridge writes the event, returns `localEventId`, persists `{classId → localEventId}` on-device and POSTs `{userId, classId, localEventId, deviceId}` to the server.
4. Server stores per-device localEventId in a new `calendar_event_mapping` table (see §8).

#### Steady state

**Book/change/cancel from inside the Android app:**
- `bookMutation.onSuccess` / `changeMutation.onSuccess` / `cancelBookingAction` calls the bridge inline
- Bridge updates the device's local calendar via CalendarContract
- Sync is instant for the device that performed the action

**Book/change/cancel from another surface (web, admin, other device):**
- Backend posts a silent FCM data message `{type: 'calendar_sync_reconcile', classIds: [...]}` to every device of that user that has `sync_opt_in_android = true`
- Device wakes briefly, runs reconciliation pass for those classIds, sleeps
- Foreground reconciliation on My Lessons screen mount as a safety net (catches missed silent pushes)

**Cross-device sync via server mapping:**
- Server knows every (device, classId, localEventId) tuple
- When a device receives the reconciliation push and acts (or fails — e.g., user manually deleted), it reports back so the server stays accurate

#### Reliability

Silent FCM on Android is materially more reliable than silent push on iOS (no force-quit issue), so this gets us to ~95% sync reliability. The foreground reconciliation pass closes the rest.

### 7.3 Mobile web / desktop web — "Add to Calendar" buttons

After a successful booking on web (when the user is **not** in the native app shell), the booking-success screen renders:

- **Google Calendar** → opens `https://calendar.google.com/calendar/render?action=TEMPLATE&text=...&dates=...&details=...&location=...` in a new tab. One-shot.
- **Apple Calendar** → downloads `lesson-{classId}.ics` with `METHOD:PUBLISH`. One-shot. iOS Safari users get the system "Open in Calendar?" prompt.
- **Outlook** → downloads the same `.ics`. (Outlook handles `PUBLISH` ICS files identically.)

**iOS Safari users additionally see** a fourth button: **"내 캘린더에 자동 동기화"** which triggers `window.location = 'webcal://...'` — same as the in-app iOS path. This is the only mobile-web user who gets sync; everyone else is one-shot.

**Why not auto-detect platform and show only one button?** Because the user may want their lesson on a different calendar than the OS default (e.g., a Mac user with iCloud for personal + Google Calendar for work). Letting them pick is friendlier and only costs a few millimeters of vertical space.

---

## Server contracts

### 8.1 Webcal feed endpoint

```
GET /api/v1/calendar/user/{opaqueToken}.ics
```

- **Auth:** the token IS the auth. No header.
- **Response:** `Content-Type: text/calendar; charset=utf-8`
- **Body:** iCalendar (RFC 5545) document containing all of the user's upcoming + recently-cancelled lessons
- **Caching:** `Cache-Control: max-age=600` (10 min). iOS won't respect tight caching headers anyway; this is just to bound server load if iOS over-pulls.
- **Library:** use [Biweekly](https://github.com/mangstadt/biweekly) for Java ICS generation. Battle-tested, RFC-conformant.

ICS event shape:

```
BEGIN:VEVENT
UID:lesson-{classId}@podo.app
DTSTART;TZID=Asia/Seoul:20260522T090000
DTEND;TZID=Asia/Seoul:20260522T092500
SUMMARY:PODO 영어 수업 with Sarah
LOCATION:PODO 앱
DESCRIPTION:PODO 앱에서 수업을 시작하세요\nhttps://podo.app/lesson/{classId}
SEQUENCE:{change_count}
STATUS:CONFIRMED        ← or CANCELLED for recently-cancelled
LAST-MODIFIED:{last_modified_utc}
BEGIN:VALARM
TRIGGER:-PT15M
ACTION:DISPLAY
END:VALARM
END:VEVENT
```

`SEQUENCE` is incremented on every change so subscribers honor the update. `STATUS:CANCELLED` events stay in the feed for 7 days post-cancellation so the OS reflects the deletion, then drop out.

### 8.2 One-shot ICS endpoint (for web "Add to Calendar" buttons)

```
GET /api/v1/calendar/lesson/{classId}.ics?token={shortLivedToken}
```

- **Auth:** short-lived signed token in the query string (15 min TTL), generated by the booking-success page
- **Response:** single-event ICS with `METHOD:PUBLISH`, downloadable
- Used by Apple Calendar / Outlook buttons in the web flow

### 8.3 Token management

New table `user_calendar_token`:

| Column | Type | Notes |
|---|---|---|
| `user_id` | bigint, PK | |
| `opaque_token` | varchar(64), unique | Random URL-safe string, the user's webcal credential |
| `created_at` | datetime | |
| `revoked_at` | datetime, nullable | If non-null, requests with this token return 410 Gone |
| `last_pulled_at` | datetime, nullable | Updated on every feed read — used for opt-in analytics |

- Created on first opt-in (iOS or web flow)
- Rotatable from Settings → 알림 → "캘린더 동기화 다시 시작" (in case user thinks the URL leaked)
- Old tokens stay valid until explicitly revoked

### 8.4 Per-device event mapping (Android only)

New table `calendar_event_mapping`:

| Column | Type | Notes |
|---|---|---|
| `id` | bigint, PK | |
| `user_id` | bigint, indexed | |
| `device_id` | varchar | From push registration |
| `class_id` | bigint, indexed | |
| `local_event_id` | varchar | Returned by CalendarContract |
| `last_synced_at` | datetime | |
| Unique: `(device_id, class_id)` | | |

Used by the backend to know which devices have a local event for which class, so silent-push reconciliation knows where to fan out.

### 8.5 Silent push for Android reconciliation

Backend hook: extend `PodoScheduleServiceImplV2.book/change/cancel` (which already has `NotificationService` injected) to additionally enqueue a silent FCM data message:

```json
{
  "type": "calendar_sync_reconcile",
  "class_ids": ["12345", "12346"],
  "action": "updated"
}
```

Sent to every Android device of the affected user with `sync_opt_in_android = true`. iOS devices ignore (iOS users are on webcal).

`changeByAdmin` and `cancelByAdmin` are the surfaces where this matters most — they're the ones that aren't covered by client-side direct writes.

### 8.6 Sync state endpoint (for Settings toggle)

```
GET  /api/v1/user-preference/calendar-sync          → current opt-in state
POST /api/v1/user-preference/calendar-sync          → flip opt-in, optionally rotate token
```

Persists `sync_opt_in_ios` and `sync_opt_in_android` flags (separate because they have different lifecycles).

---

## Event payload contract

Same across all platforms. Server is the source of truth.

| Field | Value | Example |
|---|---|---|
| Title | `PODO 영어 수업 with {tutorName}` (omit `with` clause if not yet matched) | `PODO 영어 수업 with Sarah` |
| Start | Lesson start in user TZ | `2026-05-22 09:00 KST` |
| End | Start + `lessonTime` (15 / 25 / 55 min) | `2026-05-22 09:25 KST` |
| Location | `PODO 앱` (constant) | — |
| Description | Short, includes deep link | `PODO 앱에서 수업을 시작하세요: https://podo.app/lesson/{classId}` |
| TZ | User's device timezone at booking time, snapshotted | `Asia/Seoul` |
| Alarm | -15 min, single | — |
| UID (webcal) | `lesson-{classId}@podo.app` | Stable across the lesson's lifetime |
| SEQUENCE (webcal) | Incremented per change | — |
| STATUS | `CONFIRMED` or `CANCELLED` | — |

Tutor name handling: for 무제한 users matched at runtime, on book/change the tutor may not be finalized. In that case the title is `PODO 영어 수업` (no `with` clause). We do not force a calendar update later just because a tutor was assigned — that would be noise.

---

## Permission UX detail

### iOS

iOS does **not** require a permission grant for webcal subscription — the system "Subscribe?" sheet IS the permission moment. The user's tap on "Subscribe" in that sheet is their consent.

Therefore the only thing we control is whether the soft-prompt card appears. If it does and the user taps "네," we trigger the system sheet. If the user dismisses the system sheet (taps cancel), no harm done — we'll see no feed pulls and can ask again on a later booking.

Lifetime rules:
- Show the offer card on the **first** successful booking after install.
- If the user taps "아니요," don't show it again on subsequent bookings.
- If the user taps "네" but the subscription doesn't take effect within 24h (no feed pulls observed), show it again on the next booking with slightly different copy: "캘린더 구독이 안 되었던 것 같아요. 다시 시도해보시겠어요?"
- Settings → 알림 → "캘린더 자동 동기화" is the always-available manual entry point.

### Android

Android requires the OS-level `WRITE_CALENDAR` + `READ_CALENDAR` permission. Cadence:

1. Soft-prompt card on booking success: `"잊지않게 내 캘린더에 등록해드릴까요?"`
2. On "네": trigger the OS permission prompt via the bridge.
3. On grant: write the event, store mapping, flip `sync_opt_in_android = true`.
4. On deny: show one-time inline note `"설정에서 캘린더 권한을 허용하면 자동으로 등록돼요"` with `[설정 열기]` deep link. Don't re-prompt.

The hard constraint is the same as for iOS: never trigger the OS prompt without the soft-prompt card first, because on both platforms the user only gets a limited number of OS-prompt shots before being routed to Settings.

### Mobile/desktop web

No OS permission involved. The "Add to Calendar" buttons are always visible on the booking-success screen for web users (i.e., for users not in the native app shell). No opt-in machinery — each tap is its own consent.

---

## Edge cases

| Case | Behavior |
|---|---|
| **iOS user unsubscribes from the feed manually** | The feed pulls stop. We detect (no `last_pulled_at` updates in 14 days) and can re-prompt on a later booking. |
| **iOS user moves the subscription to a different account** | Transparent to us. Same feed, same content. |
| **iOS feed delay vs. last-minute change** | Calendar may be stale up to a few hours. The alimtalk + push still fire. We surface this in opt-in copy. |
| **iOS user's `opaqueToken` leaks** | They rotate via Settings. Old token returns 410. Lesson data exposure is limited to that user's lesson schedule (no PII beyond names and times). |
| **Android user revokes permission via OS Settings** | Next bridge call returns `granted=false`. We silently flip `sync_opt_in_android = false`; surface a passive note in Settings on next visit. |
| **Android user manually deletes an event from their Calendar app** | Subsequent `update`/`remove` returns `not_found`. Logged, no user-facing error. |
| **Android user uninstalls and reinstalls** | `AsyncStorage` map is lost. Server has the mapping but the localEventIds it stores are stale (new install can't address them). On next opt-in, we treat them as new — past events written by the old install stay in their calendar, naturally age out. |
| **Android admin-initiated change (`changeByAdmin` / `cancelByAdmin`)** | Silent FCM fires → device reconciles. If FCM fails (device offline, force-quit, etc.), foreground reconciliation catches it on next app open. |
| **Multi-device same platform (e.g., two Android phones)** | Each device has its own permission grant, its own `localEventId` per class. Silent push fans out to both. Each maintains its own copy. |
| **Multi-device cross-platform (Android + iPad with iOS app)** | iPad uses webcal subscription. Android uses native-write. Both stay in sync because both read from the same server state. Calendar entries on the two devices are independent records of the same lesson. |
| **User changes phone timezone after booking** | Webcal feed carries `TZID`; Android event has stored `timeZone`. Calendar apps handle DST/TZ transitions correctly. |
| **Two 15-min lessons on the same day (무제한)** | Two separate events, two separate `UID`s (one per `classId`), independently editable. |
| **Lesson date is in the past at the time of a write** | Still write. Calendar apps handle past events fine. |

---

## Reconciliation strategy (Android)

Three reconciliation surfaces, layered from most-real-time to safety-net:

1. **Direct writes** — when the same Android device that booked also updates/cancels, the bridge writes inline.
2. **Silent FCM push** — when state changes anywhere else (web, admin, other device), backend fans out a silent push; recipient devices wake and run a targeted reconciliation for the listed `classIds`.
3. **Foreground reconciliation** — when the user opens **My Lessons / 내 수업 tab**, the screen mount effect:
   1. Reads the device's local `{classId → localEventId}` map
   2. Diffs against the API response for that screen (already being fetched)
   3. For managed classes: update if `classDateTime` changed, remove if class is gone
   4. Reports back to the server with any corrections (so the server's mapping stays accurate)

Silence: no toasts, no error UI, no spinner. Drift converges as the user uses the app.

iOS has no equivalent reconciliation pass because the webcal subscription is its own reconciliation — the OS pulls a fresh feed, and that's that.

---

## Rollout

### Phase 1 — Web "Add to Calendar" buttons (week 1)

The cheapest, most foundational piece. Pure server work + a few buttons. No native shell release required.

- ICS generation library wired up
- One-shot ICS endpoint live
- Google Calendar render URL + Apple/Outlook ICS buttons on the web booking-success screen
- GrowthBook flag: `calendar_add_buttons_v1` — 100% rollout once tested

### Phase 2 — iOS webcal subscription (week 2–3)

- Webcal feed endpoint live, ICS feed correctness verified across iOS Calendar, Google Calendar (web add-by-URL), and Outlook (Mac/Windows)
- Per-user token table + rotation/revoke endpoints
- iOS booking-success card + Settings toggle
- iOS Safari webcal button on web booking-success screen
- GrowthBook flag: `calendar_sync_ios_v1` — staged: 10% → 50% → 100% over 2 weeks

### Phase 3 — Android native-write (week 4–5)

- Bridge extension in native shell (requires app release)
- CalendarContract permission + writes
- Per-device mapping table + silent FCM push hook
- Foreground reconciliation pass on My Lessons screen
- Android booking-success card + Settings toggle
- GrowthBook flag: `calendar_sync_android_v1` — staged: 10% → 50% → 100% over 2 weeks

### Kill switch

Each GrowthBook flag independently gates its surface. Flipping any flag off stops new actions on that platform but does not retroactively delete events (or unsubscribe feeds — iOS users have to do that themselves).

---

## Success metrics

Measured per platform; they have different ceilings.

| Metric | iOS target | Android target | Notes |
|---|---|---|---|
| Opt-in rate among users who see the card | ≥ 35% | ≥ 25% | iOS expected higher because webcal UX is smoother |
| Subscription took effect (≥1 feed pull within 24h) | ≥ 90% of opt-ins | n/a | iOS only |
| Calendar-write success rate after opt-in | n/a | ≥ 98% | Android only |
| Cross-surface sync success (admin change reflected within 6h on iOS, 6m on Android) | ≥ 95% | ≥ 95% | |
| 30-day opt-out rate | ≤ 10% | ≤ 10% | |
| 7-day support tickets containing "캘린더" | < 5 per 10k opted-in users | < 5 per 10k | The runaway-entries risk metric |
| **Lesson no-show rate among opted-in users vs. matched cohort** | **-5% relative** | **-5% relative** | The core hypothesis |

---

## Open questions

1. **Default alarm offset.** PODO push reminders already fire at 15 min before. If the calendar alarm is also at 15 min, the user gets two reminders simultaneously — possibly fine, possibly annoying. Alternatives: calendar at 5 min (layered), calendar at 60 min + 5 min (defense in depth). Need a decision.
2. **Tutor-name handling for 무제한.** Showing `PODO 영어 수업` without a tutor when one isn't yet matched feels generic; showing `PODO 영어 수업 - 튜터 매칭 중` is more honest but reads as a status in calendar list views. Recommendation: omit `with` until matched, then leave the title alone (don't push an update just for the tutor). Open for confirmation.
3. **iOS feed pull frequency.** iOS doesn't expose a guaranteed refresh interval, and the user can configure it per subscription. We may want to surface guidance in the opt-in copy ("In iOS Calendar settings, you can set refresh to as often as every 15 minutes"). Marginal — only matters if last-minute change reports come in.
4. **Naver Calendar coverage.** Korean Android users who exclusively use Naver Calendar are not reachable by either webcal (Naver doesn't subscribe to ICS feeds) or native-write (CalendarContract doesn't reach Naver Calendar). Their lesson reminder will remain alimtalk-only. Should we surface a note? Probably not — most Naver Calendar users also have Google or Samsung Calendar wired up.
5. **Token leakage threat model.** The webcal token is sufficient to read a user's full lesson schedule. We rotate on user request, but is auto-rotation (e.g., every 90 days) worth the small risk of breaking active subscriptions silently? Lean toward no for v1.

---

## Appendix: file-level implementation hints

For eng spike scoping. Not part of the feature spec.

### Backend (`/Users/johnsong/podo-backend`)

- New module: `applications/calendar/`
  - `CalendarFeedController` — webcal feed endpoint
  - `CalendarFeedService` — uses Biweekly to generate ICS from lesson queries
  - `UserCalendarTokenRepository` + entity
  - `CalendarEventMappingRepository` + entity (Android only)
  - `CalendarSyncPushService` — fans out silent FCM on book/change/cancel
- Add Biweekly dependency: `net.sf.biweekly:biweekly:0.6.x`
- Extend `PodoScheduleServiceImplV2.book/change/cancel` (existing file) to invoke `CalendarSyncPushService` after the existing notification dispatch
- Extend `changeByAdmin` and `cancelByAdmin` paths too — this is what makes admin-initiated changes propagate

### Native shell (`/Users/johnsong/podo-app/apps/native`)

- Add `expo-calendar` to `apps/native/package.json` (Android use)
- Add silent FCM data-message handler (Android only) → calls reconciliation
- Extend `apps/native/src/core/app-bridge.ts` with the `calendar` namespace:
  - `subscribeIOS()` — opens webcal:// link
  - `requestPermission()` (Android) — wraps `expo-calendar` permission
  - `add(payload)` / `update(localEventId, payload)` / `remove(localEventId)` (Android)
- New `apps/native/src/shared/libs/calendar.ts` (mirror `register-push-notification.ts` shape)
- iOS `Info.plist`: nothing needed for webcal (no permission required)
- Android `AndroidManifest.xml`: add `WRITE_CALENDAR`, `READ_CALENDAR`

### Web (`/Users/johnsong/podo-app/apps/web`, `apps/tutor-web`)

- New: `apps/web/src/shared/hooks/use-calendar-bridge.ts` — wraps bridge calls for app users, no-ops for web-only users
- New: `apps/web/src/shared/hooks/use-calendar-platform.ts` — detects iOS Safari vs. Android Chrome vs. desktop vs. in-app
- New UI: `apps/web/src/views/booking/ui/add-to-calendar-card.tsx` — the offer card / button group
- Hook into `apps/web/src/views/booking/hooks/use-booking-mutation.ts`:
  - `bookMutation.onSuccess` (line 71): render appropriate variant of the calendar card
  - `changeMutation.onSuccess` (line 106): if Android opted-in, fire `calendar.update` via bridge
- Hook into `apps/web/src/entities/lesson/api/lesson.action.ts:811` (`cancelBookingAction`): same, fire `calendar.remove`
- New UI: Settings toggle row under 알림 section, two separate toggles for iOS-webcal-active and Android-native-sync-active (the OS doesn't know about the other one; users can be opted in on both their phones)
- Foreground reconciliation: hook into the My Lessons screen mount effect (Android only)
