# PRD: Deferred NPS Prompt (Show NPS on Next App Foreground)

## Problem

Today, NPS only fires when a user clicks the in-app "나가기" button on the classroom page **after** the scheduled class end time. This is the only path that routes them to `/review-complete`.

Measured over the last 14 days:

- **16,778 real classes** (student + tutor both joined the meet)
- Only **1,248 (~7.4%)** ended up on `/review-complete`
- Only **889 (~5.3%)** submitted any NPS rating

The funnel collapses *before* the survey screen, not on the survey screen itself — among users who do reach `/review-complete`, ~75% submit a rating (the screen works fine).

The largest leak (~13,020 sessions over 14 days, ~78% of all real classes) is users who **left the classroom at or after class end, but did not click the "나가기" button** — they closed the app, used the OS back gesture, foregrounded another app, or let the iframe end the session itself. They show up on `/home` (or some other page) the next time we see them.

This PRD describes a "deferred NPS prompt" that catches that cohort: when they re-open or navigate around the app, we show them the NPS for the class they just attended.

## Goal

Recover most of the ~13,020 missing NPS opportunities per 2-week period without:

- Showing NPS to users who didn't actually attend a class
- Showing NPS multiple times for the same class
- Interrupting users who are currently in another class
- Interrupting checkout, login, onboarding, or other high-friction flows

Target: lift NPS reach from ~7% to ~50%+ of real classes (a 7× lift).

## Non-Goals

- Changing the NPS form itself (rating UI, reasons, etc. — those stay as-is)
- Adding a separate "rate later" reminder via push or alimtalk (that's a different lever)
- Showing NPS for AI character chat lessons, prestudy sessions, or replays
- Backfilling historical classes (only catch classes from the moment this ships forward)

## How NPS works today (status quo)

Reference: `apps/web/src/views/class-room/view.tsx:484-502`, `apps/web/src/views/lesson-review-complete/view.tsx`, `src/main/java/com/speaking/podo/applications/podo/nps/usecase/NpsService.java`.

1. User finishes class, clicks "나가기"
2. Client checks `isClassEnded = type === 'CLASS' && now >= unix_class_end_datetime`
3. If true → routes to `/lessons/classroom/{classID}/review-complete`
4. That page shows `NpsSurveyFlow` after a 2-second delay (gated by `tbd_260219_nps_inapp` flag, currently 100% rollout)
5. User rates → `POST /api/v1/lesson-review/nps` → backend saves a `NpsResponse` row keyed by (classId, studentId)
6. **Backend already enforces uniqueness**: `NpsService.submit()` throws if a row already exists for that (classId, studentId). This means duplicate-prevention is solved at the API level — the client just needs to avoid pestering users with a screen they've already seen.

There is no server-side record of "user saw NPS but skipped" — that only lives in ClickHouse events today. We need to add one (see "Backend changes" below).

## Class lifecycle context (relevant for trigger timing)

From `podo_mysql.GT_CLASS` analysis on the last 14 days of completed PODO classes:

| Field | Behavior |
|---|---|
| `CLASS_STATE = 'FINISH'` | Set when tutor marks class complete in tutor app. **Median 1 minute after scheduled end. Average ~9 minutes after.** Long tail goes to multiple hours in rare cases. |
| `COMP_DATETIME` | Timestamp of tutor completion. Populated for ~99% of FINISH classes. |
| `CLASS_STATE = NULL` | Mostly upcoming or canceled classes. |
| `CLASS_STATE = 'PREFINISH'` | Rare admin-only intermediate state (~0.3% of classes). |
| `CANCEL_AT IS NOT NULL` | Class was canceled. Should never trigger NPS. |
| `NOSHOW_DATETIME IS NOT NULL` | Student or tutor no-show. Should never trigger NPS. |

**Key implication for trigger gating:** if we wait for `CLASS_STATE = 'FINISH'`, we miss the cohort where the student finishes class, foregrounds the app within 30 seconds, and the tutor hasn't pressed "complete" yet (which is the **median** case). So we cannot use FINISH as the sole gate. Use scheduled end time + grace period instead, and use `CLASS_STATE` only as a *negative* gate (skip if explicitly CANCEL/NOSHOW).

## Eligibility — when a class is "pending NPS"

A class is "pending NPS" for a student if **all** of the following are true:

1. **Real class, not prestudy or AI**: `CLASS_TYPE = 'PODO'` and `IS_PRESTUDY != 'Y'`
2. **Student is the owner of the class**: `STUDENT_USER_ID = current user`
3. **Class scheduled end was in the past**:  
   `now >= class_end_datetime`  
   No additional grace buffer. The "don't show on classroom URL" suppression rule already prevents mid-class prompts, and the in-flow NPS path handles the case where the tutor runs slightly over. Adding a buffer here would only delay (and in early-finish cases, lose) prompts to users who already left.
4. **Class scheduled end was within the last 24 hours**:  
   `now <= class_end_datetime + 24h`  
   After 24 hours the rating becomes too stale to be meaningful and likely annoying.
5. **Class was not canceled or marked no-show**:  
   `CANCEL_AT IS NULL AND NOSHOW_DATETIME IS NULL AND CLASS_STATE NOT IN ('CANCEL', 'CANCEL_PAID', 'CANCEL_NOSHOW_T', 'NOSHOW_S', 'NOSHOW_BOTH')`
6. **Student actually attended**: at minimum, the student joined the meet for this class. Concretely, there exists a `meet_connected` (or stronger: `meet_participant_joined` with count ≥ 2) ClickHouse event tied to this class within the lesson window.  
   *Stretch:* if attendance signal is unavailable (event lost, etc.), fall back to "tutor marked class as `CLASS_STATE = 'FINISH'` (which implies attendance)." If neither signal is present, do **not** show NPS — better to miss than to ask someone who didn't attend.
7. **No prior NPS submission**: no row in `nps_response` for `(class_id, student_id)`.
8. **Not previously skipped**: no row in `nps_skip` for `(class_id, student_id)` (new table — see "Backend changes").

## User Journeys

### Journey 1 — "Closed the app right after class" (the dominant case)

1. Student finishes a regular 25-min class. Tutor says goodbye. Student switches to messaging app or backgrounds the browser tab.
2. ~10 minutes later they open the PODO app to check tomorrow's reservation.
3. App loads `/home`. Before rendering the home greeting, app calls `GET /api/v2/lecture/podo/getPendingNps`.
4. Response includes the most recent pending class (the one they just finished).
5. Client routes to `/lessons/classroom/{classId}/review-complete?source=deferred` — same NPS flow component as today.
6. Student rates → submitted → returns to `/home`.

### Journey 2 — "Used Android hardware back to leave class"

1. Student in classroom, presses Android back instead of "나가기".
2. WebView stays in classroom URL (the `useBackButtonClose` hook just shows a "press again to exit" toast — see `apps/native/src/shared/hooks/use-back-button-close.ts`).
3. Student gives up and closes the app via app switcher.
4. Treated identically to Journey 1 on next app open.

(See companion lever — "Hijack Android back inside classroom" — as a separate, more aggressive fix. This PRD assumes the hardware-back behavior stays as-is.)

### Journey 3 — "Back-to-back classes"

1. Student finishes class A at 09:25, has class B at 09:30.
2. They go straight to `/home` then to `/lessons/classroom/{B}` to enter class B.
3. `getPendingNps` returns class A. **Client must suppress the prompt while user is on a classroom URL or actively about to enter one.**
4. Student finishes class B at 09:55. Closes app.
5. At 10:30 student re-opens the app. `getPendingNps` returns class B (most recent first; class A also pending).
6. Client shows NPS for class B.
7. Student submits, returns to /home. App immediately re-checks `getPendingNps`. Now returns class A.
8. **Cap:** show **at most one** deferred NPS per app session. So class A is *not* shown immediately — it stays pending and shows on the next app open / next foreground transition. Two surveys back-to-back feels like spam.

### Journey 4 — "Rated, then re-opened the app"

1. Student just finished class, clicked "나가기" properly, rated NPS via the classic in-flow path.
2. They re-open the app 10 minutes later.
3. `getPendingNps` returns nothing for that class (the `nps_response` row already exists).
4. No prompt. Quiet behavior, as expected.

### Journey 5 — "Saw NPS, hit Skip, re-opened the app"

1. Student finished class, clicked "나가기", got to `/review-complete`, hit Skip.
2. Client fires `nps_survey_skipped` event AND calls `POST /api/v1/lesson-review/nps/skip` (new endpoint) which writes a `nps_skip` row.
3. They re-open the app later.
4. `getPendingNps` returns nothing for that class (skip row blocks it).
5. No prompt. The user got their chance and declined.

### Journey 6 — "Tutor marks class as no-show after the fact"

1. Student briefly opened the classroom but never spoke (e.g., camera off, no audio). Class technically ran.
2. Tutor later marks class as `NOSHOW_S` in the tutor app.
3. Student opens app at 10:30 — but `getPendingNps` is called BEFORE the tutor marks no-show, so it might still return this class.
4. **Trade-off:** the response is computed at the moment of the API call. We can't predict the future. If the tutor hasn't marked no-show yet, the student gets the prompt. If the tutor marks it later, the student already rated — backend will refuse to insert anything new (the rating already exists) but the `npsResponse` row stays. We accept this — a few stale ratings on no-show classes is acceptable noise; we don't try to scrub them.
5. **Mitigation:** require attendance signal (Eligibility rule #6) before showing the prompt. A class with zero `meet_connected` events for the student wouldn't be offered for NPS, even if not yet marked no-show.

### Journey 7 — "Tutor takes 30 minutes to mark class complete"

1. Class scheduled 09:00–09:25. Real class ends ~09:24. Student clicks "나가기" at 09:24:30 (before scheduled end) → routed to `/home` by the existing `isClassEnded` gate (no NPS via the in-flow path).
2. Student backgrounds the app. Tutor doesn't mark complete until 09:55.
3. Student foregrounds at 09:35. `getPendingNps` runs:
   - `now (09:35) >= scheduled_end (09:25)`? Yes.
   - `class_state` not in the cancel/no-show set? Yes (it's still `RESERVED` or `null`).
   - Attendance signal present (student joined the meet)? Yes.
   - No prior NPS, no prior skip? Correct.
   - **Returns this class as pending.**
4. Student gets prompted, rates, submits.
5. Tutor marks complete at 09:55. NPS already exists. No conflict.

This is the desired behavior — we do **not** wait on the tutor.

### Journey 8 — "Class never actually started (tutor no-show)"

1. Class scheduled 09:00–09:25. Student joined at 09:00. Tutor never joined.
2. Student waits 10 minutes, gives up at 09:10. No `meet_participant_joined ≥ 2` event fires.
3. Student opens app at 11:00.
4. `getPendingNps` runs. **Attendance rule #6 fails** — there's no signal that a real class happened (no tutor joined). Returns no pending class.
5. No prompt. (Tutor will eventually be marked no-show, separate flow handles refunds/credits.)

### Journey 9 — "Network was bad during NPS submission"

1. Student finished class, foregrounds the app, sees the NPS, rates 8, hits submit.
2. POST fails (network drop). Error toast shows ("제출에 실패했어요. 다시 시도해 주세요.").
3. Student backgrounds the app in frustration.
4. Re-opens app later. `getPendingNps` runs.
5. Backend has no `nps_response` row yet (the POST failed). Returns the class as pending again.
6. Student gets the prompt again. **This is correct** — they intended to rate but couldn't.

### Journey 10 — "User in middle of payment / onboarding / other critical flow"

1. Student opens app to complete a subscription purchase.
2. They navigate to `/subscribes/checkout`.
3. We do **not** want to interrupt this with an NPS prompt.
4. **Suppression rule:** the deferred prompt is only triggered on a defined allowlist of "safe" navigation targets — `/home`, `/reservation`, `/lessons` (list view only), `/my-podo`. It does not trigger from `/subscribes/*`, `/login`, `/onboarding`, `/lessons/classroom/*`, `/payment/*`, or any modal-active state.

## Technical Design

### Backend changes

#### 1. New endpoint: `GET /api/v2/lecture/podo/getPendingNps`

**Auth:** standard bearer token.

**Query logic:**

```sql
SELECT 
  c.ID                       AS class_id,
  c.TEACHER_USER_ID          AS tutor_id,
  c.CLASS_DATE,
  c.CLASS_END_TIME,
  c.unix_class_end_datetime  -- or compute server-side
FROM GT_CLASS c
WHERE c.STUDENT_USER_ID = :studentId
  AND c.CLASS_TYPE = 'PODO'
  AND COALESCE(c.IS_PRESTUDY, 'N') != 'Y'
  AND c.CANCEL_AT IS NULL
  AND c.NOSHOW_DATETIME IS NULL
  AND COALESCE(c.CLASS_STATE, 'OK') NOT IN ('CANCEL','CANCEL_PAID','CANCEL_NOSHOW_T','NOSHOW_S','NOSHOW_BOTH')
  AND TIMESTAMP(c.CLASS_DATE, c.CLASS_END_TIME) <= NOW()
  AND TIMESTAMP(c.CLASS_DATE, c.CLASS_END_TIME) >= NOW() - INTERVAL 24 HOUR
  AND NOT EXISTS (SELECT 1 FROM nps_response  WHERE class_id = c.ID AND student_id = :studentId)
  AND NOT EXISTS (SELECT 1 FROM nps_skip      WHERE class_id = c.ID AND student_id = :studentId)
  AND EXISTS  (
    -- attendance check via ClickHouse-mirrored attendance table OR the existing FINISH state
    /* see "Attendance signal" below */
  )
ORDER BY TIMESTAMP(c.CLASS_DATE, c.CLASS_END_TIME) DESC
LIMIT 1;
```

**Response:**

```json
{
  "pending": true,
  "class_id": 2607511,
  "tutor_id": 2930,
  "tutor_name": "Alice",
  "class_end_datetime_unix": 1745123456
}
```

or `{ "pending": false }` if nothing eligible.

Latency budget: < 100ms. Index `(STUDENT_USER_ID, CLASS_DATE)` likely already exists; verify before ship.

**Attendance signal** — pick one of:
- (preferred) Mirror `meet_participant_joined` event existence into a small `class_attendance(class_id, has_tutor_joined_at)` table updated by an event consumer. Cheap to query.
- (fallback) Use `CLASS_STATE = 'FINISH'`. Loses the "tutor hasn't completed yet" cohort but is safe and requires no new infrastructure.

Recommend launching with the fallback (FINISH only) and migrating to the attendance table in v2 once we measure how many users we miss with the conservative gate.

#### 2. New endpoint: `POST /api/v1/lesson-review/nps/skip`

Body: `{ classId: number }`. Writes a row to a new `nps_skip` table.

```
nps_skip
  id          BIGINT PK
  class_id    BIGINT (indexed)
  student_id  INT
  created_at  DATETIME
  UNIQUE (class_id, student_id)
```

Idempotent — repeated calls for the same (class, student) are no-ops.

This is needed because today "skipped" lives only in ClickHouse events, which is too lossy to gate "should we re-prompt?" on.

### Client changes

#### Web (`apps/web`)

**New hook:** `useDeferredNpsPrompt()`

- Lives in `features/lesson-review/hooks/use-deferred-nps-prompt.ts`
- Mounted in the root layout for `(internal)` routes (the authenticated app shell)
- On mount AND on each route change to a path in the safe-navigation allowlist, debounce-call `getPendingNps` (max once per 60 seconds)
- If a pending class is returned AND we haven't already shown a deferred prompt this app session, route to `/lessons/classroom/{classId}/review-complete?source=deferred`
- After the user submits or skips on that page, set a session-scoped flag `__deferred_nps_shown_this_session = true` so we don't re-prompt until the next app open

**Modify NpsSurveyFlow** (`features/lesson-review/ui/nps-survey/nps-survey-flow.tsx`)

- `handleSkip` currently fires the `nps_survey_skipped` event and navigates away. Add: also call `POST /api/v1/lesson-review/nps/skip` so the server records the dismissal.
- This applies to BOTH the in-flow path (clicking 나가기 → /review-complete → skip) and the deferred path. Both should be persistently "skipped".

**Modify `/lessons/classroom/[classID]/review-complete/page.tsx`**

- Read the `?source=deferred` query parameter and pass it through to `NpsSurveyFlow` for analytics tagging (so we can compare in-flow vs deferred submission rates).
- Behavior is otherwise identical.

**Modify `/views/class-room/view.tsx`**

- No change required for this PRD specifically. The existing `goBackPage()` path stays as-is. Users who leave early (the ~13% cohort from the other lever) will be caught by the deferred prompt on next foreground.
- (Combine with Lever 1 — drop the `isClassEnded` gate — for full coverage.)

#### Native (`apps/native`)

- The native shell wraps the web in a WebView. Most of the work is web-side.
- The `useAppState` hook (`apps/native/src/shared/hooks/use-app-state.ts`) already detects foreground/background. Add: on transition from `background` → `active`, inject a `window.postMessage({ type: 'app-foregrounded' })` into the WebView so the web layer can re-run `getPendingNps` even if no route change occurred.
- The web `useDeferredNpsPrompt` hook listens for that message in addition to route changes.

### Suppression rules (where the prompt MUST NOT show)

The deferred prompt is suppressed when ANY of these are true at the moment of the trigger check:

| Condition | Reason |
|---|---|
| Current path matches `/lessons/classroom/{id}` (no `/review-complete` suffix) | User is in or about to enter a class. Don't interrupt. |
| Current path is `/login`, `/onboarding/*`, `/payment/*`, `/subscribes/checkout/*` | Critical conversion flow. Don't interrupt. |
| Any modal / overlay is currently open (`overlay.isOpen()`) | Don't stack modals. |
| User has shown a deferred NPS already this app session | One per session cap. |
| Has the user has a class scheduled to start in < 10 minutes | They're about to enter prep mode. Don't interrupt. Check via existing `getNextLectureInfo` API or cache. |
| `getPendingNps` errored | Silent failure — never break user flow for the sake of a survey. |

### Frequency caps

- **Per app session**: max 1 deferred prompt
- **Per class**: max 1 prompt total (enforced by `nps_skip` row OR `nps_response` row)
- **Per user across sessions**: no cap beyond the per-class rule. If a user attends 3 classes in a day, they could legitimately see 3 deferred prompts spread across 3 separate app opens.

### Analytics (new ClickHouse events)

- `nps_deferred_prompt_eligible` — fired client-side when `getPendingNps` returns a class. Props: `{ classId, tutorId, secondsSinceClassEnd, suppressedReason: null | "in_classroom" | "modal_open" | "checkout" | "session_cap" | "upcoming_class" }`
- `nps_deferred_prompt_shown` — fired when we actually route the user to `/review-complete` from the deferred path. Props: `{ classId, tutorId, secondsSinceClassEnd }`
- `nps_survey_viewed`, `nps_rating_submitted`, `nps_survey_skipped` — already exist; add `source: 'inflow' | 'deferred'` prop so we can split rates by entry path

This lets us measure: of the eligible cohort, what fraction get the prompt (eligible vs shown), and what fraction submit (shown vs submitted), broken down by entry path.

## Rollout

1. **Backend ships first**: `getPendingNps` endpoint + `nps_skip` table + skip endpoint. Verify no perf regression on `/home` API budget. Verify duplicate prevention works end-to-end.
2. **Client ships behind a feature flag** `tbd_260X_nps_deferred_prompt` (defaults off). 
3. **Internal QA**: run through Journeys 1, 3, 4, 5, 7, 10 manually in stage.
4. **5% rollout for 1 week**. Compare to control:
   - Survey reach as % of real classes (target: > 25%)
   - Skip rate of deferred vs in-flow prompts (sanity — should be similar; if deferred skip rate is much higher, the prompt is annoying)
   - Average rating from deferred vs in-flow (sanity — meaningfully different ratings would suggest a self-selection issue)
5. **50% for 1 week**, then 100% if metrics look good.

## Open Questions

1. **Should we eventually also catch users via push notification** ("How was your class with Alice today?")? Out of scope for this PRD but worth considering as a follow-up if in-app reach plateaus.
2. **Should the deferred prompt look different from the in-flow one** (e.g., a smaller modal instead of a full-page takeover, since the user wasn't expecting it)? Recommend **same UI** for v1 — minimizes complexity, reuses the existing flow component. Re-evaluate if skip rate is unexpectedly high.
3. **What about classes attended on web but the user opens the mobile app later** (or vice versa)? `getPendingNps` is server-side and platform-agnostic, so this works for free.
4. **Do we need a grace period after scheduled end?** Current design says no — trigger immediately at `now >= scheduled_end`. If post-launch analytics reveal cases where the deferred prompt fires while the user is mid-wrap-up (e.g., racing the in-flow path because of some edge case the suppression rules miss), introduce a small buffer (30–60s) at that point. Don't add it preemptively.
