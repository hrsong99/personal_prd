# PRD-v0: Calendar Sync for Lesson Bookings — Minimal Scope

## Overview

We are adding an **opt-in** "내 캘린더에 등록해드릴까요?" feature to the PODO booking flow. When a student opts in, lessons they book **from inside the PODO app** are written to the OS-level calendar on the same device. Changes and cancellations they make **from inside the same app, on the same device** are automatically reflected in that calendar entry.

This is the smallest possible version of the feature: a Toss-style native EventKit / CalendarContract integration, no server changes, no cross-device sync, no reconciliation. Its purpose is to ship fast and learn whether users actually want a calendar entry at all before we invest in more.

Inspired by Toss's `정부24` calendar-add flow ("Toss" would like to add to your Calendar). Same shape, same simplicity.

---

## Goals

1. Opted-in students get a calendar entry on their device for every PODO lesson they book through the app.
2. If they change a lesson in the same app, the calendar entry moves to match.
3. If they cancel a lesson in the same app, the calendar entry is removed.
4. Permission ask is just-in-time, single-shot, and recoverable from Settings.
5. Zero backend changes. Zero OAuth. Zero new endpoints.

## Non-Goals (explicit)

- **No cross-device sync.** If the user books on Phone A, the lesson does not appear on Phone B's calendar. This is a known limitation; v1 may revisit.
- **No cross-surface sync.** If the user (or admin) cancels a lesson from the **web app**, the **admin tool**, or **another device**, the calendar entry on the original device is **not** updated. The user must update or delete manually, or wait for it to age out naturally.
- **No server-side calendar state.** The backend does not know whether a user has opted in, does not store any calendar IDs, does not generate ICS files.
- **No mobile/desktop web "Add to Calendar" buttons.** Web users see no calendar UI in v0.
- **No reconciliation pass.** We do not sweep the device on app open looking for drift.
- **No edge-case mitigations.** If the user manually deletes an event from their Calendar app, we don't know. If they revoke permission mid-flight, we don't gracefully retry. The feature is best-effort and stops silently when things go wrong.
- **No analytics dashboard.** Just basic opt-in / write-success event firing into the existing analytics pipeline.
- **No "remind me N minutes before" knob.** Hardcoded 15-min reminder.

---

## Architecture

```
PODO web (booking UI)
       ↓ onSuccess of book / change / cancel
       ↓
   app-bridge.calendar.{add, update, remove}
       ↓ bridge → native
       ↓
  expo-calendar (wraps EventKit on iOS, CalendarContract on Android)
       ↓
  OS Calendar (iCloud / Google / Samsung / Naver — whatever the device's default is)
```

Per-device, on-device only. The bridge is the only new component. No new backend services.

---

## User flows

### Flow 1 — First booking after install (not yet opted in)

1. User books a lesson through the existing UI.
2. `POST /api/v3/schedule/book` succeeds (unchanged).
3. On the booking-success screen, below existing content, a one-time offer card renders:
   - **"잊지않게 내 캘린더에 등록해드릴까요?"**
   - Primary CTA: **"네, 등록할게요"**
   - Secondary CTA: **"아니요"**
4. On "네":
   - Web calls bridge `calendar.requestPermission()`.
   - Bridge triggers the OS permission prompt (iOS: `EKEventStore.requestFullAccessToEvents` / Android: `WRITE_CALENDAR` + `READ_CALENDAR`).
   - On grant: bridge writes the event via `expo-calendar`, returns `localEventId`.
   - Web persists `{classId → localEventId}` in `AsyncStorage` (via bridge) and flips on-device opt-in flag.
   - Toast: **"내 캘린더에 등록되었어요"**
5. On "아니요": records opt-in = false, dismisses the card. Not shown again unless the user toggles from Settings.
6. On permission denied at the OS prompt: one-time inline note **"설정에서 캘린더 권한을 허용하면 자동으로 등록돼요"** with `[설정 열기]` deep link.

### Flow 2 — Subsequent bookings (already opted in)

1. User books a lesson.
2. On success, web calls `calendar.add(eventPayload)` directly — no card, no prompt.
3. Toast: **"내 캘린더에 등록되었어요"** with **"취소"** link to undo just this event.

### Flow 3 — Change a lesson from the same app

1. User changes lesson time in the existing UI.
2. `POST /api/v3/schedule/change` succeeds.
3. Web looks up `localEventId` for the `classId` from AsyncStorage.
4. If present, web calls `calendar.update(localEventId, newPayload)`.
5. Toast: **"내 캘린더 일정이 변경되었어요"**

If `localEventId` is missing (user opted in *after* this lesson was originally booked, or the original write failed silently): no-op. We don't retroactively create entries for past bookings.

### Flow 4 — Cancel a lesson from the same app

1. User cancels lesson in the existing UI.
2. `POST /api/v3/schedule/cancel` succeeds.
3. Web looks up `localEventId` for the `classId`.
4. If present, web calls `calendar.remove(localEventId)`.
5. Removes the mapping from AsyncStorage.
6. Toast: **"내 캘린더에서도 삭제되었어요"**

### Flow 5 — Opt out via Settings

1. Settings → 알림 → "내 캘린더에 자동 등록" toggle OFF.
2. Flips opt-in flag.
3. **Already-written events are left in place.** Surfaced in the toggle copy: `"새로운 수업만 등록되지 않아요. 이미 등록된 일정은 직접 삭제해 주세요."`

---

## Permission UX cadence

The order of dialogs matters. The correct sequence for both iOS and Android:

1. **App-level soft prompt** (our card) — never appears until the user has at least one successful booking.
2. **Only if user taps "네, 등록할게요"** → trigger the OS-level permission prompt.
3. **If OS prompt denied** → inline note with `[설정 열기]`. Do not loop.

Burning the OS prompt on a user who would have said no to our card means they can never opt in later without going to Settings manually. On iOS in particular, the user only gets one shot at the system dialog per app install.

---

## Bridge contract

Extend `apps/native/src/core/app-bridge.ts` with three methods, mirroring the existing push-notification bridge pattern:

```ts
calendar: {
  requestPermission(): Promise<'granted' | 'denied' | 'restricted'>

  add(payload: CalendarEventPayload): Promise<{ localEventId: string }>

  update(
    localEventId: string,
    payload: CalendarEventPayload
  ): Promise<{ ok: boolean }>

  remove(localEventId: string): Promise<{ ok: boolean }>
}

type CalendarEventPayload = {
  title: string          // "PODO 영어 수업 with Sarah" or "PODO 영어 수업"
  startDate: string      // ISO with TZ
  endDate: string        // ISO with TZ
  location: string       // "PODO 앱"
  notes: string          // deep link back to lesson
  timeZone: string       // e.g. "Asia/Seoul"
  alarmMinutesBefore: number // 15
}
```

`update` and `remove` return `{ok: false}` if the event no longer exists in the OS calendar (user manually deleted it). Caller treats this as a no-op — no error UI.

---

## Local storage

- **Where**: `AsyncStorage` on the native side, accessed via the bridge.
- **Key**: `calendar:eventMap`
- **Value**: `Record<classId, localEventId>`
- **Also stored**: `calendar:optedIn` boolean, `calendar:promptDismissed` boolean (so we don't re-show the card after "아니요").
- **Lifecycle**: lost on app uninstall. Not synced across devices. Not synced to backend.

---

## Event payload

| Field | Value | Example |
|---|---|---|
| Title | `PODO 영어 수업 with {tutorName}` (omit `with` clause if not yet matched) | `PODO 영어 수업 with Sarah` |
| Start | Lesson start in user TZ | `2026-05-22 09:00 KST` |
| End | Start + `lessonTime` (15 / 25 / 55 min) | `2026-05-22 09:25 KST` |
| Location | `PODO 앱` (constant) | — |
| Notes | Deep link to lesson | `PODO 앱에서 수업을 시작하세요: https://podo.app/lesson/{classId}` |
| Time zone | Device TZ at booking time | `Asia/Seoul` |
| Alarm | -15 min, single | — |

For 무제한 users where the tutor is not yet matched at booking time, the title is `PODO 영어 수업` (no `with` clause). We do not push a calendar update later just because the tutor was assigned.

---

## Rollout

Single phased release behind GrowthBook flag `calendar_sync_v0`.

| Phase | Audience | Duration |
|---|---|---|
| Internal | Eng team + PMs | 3 days |
| 10% | Random app users | 1 week |
| 50% | If opt-in rate ≥ 20%, opt-out rate ≤ 15% | 1 week |
| 100% | Same criteria | — |

### Kill switch

Flipping `calendar_sync_v0` off:
- Stops the booking-success card from appearing
- Stops all bridge calls
- Does **not** retroactively remove already-written calendar entries (we leave them; they age out)

---

## Success metrics

| Metric | Target |
|---|---|
| Opt-in rate (among users who see the card) | ≥ 25% |
| Calendar-write success rate after opt-in | ≥ 98% |
| 30-day opt-out rate via Settings | ≤ 15% |
| Lesson no-show rate among opted-in vs. matched cohort | -3% relative (lower target than v1 because of the sync gaps) |

The no-show metric is the one that justifies going beyond v0. If opt-in is meaningful but no-show doesn't budge, we don't build v1.

---

## What v0 deliberately leaves broken

These are known gaps. Listing them so they don't get re-discovered as bugs:

- Admin-initiated changes (`changeByAdmin`, `cancelByAdmin`) don't update the calendar.
- Cancellations made from web (desktop or mobile browser, not the app) don't update the calendar.
- Cancellations made from another device don't update the calendar.
- If the user installs the app on a second phone, that phone's calendar is empty until they book new lessons there.
- If the user uninstalls and reinstalls, the old calendar entries are now orphaned (we can't update or delete them, only OS-level Calendar editing can).

All of these are addressed in [PRD.md](./PRD.md) (the full design). v0 ships with these gaps explicitly accepted.

---

## Appendix: file-level implementation hints

### Native shell (`/Users/johnsong/podo-app/apps/native`)

- Add `expo-calendar` to `apps/native/package.json`
- Extend `apps/native/src/core/app-bridge.ts` with the `calendar` namespace
- New `apps/native/src/shared/libs/calendar.ts` mirroring `register-push-notification.ts` shape
- iOS `Info.plist`: add `NSCalendarsFullAccessUsageDescription`:
  `"PODO 영어 수업을 잊지 않도록 캘린더에 자동으로 등록합니다."`
- Android `AndroidManifest.xml`: add `WRITE_CALENDAR`, `READ_CALENDAR`

### Web (`/Users/johnsong/podo-app/apps/web`)

- New hook: `apps/web/src/shared/hooks/use-calendar-bridge.ts`
- Hook into `apps/web/src/views/booking/hooks/use-booking-mutation.ts`:
  - `bookMutation.onSuccess` (line 71): render the offer card on first booking; otherwise just call `calendar.add`
  - `changeMutation.onSuccess` (line 106): if opted-in, call `calendar.update`
- Hook into `apps/web/src/entities/lesson/api/lesson.action.ts:811` (`cancelBookingAction`): after success, call `calendar.remove`
- New UI: booking-success calendar offer card
- New UI: Settings toggle row under 알림 section

### Backend

**No changes.**
