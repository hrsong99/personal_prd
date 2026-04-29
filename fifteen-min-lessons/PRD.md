# PRD: 15-Minute Beginner Lessons (Additive)

## Overview

We are introducing a second class-length tier — **15-minute beginner lessons** — alongside our existing 25-minute classes. 15-min lessons are **purely additive**: existing 무제한 (Unlimited) and 라이트 루틴 (Light Routine, monthly-8-ticket) subscribers gain the option to take 15-min lessons, but we are **not** retiring the 25-min product, **not** repricing, and **not** selling 15-min-only subscriptions. (We previously sold standalone 15-min subscriptions; that SKU is sunset and is not coming back.)

The goal is to reduce the activation barrier for true beginners — many of whom find a full 25-min English conversation with a native tutor intimidating — by giving them shorter, lower-stakes sessions inside the same plan they already pay for.

This is a **content-tier expansion**, not a product replacement. Every line of this PRD should be read with that frame.

---

## Goals

1. Beginners can pick a 15-min lesson from the lesson tab without changing their plan.
2. 무제한 users can substitute 1×25-min/day with 2×15-min/day at no extra cost, but cannot mix the two on the same day (the daily class budget is 25–30 min total).
3. 라이트 users can spend half a ticket on a 15-min lesson, so a single 8-ticket plan stretches up to 16 lessons if every lesson is 15-min, or 8 lessons if every lesson is 25-min, or any half-step combination.
4. The lesson tab surfaces both 15-min and 25-min courses side-by-side; each course is internally homogeneous (no mixed-length lessons inside a single course).
5. Admins can add new 15-min courses through `grape` and have them appear to all eligible users on the next refresh, without code deploys or per-user purchase records.
6. No regressions to the existing 25-min product, pricing, alimtalk copy, or subscriber commitments.

## Non-Goals

- **No new SKU** — 15-min lessons are not separately purchasable, not separately priced, and have no standalone subscription.
- **No mass migration of existing 25-min content to 15 min.** Existing 25-min courses stay 25 min, full stop.
- **No change to refund, cancellation, or no-show policies.**
- **No per-day cap on 15-min lessons for 라이트 users** — their cap is, and remains, their ticket balance. (Only 무제한 has the daily-budget rule.)
- **No mid-course swap.** A user enrolled in a 25-min course continues that course at 25 min until completion; switching tracks means starting a different course.
- **Not a timeline doc.** Sequencing is in §17, but launch dates are out of scope here.

---

## Glossary

| Term | Meaning |
|---|---|
| **Lesson type / 수업 시간 (`lessonTime`)** | The duration of a single lesson, in minutes. Today: `25`. After this PRD: `15` or `25`. (`55` exists as a legacy enterprise tier and is left untouched.) |
| **Course (`GT_CLASS_COURSE`)** | A bundle of curriculum content keyed by `(langType, curriculumType, lessonTime, level, week)`. Each course is internally one lesson type. |
| **Daily lesson budget (무제한)** | The set of `{count × lessonType}` combinations a 무제한 user is allowed to consume in a single user-local calendar day. After this PRD: `{1×25}` OR `{2×15}` OR `{1×15}` OR `{0}`. Mixing is forbidden. |
| **Ticket cost** | The fractional ticket count consumed by a single lesson booking. After this PRD: `1.0` for 25-min, `0.5` for 15-min. |
| **User-local day** | The calendar day in the user's device timezone, snapshotted at booking time (consistent with existing post-purchase-booking PRD's timezone treatment). |

---

## User Segments and Behavior

### 무제한 (Unlimited) — daily-budget rule

A 무제한 user's daily allowance is bounded by **at-once class budget ≤ 30 min**. The valid daily states are:

| Already booked today | Can additionally book |
|---|---|
| Nothing | 1×25 **or** 1×15 (and if 1×15 is chosen, may later add a 2nd 1×15) |
| 1×15 | 1×15 only (a 2nd 25-min would push total to 40 min → blocked) |
| 2×15 | Nothing — daily budget exhausted |
| 1×25 | Nothing — daily budget exhausted |

The **first booking of the day determines the allowed type for the rest of the day**, and a 무제한 user can hit at most 2 lessons in a day (and only if both are 15-min).

A booking flow for two 15-min lessons in a single transaction is supported (§7.3) and is the canonical path. A user can also book the second 15-min independently later in the day, subject to the same budget check.

Cancellations restore budget. If a user has a 1×25 booked for today and cancels, they regain the full 30-min budget for that day and can re-book either 1×25 or up to 2×15.

### 라이트 루틴 (Light Routine, 월 8회) — fractional-ticket rule

A 라이트 user's monthly ticket balance can now be spent in half-ticket increments:

- 25-min lesson = 1.0 ticket
- 15-min lesson = 0.5 ticket

There is **no daily class budget** for 라이트 — the only constraint is positive ticket balance. A 라이트 user with 8 tickets/month can take, for example, 8×25-min, or 16×15-min, or 4×25-min + 8×15-min — any combination summing to ≤ 8.0 ticket-equivalents.

Half-ticket consumption must round consistently and never accidentally permit "over-spending." See §13 for the data-model treatment.

### Other segments (out of scope, but covered by default)

- **Trial / promotional / Light Routine 12회 / business / etc.** — these inherit the same lesson-type-aware booking machinery, but the **default is "25-min only" unless an explicit flag enables 15-min for that segment**. Phase 1 launches with 무제한 and 라이트 only; other plans turn on later via the same GrowthBook flag (§17).

---

## Lesson Tab and Course Browsing

### Visibility rules

The lesson tab (지금 들을 수 있는 코스) shows a **mixed list of 15-min and 25-min courses** for every user whose plan supports 15-min content (Phase 1: 무제한 and 라이트 only).

Each course tile clearly displays its duration (e.g. `15분`, `25분` chip on the tile). Sort order: 25-min courses appear in their existing order; 15-min courses are interleaved by level/track relevance — the exact ranking is a follow-up tuning concern, but the simple rule for v1 is **"newest 15-min beginner content first, then existing 25-min sort."**

A course is internally homogeneous — every lesson inside `course X` shares the same `lessonTime`. There is no mixing within a course. The user understands "this course is a 15-min track" or "this course is a 25-min track" up front and that does not change once they start it.

### Filtering

A simple **duration filter** (`전체 / 15분 / 25분`) appears above the course list when the user's plan supports both. Users on plans that don't support 15-min do not see the filter at all and see only 25-min courses (current behavior preserved).

### What's NOT in lesson tab

- No "estimated time to complete this course" change. Course progression is still tracked by week-and-level, not minutes.
- No "switch this course to 15-min" affordance. The two are different courses.

---

## Booking Flow

### 7.1 Single-lesson booking (15-min)

Identical to the existing 25-min booking flow with one additional input: lesson-type selection, made implicit by the course chosen. When a user picks a 15-min course, the booking flow:

1. Filters tutor schedules to slots whose start minute is in **`{00, 20, 40}`** (matching the existing client-side rule in `grape/admin/matching/podo_mock_matching_tutors.php:375`).
2. Sends `lessonTime: 15` to the booking API.
3. On success, debits 0.5 ticket (라이트) or contributes 15 min to the daily budget (무제한).

### 7.2 25-min booking

Unchanged. Slot grid is `{00, 30}` per the same matching file (line 376). `lessonTime: 25` is sent. 1.0 ticket consumed (라이트) or 25 min daily-budget consumed (무제한).

### 7.3 Bundled 2×15-min booking (same booking session, 무제한)

A 무제한 user picking a 15-min course is offered the choice up front:

> 한 번에 15분 레슨 두 개를 잡으시겠어요? (오늘은 두 번까지 가능해요)
> [예, 두 개 잡기] [한 개만 잡기]

If they choose two:
- The slot picker shows pairs of available 15-min slots. A "pair" is any two 15-min slots on the same calendar day — they do **not** need to be consecutive, do not need to be the same tutor, and do not need to be in the same course week. The user picks each independently.
- The two bookings are submitted to the backend as one transaction. If either booking fails (e.g. the second slot got grabbed during selection), the entire transaction is rolled back and the user retries.

If they choose one:
- Standard single 15-min booking. The system remembers the user has used 1×15 today and, on the next visit, will show the "you can book one more 15-min today" promotion (see §16).

### 7.4 Bundled 2×15 booking does NOT have to be back-to-back

Explicitly: **back-to-back is a permitted but not required pattern.** Users with childcare windows, lunch breaks, or split availability can do 9:00 + 14:00 just as easily. The slot picker sorts pairs by time but does not enforce adjacency.

A "back-to-back convenience" affordance — one tap to fill the slot immediately after the first — is a nice-to-have and tracked as a future enhancement, not a v1 blocker.

### 7.5 Independent second 15-min booking later in the day

If a user has already booked one 15-min lesson today and returns later to book another, the booking flow:

- Permits picking another 15-min course (any 15-min course, not just the same one as the first).
- **Does not** permit picking a 25-min course (the daily-budget rule blocks it). 25-min courses appear in the lesson tab but with a disabled CTA and an explanatory tooltip:

  > 오늘은 이미 15분 레슨이 잡혀있어 25분 레슨은 예약할 수 없어요. 내일부터 다시 가능합니다.

### 7.6 Booking rejection messages

When a booking is rejected at submission time due to a budget conflict (e.g. someone slipped a 25-min booking in just before the user's 15-min request landed), the API returns a structured error and the FE shows a clear message:

| Reject reason | User-facing copy |
|---|---|
| `DAILY_BUDGET_MIXED` | 오늘은 이미 다른 길이의 수업이 잡혀있어요. 같은 길이로만 예약할 수 있어요. |
| `DAILY_BUDGET_EXHAUSTED` | 오늘 예약 가능한 수업을 모두 잡으셨어요. 내일부터 다시 예약할 수 있어요. |
| `INSUFFICIENT_TICKETS` (라이트) | 남은 티켓이 부족해요. 15분 레슨은 0.5 티켓이 필요합니다. |

---

## Cancellation, Rescheduling, No-Show

### Cancellation

Cancellation rules unchanged in shape. Specific to this PRD:

- Canceling a 15-min lesson restores 0.5 ticket (라이트) or 15 min of daily budget (무제한).
- Canceling one of a 2×15 bundle does **not** auto-cancel the other. Each is independent.
- A cancellation that frees up the daily budget makes the user immediately eligible to re-book any allowed type, including switching from 15 to 25 — provided the cancellation is processed before the second 15-min lesson (if any) takes place.

### Rescheduling

Lesson type cannot change on a reschedule. A 15-min lesson reschedules to another 15-min slot only (preserving `lessonTime`). To switch types, the user cancels and re-books.

### No-show

Existing no-show rules apply per booking. A no-shown 15-min lesson consumes its 0.5 ticket (라이트) and its 15-min daily-budget share (무제한) — same as a no-shown 25-min lesson today consumes its 1.0 ticket and full budget.

---

## Lesson Delivery / In-Class Behavior

### Auto-kick timer

The auto-kick warning + countdown logic in `podo-app/apps/web/src/views/class-room/config/auto-kick.ts` already reads `unixClassEndDatetime` from the API. **No code change** required — the API will simply send `scheduledAt + 15 min` for 15-min lessons. Verify behavior:

- 15-min lesson: warning at the 5-min mark (relative grace period), kick at end-of-class + grace.
- 25-min lesson: unchanged.

If the existing 10-min warning + 3-min kick grace from `auto-kick.ts:7,10` looks wrong scaled to 15 min, see §16.6 for the proposed proportional grace policy.

### Phase indicator / pacing

The classroom UI does not currently surface phase-level pacing. No change needed in v1. Content delivery (Lemonade) is responsible for pacing within the lesson window and content authors will produce 15-min variants directly inside `GT_CLASS_COURSE` rows.

### Live-tutor experience

Tutor in-lesson UI (delivered via the tutor-side app, separate from `grape`) needs to display the lesson length on the call card. Whatever component already shows "25분" today reads from the lesson record — feeding it `15` will Just Work. The tutor side's lesson-detail flow has been validated to dynamically render `LESSON_TIME` already (see `grape/admin/podo_class_detail.php:196,841,845` — admin already handles `LESSON_TIME == 15`).

---

## Admin Tooling (grape)

### 10.1 Course creation — primary admin requirement

Admins must be able to **create new 15-min courses** through `grape` and have those courses immediately visible to all 무제한 / 라이트 users in the lesson tab, without per-user purchase records or code deploys.

Today, course creation in `grape` lives near `podo_class_detail.php` and the curriculum-popup flow at `grape/admin/popup/podo_course_list.php`. The popup already accepts a `LESSON_TIME` parameter and filters courses by it. The course-creation form needs:

- A `LESSON_TIME` selector with options `15` and `25` (and `55` if it remains in the dropdown for legacy admin purposes; do not remove).
- A `IS_BEGINNER_15` boolean (or analogous tag) so curriculum operators can mark a 15-min course as the introductory beginner track. This drives sort order in the lesson tab.
- Validation: a 15-min course cannot have lessons whose start time violates the `{00, 20, 40}` rule (this rule lives in metadata, not in course content, so this validator is for tutor-base-schedule pages, not the course form itself — see 10.3).

### 10.2 Visibility removal of `isBasicPurchased15`

The current `LectureQueryServiceImpl.java:1822` flag `isBasicPurchased15` gates 15-min course visibility on whether the user purchased the legacy 15-min subscription. **This flag must be removed (or globally true-d) for the lesson tab.** Replacement logic:

- For Phase 1 plans (무제한, 라이트): the lesson tab returns 15-min courses unconditionally.
- For other plans: 25-min only, until the rollout flag turns them on.

`isBasicPurchased15` may still be relevant for *progress* tracking (a user who completed week 3 of a 15-min basic course should resume there) — that's a separate concern from listing-time visibility. Keep the progress-tracking semantics; remove only the listing gate.

### 10.3 Tutor base-schedule page (`grape/admin/podo_tutor_base_schedule_edit.php`)

Tutor base schedules today render in 30-min increments and feed downstream slot generation. After this PRD:

- A tutor's base availability may need to be expressible at 15-min resolution if we want to maximize 15-min slot density. Cheapest path: keep base schedules at 30-min, and let the booking layer split a 30-min slot into either a single 25-min booking *or* a single 15-min booking *or* a 2×15-min booking, using the existing slot-start rule (`{00, 20, 40}` for 15-min, `{00, 30}` for 25-min). This means a single 30-min tutor block at `9:00–9:30` can host either:
  - one 25-min lesson at 9:00, OR
  - one 15-min lesson at 9:00 (leaving 9:15–9:30 idle), OR
  - one 15-min lesson at 9:00 and one at 9:20 (using `00, 20, 40` grid, with 9:35–9:30 hosting the second only if the tutor has the next 30-min block too).

  This last case crosses 30-min block boundaries and is the trickiest piece — see §16.3 for the boundary rule.

**Recommendation for v1:** keep tutor scheduling at 30-min resolution; do not add a 15-min editing UI to `grape`. The slot-start rules let us host 15-min lessons inside existing 30-min blocks without changing how tutors enter availability.

### 10.4 Class detail and per-class admin actions

`grape/admin/podo_class_detail.php` already branches on `LESSON_TIME == 15` and `LESSON_TIME == 55` (lines 841, 845). The change is to surface 15-min as a normal expected case rather than a legacy edge case — primarily a copy and UX-polish pass.

### 10.5 Admin-facing back-to-back display

When a 무제한 user has booked a 2×15 same-day pair, admin views (`podo_class.php`, the class list) should visually group them under a single "user-day" row to match the booking model. This is a small grouping addition, not a data model change.

---

## Tutor Compensation

### 11.1 Per-lesson rate decision

Two clean options. **Recommendation: Option B (proration) for v1.**

| Option | Mechanism | Pro | Con |
|---|---|---|---|
| **A — Flat per-class rate, new tier for 15-min** | Define a separate KRW rate for 15-min lessons. | Tutors clearly see two rates. Admin can promote 15-min content with a higher per-minute rate to incentivize tutor uptake. | Rate negotiation needed; payroll system needs a new SKU. |
| **B — Proration at 15/25** | A 15-min lesson pays `existing_25min_rate × (15/25) = 0.6×` per class. | Zero contractual renegotiation needed for v1 — pure math. Implement once, applies to all tutors. | Tutors who do many 15-min lessons earn proportionally less per hour after factoring context-switch overhead. Possible morale issue. |

If Option B is chosen, the `÷25` divisor in `grape/app/android/process/payment_complete_vbank.php:154,263–265` and the `× 25` in `grape/app/android/process/class_ps.php:57` must both be replaced with a per-row `LESSON_TIME` lookup. This is the highest-care file group in this entire PRD — see §14.4.

### 11.2 Tutor incentive thresholds

The existing tutor-incentive milestone scheme (`personal_prd/tutor-incentive/`) ladders by completed-lesson count. After 15-min lessons launch, the policy is: **a 15-min lesson counts as 0.6 milestones** (mirroring proration). This avoids tutors gaming the system with high-volume short lessons. Memo this decision in the next tutor incentive doc revision.

### 11.3 Tutor opt-in

Tutors are **not** required to deliver 15-min lessons. A `WILLING_TO_TEACH_15MIN` flag on the tutor profile gates whether a tutor's slots surface for 15-min booking. Default: `false`, with a tutor-side toggle to opt in. Admin can also flip the flag in `grape`.

---

## Notifications and Alimtalk

### 12.1 Lesson-confirmation alimtalk

Existing booking-confirmation templates (`pd_reg_weeklyclass_2`, `pd_reg_infinity_2`, etc.) use `{Lessonterm}` parameter — they will substitute `15` automatically and require **no template change** for the substitution itself.

However: template **N2** (`personal_prd/post-purchase-booking/PRD-addition-2-alimtalk-ko.md`) contains the marketing claim:

> "{Lessonterm}분 레슨만으로 원어민과의 5시간 대화만큼 실력 향상 효율을…"

This claim was calibrated for 25 min and should not auto-substitute to "15분 레슨만으로 5시간 대화 효율." Action:

- Fork N2 into N2a (25-min variant — current copy) and N2b (15-min variant — new copy with a different value claim, drafted by the marketing team).
- Backend selects N2a or N2b based on the booked lesson's `lessonTime`.

### 12.2 2×15 booking confirmation

When two 15-min lessons are booked in a single transaction, send **one** alimtalk that announces both, not two separate ones, to avoid notification fatigue:

> 오늘 15분 레슨 2개를 모두 예약했어요!
> ① {time1} {tutor1}
> ② {time2} {tutor2}

If the two are booked in separate sessions (one earlier in the day, one later), send two separate confirmations as today.

### 12.3 Daily-budget exhaustion notification

When a 무제한 user completes their second 15-min lesson of the day, send a celebratory push: "오늘 두 번째 15분 레슨까지 완료했어요!" — reinforces the new behavior. This is purely additive; do not retrofit equivalent copy into the 25-min path.

### 12.4 Reminder timing

Pre-class reminders (e.g. 30 min before) carry no duration semantics inside the message body — they reference `{class_time_range}` like `09:00~09:15`, which the existing template variables handle correctly with the new `lessonTime`. **No change required**.

---

## Data Model Changes

### 13.1 `GT_CLASS` (lecture record) — `LESSON_TIME` column already exists

Per `grape/admin/podo_class_detail.php:34,53`, `GT_CLASS_TICKET` already has a `LESSON_TIME` column and lectures are joined to it. The frontend schema `lectureTicket.ts:33` carries the same column with a default of `25`.

**Required changes:**

- Allow `LESSON_TIME = 15` to be set on lecture records (no schema migration; it's already an `int`).
- Add a backend validator that rejects `LESSON_TIME` values outside `{15, 25, 55}` rather than letting any integer through.
- The current invariant in `LectureRegistRequestDto.java:64–67` —
  ```
  if(min % Ticket.ClassTimePerOneTicket != 0)  // ← throws on 15-min!
      throw new IllegalArgumentException("Wrong class start/end time");
  this.nTicket = Math.toIntExact(min / Ticket.ClassTimePerOneTicket);
  ```
  — must be replaced. New rule:
  ```
  if (min == 15) { ticketCost = 0.5; nTicket = 1; /* row counts but consumes half */ }
  else if (min == 25) { ticketCost = 1.0; nTicket = 1; }
  else if (min == 55) { /* legacy untouched */ }
  else throw IllegalArgumentException("Unsupported lesson length: " + min);
  ```

  See §13.3 for `ticketCost` storage.

### 13.2 `GT_CLASS_COURSE` — already keyed by lessonTime

`GT_CLASS_COURSE` is keyed by `(lang, curriculumType, lessonTime, level, week)` per `LectureQueryServiceImpl.java:485,511,614`. **No schema change**. Admins simply create new rows with `LESSON_TIME = 15`.

Add an `IS_BEGINNER_15` (or similar) tag column to mark courses that should sort first for newcomer users. This is purely a UX tag and can be a `TINYINT(1)` default 0.

### 13.3 Ticket consumption — fractional units

The hard problem. Current `ClassTimePerOneTicket = 25L` (in `Ticket.java`, `Card.java`, `Board.java`, `SubscribeMapp.java`) encodes "1 ticket = 25 min."

**Recommended approach: introduce a `TICKET_COST` decimal column on the lecture-ticket join, default `1.0`, and use it as the source of truth for ticket consumption.** Existing rows backfill to `1.0`.

```sql
ALTER TABLE GT_CLASS_TICKET ADD COLUMN TICKET_COST DECIMAL(3,1) NOT NULL DEFAULT 1.0;
UPDATE GT_CLASS_TICKET SET TICKET_COST = 1.0 WHERE TICKET_COST IS NULL;
```

Booking creates a ticket-consumption record with `TICKET_COST = 0.5` for 15-min and `1.0` for 25-min. Cancellation refunds the same. Light's "remaining tickets" UI sums `TICKET_COST` instead of counting rows.

The `ClassTimePerOneTicket` constant stays at `25L` and continues to mean "minutes-per-full-ticket" for backwards compatibility — but no new code should multiply or divide by it. New code reads `TICKET_COST` directly. (See §17.3 for the cleanup plan.)

### 13.4 무제한 daily-budget tracking

No new table needed. The daily budget is computed on demand by querying existing lectures for the user's local day:

```
SELECT lessonTime, COUNT(*) 
FROM GT_CLASS 
WHERE STUDENT_ID = ? 
  AND CLASS_DATE_TIME >= start_of_local_day 
  AND CLASS_DATE_TIME < end_of_local_day
  AND STATUS NOT IN (CANCELLED, ...)
GROUP BY lessonTime
```

A user is allowed a new booking iff:
- Result rows are empty, OR
- All rows have `lessonTime = 15` AND total count < 2 AND requested booking is also `lessonTime = 15`.

This check lives in `PodoScheduleServiceImplV2` next to the existing `BonusPlanType.UNLIMITED` branch at line 1119.

### 13.5 Tutor `WILLING_TO_TEACH_15MIN` flag

New column on the tutor profile table. Default `0`. Admin-editable. Tutor-app-editable.

```sql
ALTER TABLE GT_TUTOR ADD COLUMN WILLING_TO_TEACH_15MIN TINYINT(1) NOT NULL DEFAULT 0;
```

The tutor-availability query that surfaces slots to learners must filter on `WILLING_TO_TEACH_15MIN = 1` when the requested `lessonTime = 15`.

---

## API Changes

### 14.1 Booking endpoint

`POST /api/v3/schedule/book` (or whichever current endpoint serves) accepts a new field:

```
{
  "tutorId": 123,
  "scheduledAt": "2026-05-01T09:00:00Z",
  "courseId": 456,
  "lessonTime": 15,        // NEW — required, 15 or 25
  "bundleWithBookingId": null  // NEW — for 2×15 bundling, see below
}
```

For 2×15 bundles, the FE submits two separate booking requests in a single multi-call transaction; if the backend prefers a single endpoint, accept an array body. Recommendation: array body for atomicity.

### 14.2 Lesson tab endpoint

`GET /api/v2/lecture/getLectureCourseList` (`LectureQueryServiceImpl.java:1808`) returns 15-min courses unconditionally for Phase 1 plans. Add a filter param:

```
GET /api/v2/lecture/getLectureCourseList?lessonTime=15  // or 25, or omit for both
```

### 14.3 Daily-budget probe endpoint

`GET /api/v3/booking/daily-availability?date=YYYY-MM-DD&tz=Asia/Seoul`

Returns the user's remaining budget for that local day:

```
{
  "plan": "UNLIMITED",
  "remaining": {
    "canBook25": false,    // already booked 1×15 today
    "canBook15": true,
    "canBook15Count": 1    // 0..2
  }
}
```

The frontend reads this to enable/disable course CTAs and to surface the "you can book one more 15-min today" prompt. For 라이트, the response includes `remainingTickets: 7.5` etc.

### 14.4 Tutor schedule endpoint

`GET /api/v3/schedule/getTutorSchedulesForReg` accepts `lessonTime` and:

- For `lessonTime=15`: returns slots whose start minute ∈ `{00, 20, 40}`, only from tutors with `WILLING_TO_TEACH_15MIN=1`.
- For `lessonTime=25`: unchanged.

### 14.5 Cancel / reschedule endpoints

No signature change. Backend logic refunds based on the booked lecture's actual `lessonTime` and `TICKET_COST`.

---

## Backend Logic Changes (file-by-file)

### 15.1 `podo-backend` — Java/Kotlin

| File | Change |
|---|---|
| `applications/lecture/dto/request/LectureRegistRequestDto.java:64-67` | Replace the `% 25 == 0` invariant with the lesson-type-aware logic in §13.1. **Critical** — current code throws on 15-min. |
| `applications/podo/schedule/usecase/PodoScheduleServiceImplV2.java` (around line 1119, the `BonusPlanType.UNLIMITED` branch) | Add daily-budget check per §13.4 before creating the lecture. Reject with `DAILY_BUDGET_MIXED` or `DAILY_BUDGET_EXHAUSTED`. |
| `applications/lecture/service/query/LectureQueryServiceImpl.java:1822-1910` | Remove `isBasicPurchased15`-as-listing-gate. Have `getLectureCourseList(...)` return both 15-min and 25-min for 무제한/라이트 users in Phase 1. Keep `isBasicPurchased15` for progress resumption only. |
| `applications/purchaseBonus/service/StartingLessonResolverService.java:49` (`DEFAULT_LESSON_TIME = 25`) | Stays `25`. The constant defines the default for first-time post-purchase auto-booking, not the only possible value. |
| `applications/ticket/domain/Ticket.java`, `Card.java`, `Board.java`, `SubscribeMapp.java` (`ClassTimePerOneTicket = 25L`) | **Do not delete.** Mark as deprecated for new logic; new code uses `TICKET_COST` per row. |
| `applications/coupon/dto/response/ApplyConditionGetForSubDto.java` | Already documents `[15, 25, 55]`. No change. |
| New: `applications/podo/schedule/service/DailyBudgetService.java` | New service that encapsulates §13.4 rules. Called from `PodoScheduleServiceImplV2` and from the new daily-availability endpoint. |
| New: `applications/podo/schedule/dto/error/BookingRejectReason.java` | Enum: `DAILY_BUDGET_MIXED`, `DAILY_BUDGET_EXHAUSTED`, `INSUFFICIENT_TICKETS`, `TUTOR_NOT_15MIN_OPT_IN`, `INVALID_15MIN_SLOT_START`. |

### 15.2 `grape` — PHP

| File | Change |
|---|---|
| `app/android/process/payment_complete_vbank.php:154,263-265` | **Highest-care change.** Replace `÷25` divisor with `÷ row.LESSON_TIME` lookup. Run a parallel-run reconciliation in staging for one full payroll cycle before promoting. |
| `app/android/process/class_ps.php:57` (`(GC.TICKET_COUNT * 25) AS CLASS_MINUTE`) | Replace with `(GC.TICKET_COUNT * GCT.LESSON_TIME) AS CLASS_MINUTE` (joined to the ticket table for actual length) or store `LESSON_TIME` directly on `GT_CLASS` rows. |
| `app/android/process/t_class_v5_ps.php:3106` (notification body `(TICKET_COUNT * 25)분 수업`) | Use the actual booked `LESSON_TIME` per row. |
| `admin/process/podo_class_ps.php:317,779` (`+ INTERVAL 25 MINUTE`) | Use lesson record's `LESSON_TIME` to derive `INTERVAL N MINUTE`. |
| `admin/process/first_study_ps.php:96` (`+25 minutes` for trial end) | Trials remain 25 min for now (out of scope). Keep, but extract to a constant for future flexibility. |
| `admin/podo_tutor_schedule_edit.php`, `admin/popup/podo_course_list.php`, course-create form (location TBD) | Add `LESSON_TIME = 15` option in dropdowns. Already partly there for the 15-min slot-start rule (`admin/matching/podo_mock_matching_tutors.php:375`). |

---

## Frontend Changes (file-by-file)

### 16.1 `podo-app`

| File | Change |
|---|---|
| `apps/web/src/server/infrastructure/database/schema/lectureTicket.ts:33` | DB-default for `LESSON_TIME` stays `25`. No change. The default applies only to ticket-spawning, not to bookings. |
| `apps/web/src/views/post-purchase-booking/select-view.tsx` | Add lesson-type chooser at the top when the selected course is 15-min. Add 2×15-bundle slot picker per §7.3. |
| `apps/web/src/features/post-purchase-booking/` (level-selection) | Add `15분 / 25분` filter chip above the course list. Hide the chip for plans without 15-min support. |
| `apps/web/src/views/class-room/config/auto-kick.ts` | No change to constants; the timer is API-driven. **However**, validate that the existing 10-min warning + 3-min kick (`AUTO_KICK_WARNING_DELAY_S = 10*60`, `AUTO_KICK_COUNTDOWN_S = 3*60`) feels right when scaled to a 15-min lesson — see §16.6. Likely needs a per-lesson-type override. |
| `apps/web/src/features/payment-type/ui/*` (the 5 payment-type UIs that hardcode `25분`) | **No change in v1.** These are paid-product descriptions and the SKUs themselves stay 25-min-flagged. Adding 15-min as a beginner option does not require rewriting product copy. |
| `apps/web/src/features/onboarding/screens.tsx:783`, `apps/web/src/features/onboarding/home-widget.tsx:247`, `apps/web/src/views/trial-subscribes/view.tsx:564` (`25분` hardcoded copy) | **No change in v1.** These describe the trial and onboarding promise, both of which remain 25-min. |
| `apps/web/src/entities/feature-flag/api/feature-flag.api.ts` + `apps/web/src/shared/constants/feature-flags.ts` | Add new flags: `FIFTEEN_MIN_LESSONS_ENABLED` (Phase 1 plans only), `FIFTEEN_MIN_BUNDLED_BOOKING_ENABLED` (gates the 2×15 in-flow UX). |
| `apps/web/src/shared/types/subscription.ts:16,27` | Already supports `25 \| 50`. Extend to include `15`. (Line 50 hint: there's also `50` which is probably the legacy `2×25` — out of scope for this PRD.) |

### 16.2 Auto-kick scaling (§16.6 anchor)

The existing kick policy was sized for 25-min: 10-min warning before end + 3-min kick countdown after end. Scaling proportionally to 15-min:

- **Recommended:** keep absolute values (warning at 10 min into the 15-min lesson, i.e. with 5 min remaining; kick 3 min after end). This means the warning is more aggressive (66% of class elapsed vs 40% for 25-min) — likely fine, but a stakeholder review is warranted before launch.
- **Alternative:** scale to `lessonTime × 0.4` for warning and a flat 2-min kick.

Decide before launch; document the chosen rule in `auto-kick.ts`.

---

## Edge Cases

### 17.1 Course content authored for 15 min but mistakenly tagged 25 min (or vice versa)

Validation: when an admin saves a `GT_CLASS_COURSE` row with `LESSON_TIME=15`, ensure all child lesson assets are present and timed for 15 min. This is a data-quality concern, not a runtime check — handle as a CMS-side validator in the course-create form (not a hard backend reject).

### 17.2 User books 1×15 today, then admin adds a make-up class manually for them at 25-min that pushes their daily into a forbidden state

Admin actions bypass the daily-budget rule by design (admin overrides have always trumped user-side rules). However, the schedule view should show a soft warning ("This user already has a 15-min lesson today — this 25-min booking violates daily-budget policy. Continue?") in `grape`.

### 17.3 Existing data — `ClassTimePerOneTicket = 25L` cleanup

Long-term, all four domain entities replicating `ClassTimePerOneTicket` can be deprecated in favor of `TICKET_COST`. The cleanup is **not required for v1** — leaving the constants in place and unused does no harm. Schedule a follow-up cleanup PR ~3 months post-launch once we're confident no production code path still depends on the constant.

### 17.4 Tutor not opted in (15-min)

A 무제한 user picks a 15-min course but only sees 25-min slot times because no tutors with the course's required level are 15-min-opted-in. Frontend shows:

> 15분 레슨이 가능한 튜터가 곧 추가될 예정이에요. 다른 코스를 살펴보거나, 알림을 받아보세요.

Track demand here for tutor-recruitment prioritization.

### 17.5 30-min slot boundary crossing for 2×15 same-tutor bookings

When a 2×15 bundle wants to use back-to-back slots like 9:00 (slot1) and 9:20 (slot2), and these straddle two 30-min tutor blocks (9:00–9:30 and 9:30–10:00), the second slot at 9:20 only has 10 min of the first block left and would need to draw 5 min from the next block. Conservative v1 rule: **slot2 of a 2×15 bundle must end within a single tutor 30-min block** — i.e. slot2-end-time minute ≤ block-end. Practical implication: 2×15 with the same tutor must use slot starts `{(00, 20)}` or `{(20, 40)}`, with the second 15-min lesson ending at 35 or 55 — both within the 30-min block. No cross-block bookings. Different tutors: no constraint, both slots are independently valid.

### 17.6 Light user with exactly 0.5 tickets remaining

This is now possible (was always rounded to integer ticket counts before this PRD). UI must:

- Show "0.5 tickets remaining" cleanly (e.g. `남은 티켓: 0.5장`).
- Allow booking one more 15-min lesson.
- Block 25-min booking with copy: "남은 티켓이 부족해요. 25분 레슨은 1장이 필요합니다. 15분 레슨은 가능해요."

### 17.7 Trial class still 25 min

Trial classes (and the post-purchase first-lesson auto-booking via `StartingLessonResolverService`) remain 25-min. The trial product is a marketing landing-page promise (`'25분 무료 체험\n한번이면 충분해요'`) that we are not breaking in this PRD.

A future enhancement could offer a "15-min trial" variant; out of scope here.

### 17.8 Coupon application

`ApplyConditionGetForSubDto` already documents `lessonTime ∈ [15, 25, 55]`. Confirm that any existing per-lesson-time coupon condition logic correctly evaluates against `15` — it should, because the field is already there. Add an integration test for "coupon valid for 15-min lessons only" + "coupon valid for any lesson time."

### 17.9 Post-purchase bonus window calendar cap

The post-purchase booking PRD's calendar cap logic states: *"lesson length is 25 minutes, so any lesson booked through this flow is structurally completable inside the initial window."* Becomes more permissive with 15 min — every existing calendar slot still passes. No change required, but add an explicit unit test confirming a 15-min booking at the very edge of the bonus window passes the same check.

### 17.10 NPS deferred prompt timing

The NPS PRD's class-end timing depends on `class_end_unix` only. With 15-min lessons, the trigger fires at `start + 15` instead of `start + 25`. **No code change.** Add a regression test confirming NPS fires at the correct relative offset for both lengths.

---

## Existing-System Alignment Notes

This section mirrors the post-purchase-booking PRD's "Existing-system alignment notes" pattern. Findings:

- **`isBasicPurchased15` was scaffolded for a sunset SKU and is now misnamed.** Renaming it to `hasFifteenMinAccess` (or removing it from listing logic entirely, per §10.2) is recommended for clarity. Existing rows that rely on it for progress tracking are unaffected.
- **The 15-min slot-start rule (`{00, 20, 40}`) already exists in `grape/admin/matching/podo_mock_matching_tutors.php:375`** and is the canonical source. The frontend booking UX must consume the same rule from a shared API endpoint, not re-implement it. Recommend adding a `GET /api/v1/config/slot-start-rules` endpoint that returns:
  ```
  { "15": ["00","20","40"], "25": ["00","30"], "55": ["00"] }
  ```
- **`GT_CLASS_TICKET.LESSON_TIME` is already an int column with a 25 default** (`apps/web/src/server/infrastructure/database/schema/lectureTicket.ts:33`). No DDL change required for this column.
- **Coupon DTOs already document `[15, 25, 55]`** (`ApplyConditionGetForSubDto`). No code change required there for v1.
- **The auto-kick timer is API-driven** (`apps/web/src/views/class-room/config/auto-kick.ts`). The timer adapts automatically; only the kick-grace policy needs a per-lesson-type review.
- **`grape/admin/podo_class_detail.php` already has `LESSON_TIME == 15` branches** (lines 841, 845). The admin tool partially predicts this PRD; we are completing the work, not starting it.
- **Tutor compensation files (`payment_complete_vbank.php`, `class_ps.php`, `t_class_v5_ps.php`) hardcode `÷25` and `×25`.** These are the highest-risk files in the PRD and need careful migration with parallel-run validation.

---

## Migration & Rollout

### 18.1 GrowthBook flags

Three flags to gate rollout:

| Flag | What it gates | Default |
|---|---|---|
| `FIFTEEN_MIN_LESSONS_ENABLED` | Whether 15-min courses appear in the lesson tab and are bookable. | `false`, ramp by user-id %. |
| `FIFTEEN_MIN_BUNDLED_BOOKING_ENABLED` | Whether the 2×15 in-flow booking UX is shown. (Single 15-min booking can launch first, bundle UX second.) | `false`. |
| `FIFTEEN_MIN_LIGHT_HALF_TICKET_ENABLED` | Whether 라이트 users can spend 0.5 tickets. (Allows decoupling 무제한 launch from 라이트 launch if QA reveals issues.) | `false`. |

### 18.2 Ramp plan

- **Week 1:** Internal users only (Day1 employees, content team) — 100% of internal account IDs.
- **Week 2:** 5% of 무제한 users (single 15-min booking only; bundle disabled).
- **Week 3:** Add 2×15 bundle booking to the same 5%.
- **Week 4:** Add 라이트 fractional ticket consumption to the same 5%.
- **Week 5–6:** Ramp to 25%, 50%, 100% sequentially with payroll reconciliation gating each step.

Hold gates between phases on:
- Tutor payroll variance < 1% from expected.
- 무제한 daily-budget violation rate ≈ 0.
- 라이트 ticket-balance consistency (sum of `TICKET_COST` per user matches `purchased - refunded` exactly).

### 18.3 Cleanup follow-ups

Schedule a cleanup agent ~3 months post-launch to:

1. Remove `ClassTimePerOneTicket` constants from the four domain entities (§17.3).
2. Rename `isBasicPurchased15` to `hasFifteenMinAccess` or fold its remaining usages into a more general progress-tracking field.
3. Re-verify no PHP file still does `÷25` or `×25` for revenue/payroll math.

---

## Acceptance Criteria

A 무제한 user can:
- ✅ See both 15-min and 25-min courses in the lesson tab when `FIFTEEN_MIN_LESSONS_ENABLED=true`.
- ✅ Book a single 15-min lesson; the daily budget records 15 min consumed.
- ✅ Book a second 15-min lesson the same day; the daily budget records 30 min consumed.
- ✅ Be **blocked** from booking a 25-min lesson same day after a 15-min booking, with the correct error copy.
- ✅ Be **blocked** from booking a 15-min lesson same day after a 25-min booking, with the correct error copy.
- ✅ Bundle 2×15 in a single booking flow.
- ✅ Cancel one of a 2×15 bundle without affecting the other.
- ✅ Reschedule a 15-min lesson to another 15-min slot but not to a 25-min slot.

A 라이트 user can:
- ✅ See "tickets remaining: 7.5" after spending one 15-min lesson from an 8-ticket plan.
- ✅ Book up to 16 lessons in a month if all are 15-min.
- ✅ Mix 15-min and 25-min lessons freely (no daily-budget rule for 라이트).
- ✅ Be blocked from booking a 25-min lesson with only 0.5 tickets remaining, but allowed to book a 15-min.

An admin can:
- ✅ Create a new 15-min course in `grape`.
- ✅ Have the new course immediately appear in the lesson tab for all 무제한 + 라이트 users on next refresh.
- ✅ Toggle a tutor's `WILLING_TO_TEACH_15MIN` flag and see the tutor's slots show up for 15-min booking immediately.
- ✅ Inspect a 2×15 bundle in `podo_class.php` as a grouped pair under one user-day row.

System invariants:
- ✅ Tutor payroll for any week = sum over lessons of `(per-25-min-rate × lessonTime/25)` to within ≤ 1% rounding error.
- ✅ No 무제한 user has > 30 min booked on any single user-local day.
- ✅ No 라이트 user has spent more `TICKET_COST` than they purchased (within a billing cycle).

---

## Open Questions / Decisions Needed Before Build

These need product/business answers before engineering can finalize:

1. **Tutor compensation model: Option A (flat new tier) or Option B (proration)?** §11.1. Recommend B; needs sign-off.
2. **Does the 15-min beginner content already exist, or is it on the content team's roadmap?** Without content, the feature ships empty.
3. **Are we OK keeping `25분` in onboarding/payment copy as-is, given the trial and primary product remain 25-min?** §16.1. Recommend yes — additive change, existing promise is preserved.
4. **Daily-budget violation handling in admin overrides:** soft warning only, or hard block with override-reason field? §17.2.
5. **Auto-kick grace policy for 15-min:** absolute (10-min warning, 3-min kick) or proportional (`lessonTime × 0.4`)? §16.2.
6. **Tutor opt-in default:** opt-in or opt-out? §11.3 has it as opt-in. Opt-out would maximize 15-min slot supply but risks tutor backlash; opt-in is safer but slows launch.
7. **Should the lesson tab show 15-min courses to users on plans not in Phase 1 (e.g. business, 12회 routine), with a "upgrade to access" CTA?** Could be a marketing growth lever; recommend "no" for v1 to keep the additive-only promise clean.

---

## Appendix A: File-Reference Index

| Concern | File(s) |
|---|---|
| Lesson registration invariant (`% 25 == 0` rejection) | `podo-backend/.../lecture/dto/request/LectureRegistRequestDto.java:64-67` |
| Daily-budget check insertion point | `podo-backend/.../podo/schedule/usecase/PodoScheduleServiceImplV2.java:~1119` |
| Lesson tab listing logic | `podo-backend/.../lecture/service/query/LectureQueryServiceImpl.java:1808-1910` |
| 15-min slot-start rule (canonical) | `grape/admin/matching/podo_mock_matching_tutors.php:375` |
| Tutor payroll `÷25` / `×25` math | `grape/app/android/process/payment_complete_vbank.php:154,263-265`, `class_ps.php:57`, `t_class_v5_ps.php:3106` |
| Class-end interval | `grape/admin/process/podo_class_ps.php:317,779`, `first_study_ps.php:96` |
| Admin class detail (already 15-min-aware) | `grape/admin/podo_class_detail.php:34,53,196,841,845` |
| Frontend lesson-time type | `podo-app/apps/web/src/shared/types/subscription.ts:16,27` |
| Frontend default | `podo-app/apps/web/src/server/infrastructure/database/schema/lectureTicket.ts:33` |
| Auto-kick timer | `podo-app/apps/web/src/views/class-room/config/auto-kick.ts:7,10` + `hooks/use-auto-kick-timer.ts:15,74` |
| Booking screen (slot picker) | `podo-app/apps/web/src/views/post-purchase-booking/select-view.tsx` |
| Feature-flag plumbing | `podo-app/apps/web/src/entities/feature-flag/api/feature-flag.api.ts`, `shared/constants/feature-flags.ts` |
| Coupon condition (already supports `[15,25,55]`) | `podo-backend/.../coupon/dto/response/ApplyConditionGetForSubDto.java` |
| ClassTimePerOneTicket constant (legacy, do not delete) | `podo-backend/.../ticket/domain/Ticket.java:24`, `Card.java`, `Board.java`, `subscribe/domain/SubscribeMapp.java` |
| Default lesson time (post-purchase auto-book) | `podo-backend/.../purchaseBonus/service/StartingLessonResolverService.java:49` |
