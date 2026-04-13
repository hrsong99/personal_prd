# Tutor Incentive Event — Research Summary & Feature Proposal

## Part 1: Current State of the Codebase

### A. Existing Event/Incentive Page (tutor-web, podo-app)

There is already an incentive page in the tutor-web app, but it's called **"이벤트" (Event)** in the codebase.

**Route:** `/event`
**Location:** `apps/tutor-web/src/app/[locale]/(after-login)/(with-layout)/event/`

**How it works today:**
- The page shows a progress bar with 4 mission tiers (50/150/300/500 completed lessons → cumulative yen bonuses up to 5,000¥)
- It fetches a single count of completed lessons from the `GT_CLASS` table for January 2026
- **All reward calculation is done in the browser** — hardcoded constants in `event-view.tsx`, calculated via `useMemo`
- The "Exchange" button just opens an external site (giftto.jp) in a new tab
- **There are zero writes to the database.** No record of event participation, no mission-completion tracking, no reward payout record. It's purely a read-only display.

**How tutors access it:**
- There is **no sidebar or bottom navigation link** — there never was one (confirmed via full git history)
- The only entry point is a **popup modal** (`EventMissionPopup`) that appears on the Home and Lessons pages
- The popup only shows for Japanese tutors (`tutorType === '일본어'`) during January 2026
- The popup has a "don't show for 1 week" option stored in `localStorage`
- The popup has a CTA button that navigates to `/event`

**What counts as a completed lesson:**
- Statuses: `COMPLETED`, `NOSHOW_S` (student no-show), `CANCEL_PAID` (cancelled within 1 hour of class start)
- Excluded: `COMPLETED` where `paymentDiv = 'NP'` (no-pay completions)

**Key files:**

| File | Purpose |
|---|---|
| `event/_components/event-view.tsx` | Main component — all UI + hardcoded mission logic |
| `event/event.css.ts` | Vanilla Extract styles (progress bar, milestones, speech bubble) |
| `event/page.tsx` | Server component wrapper |
| `widgets/event-mission-popup/event-mission-popup.tsx` | Popup modal with CTA |
| `entities/lectures/api/lecture.query.ts` | TanStack Query — `eventCompletedLessonCount` |
| `server/modules/lectures/service.ts` | Server-side lesson counting with filtering |

### B. The 1-Hour Booking Setting (critical for the new feature)

The tutor setting `ALLOW_LESSON_ONE_HOUR_BEFORE` already exists and is well-instrumented:

**Database:**
- Column: `GT_TUTOR.ALLOW_LESSON_ONE_HOUR_BEFORE` (`CHAR(1)`, `'Y'`/`'N'`, default `'N'`)

**Toggle UI:**
- Located in the tutor Settings page (`/settings`)
- Uses a `<Switch>` component with a confirmation dialog before any change
- File: `shared/ui/setting-form-field/setting-form-field.tsx`

**API:**
- `PATCH /api/v1/tutors/settings/allow-lesson-one-hour-before` (tutor-web BFF → direct DB write)
- Also: `PATCH /api/v1/tutor/settings/allow-lesson-one-hour-before` (podo-backend Java, but without audit logging)

**Audit log (this is the key piece):**
- Every toggle is recorded in `GT_BIZ_LOG` with:
  - `BIZ_TYPE = 'ALLOW_LESSON_ONE_HOUR_BEFORE'`
  - `BIZ_VALUE = 'Y'` or `'N'`
  - `USER_ID = <tutor's GT_TUTOR.ID>`
  - `CRE_DATETIME = timestamp of the change`
- **Only written by the tutor-web BFF path** (not by the Java backend — that has a TODO comment for logging)

---

## Part 2: Proposed New Feature

### Core Concept

A new incentive event page for **Japanese tutors only**, tied directly to the **1-hour booking setting**. Instead of a one-time fixed campaign, this is an ongoing incentive that rewards tutors for completing classes while the 1-hour booking setting is active.

### How It Should Work

**Participation:**
- If a tutor already has the 1-hour booking setting turned ON → they are **automatically part of the event**
- If the setting is OFF → they must toggle it ON to join, and class counting starts from that moment

**Milestone System:**
- Starting from **30 completed classes**, the tutor earns an extra **+1% of base salary** as a bonus, with additional +1% at each subsequent milestone (up to 20% at 500 classes)
- Milestone gaps increase as the tutor progresses: every 10 classes at first, then every 20, 25, and 50 at higher tiers
- Instead of a traditional absolute progress bar, the UI should use a **scrolling/rolling milestone bar** that feels like continuous progress
30	1.0%
40	2.0%
50	3.0%
60	4.0%
70	5.0%
80	6.0%
90	7.0%
100	8.0%
120	9.0%
140	10.0%
160	11.0%
180	12.0%
200	13.0%
225	14.0%
250	15.0%
275	16.0%
300	17.0%
350	18.0%
400	19.0%
500	20.0%

**The Toggle-Off Problem (key UX challenge):**
- When a tutor tries to turn OFF the 1-hour booking setting, show a **confirmation popup** that says:
  - Their current incentive progress (e.g., "You've completed X classes and earned Y% bonus so far")
  - A warning that **classes taught with this off will not count towards the mission**
  - When they turn it back on later, counting continues
- If confirmed → setting turns off, progress pauses
- If cancelled → setting stays on, progress preserved

### Technical Feasibility — No New DB Writes Needed

The existing infrastructure can support this without creating new tables:

| Need | Existing Solution |
|---|---|
| Know if setting is ON | `GT_TUTOR.ALLOW_LESSON_ONE_HOUR_BEFORE` |
| Know when setting was last turned ON | `GT_BIZ_LOG` — most recent row with `BIZ_TYPE = 'ALLOW_LESSON_ONE_HOUR_BEFORE'` and `BIZ_VALUE = 'Y'` |
| Count classes since that date | `GT_CLASS` query with `startedAt >= lastToggleOnDate` |
| Count classes during ON periods only | Query all ON/OFF toggle pairs from `GT_BIZ_LOG`, sum classes in each ON window |

**The counting logic (pause-based, not reset):**
1. Query `GT_BIZ_LOG` for all toggle entries for this tutor, ordered by `CRE_DATETIME`
2. Build a list of ON windows: each `'Y'` entry starts a window, each `'N'` entry closes it (current window stays open if setting is currently ON)
3. Count completed lessons from `GT_CLASS` where `startedAt` falls within any ON window
4. Look up the lesson count in the milestone table to determine the current bonus %

**Edge cases to handle:**
- Tutor had setting ON before the event feature launches → no `'Y'` log entry exists or it's very old → treat the **event launch date** as the start of their first ON window
- Tutor has never toggled the setting (no `GT_BIZ_LOG` entries at all) → if currently ON, use event launch date as window start; if currently OFF, no windows exist yet
- Tutor toggles OFF then ON again → progress is **preserved** (classes from all previous ON windows still count), new ON window begins accumulating on top
- Changes made via Java backend don't write to `GT_BIZ_LOG` (TODO in code) → if any admin tool uses that path, those toggles would be invisible to this feature

### What Needs to Be Built

| Component | Type | Details |
|---|---|---|
| Updated event page | Modify existing | New milestone logic, scrolling bar UI, base salary % display |
| Scrolling milestone bar | New UI component | Variable-gap milestones (10→20→25→50 class increments), scrollable/rolling visual |
| ON-window counting query | New query | Build ON/OFF windows from `GT_BIZ_LOG`, count classes across all ON periods |
| Enhanced toggle-off confirmation | Modify existing | Show current incentive progress + pause warning in the confirmation dialog |
| Navigation link | New | Add event/incentive link to sidebar and/or bottom nav (currently missing) |
| New DB tables | **None** | Everything uses existing `GT_BIZ_LOG` + `GT_CLASS` + `GT_TUTOR` |

---

## Part 3: Open Questions for PRD

1. **Event duration** — Is this an ongoing permanent incentive, or does it have a start/end date like the current January 2026 campaign?
2. **Reward cap** — Is there a maximum bonus percentage, or does it grow indefinitely (e.g., 100 classes = +20%)?
3. **Reward payout** — How is the bonus actually paid? Added to the invoice automatically (via the grape admin system)? Or still manual?
4. **Monthly reset** — Does progress reset each month, or is it cumulative across months?
5. **Which classes count** — Same rules as the current event (COMPLETED + NOSHOW_S + CANCEL_PAID within 1 hour, excluding NP)?
6. **Navigation** — Should there be a permanent sidebar link, or still popup-only access?
7. **Korean tutors** — Japanese only for now, or planned expansion?
8. **Base salary display** — Show exact yen amounts, or just the percentage + a note about base salary?
