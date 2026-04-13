# Post-Purchase First Lesson Booking Flow

*Created At: 2026-04-13T06:12:43.846443+00:00*

## Goal

Guide new purchasers through a streamlined first lesson booking immediately after purchase, driving early activation (first lesson completed within the bonus window) to demonstrate product value and reduce post-purchase drop-off.

## User Stories

1. **As a** New lesson package purchaser, **I want to** Be guided directly into a simplified booking flow immediately after purchase, **so that** I don't have to discover the booking tab on my own and can schedule my first lesson with minimal friction.
2. **As a** New lesson package purchaser, **I want to** See a pre-filled recommended level based on my prior data (trial recommendation → onboarding inference → Start 1 fallback), **so that** I don't face decision paralysis choosing from a list of unfamiliar levels.
3. **As a** New lesson package purchaser, **I want to** Override the pre-filled level via a bottom sheet, **so that** I retain control if the system recommendation doesn't match my preference.
4. **As a** New lesson package purchaser, **I want to** See 6 recommended time slots upfront with a 'see other times' option opening a calendar capped at 3 days, **so that** I can quickly pick a time without scrolling through a full calendar, and every visible slot qualifies for the bonus.
5. **As a** New lesson package purchaser, **I want to** See a persistent global toast above the GNB across all tabs showing the bonus deadline and reward, **so that** I'm continuously reminded of the time-sensitive incentive regardless of where I navigate in the app.
6. **As a** New lesson package purchaser, **I want to** Tap the toast body to navigate to the booking tab with my default level pre-selected, **so that** I can easily resume booking from any screen without hunting for the right tab.
7. **As a** New lesson package purchaser, **I want to** See a personalized Home card with my recommended level and quick booking/browsing buttons, **so that** I have a persistent re-entry point on Home even after leaving the post-purchase flow.
8. **As a** New lesson package purchaser (post-bonus-expiry), **I want to** Still see the Home booking card (without bonus copy) after the bonus window expires, **so that** I'm still nudged to book my first lesson even if I missed the bonus deadline.
9. **As a** New lesson package purchaser, **I want to** Receive push and alimtalk notifications reminding me of the bonus deadline and confirming bookings/awards, **so that** I'm reminded even outside the app and receive confirmation when actions are taken.

## Constraints

- Calendar bottom sheet must cap available dates at purchase_day + 0, +1, +2 (3 days max) so every selectable slot falls within the bonus window
- Bonus deadline uses calendar-day model: end of day (23:59:59 user local timezone) on purchase_day + 2, NOT a rolling 48-hour clock
- Bonus award is idempotent — fires exactly once per purchase
- Toast X-dismissal state must be stored server-side per-purchase (survives app reinstall, logout/login, multi-device)
- Post-purchase single-screen flow is one-shot only — toast tap navigates to the standard booking tab, not back to the post-purchase flow
- Tutor is auto-assigned by the system — users do not pick tutors
- Both push and alimtalk fire for every notification (intentional redundancy, no retry logic within this flow)
- All deadline-related copy must use the absolute date format (e.g., '4월 17일까지'), never a rolling countdown
- No empty state design needed for 'no available slots' — healthy slot supply is assumed; if it occurs, it's a P0 supply incident
- Brownfield: must integrate into existing podo-app (TypeScript monorepo with native app, tutor-web) and podo-backend (Kotlin)

## Success Criteria

1. Primary metric: % of new purchasers who COMPLETE (not just book) their first lesson within the bonus window (end of purchase_day + 2)
2. Measure baseline starting at launch, then set an explicit numeric target after the first 2 weeks of post-launch data
3. Bonus awards are correctly scaled by plan type and package duration (회차권: +2/+4/+8 classes for 3/6/12mo; 무제한: +21/+30/+60 day extension for 3/6/12mo)
4. Toast persists across all tabs and app sessions until dismissed (X), deadline passes, or bonus is awarded
5. Level pre-fill 3-tier fallback chain resolves correctly: trial tutor recommendation → onboarding inferred level → Start 1
6. Notification suppression works correctly: no bonus-related notifications after N4 (bonus awarded) fires

## Assumptions

- Slot supply is healthy enough that the 3-day calendar window will always have available time slots
- The race condition window between purchase confirmation and post-purchase flow display is effectively zero
- Simultaneous bonus-eligible purchases by the same user are very unlikely but possible — show toast with earliest deadline
- Users who dismiss the toast and ignore notifications are acceptable loss — notifications are the safety net, not a guarantee
- The existing booking flow (level → time slot → confirm with auto-assigned tutor) is stable and does not change
- The 3-tier level fallback data (trial recommendation, onboarding inference) is available via existing backend APIs

## Decide Later

The following items were deferred or identified as premature at this stage. They should be revisited when more context is available:

- Do you know the current baseline for first-lesson-completion-within-48h metric, and do you have a target in mind — e.g., move it from ~X% to Y%? (Answer: measure baseline post-launch, set target after 2 weeks of data)
- Fixed local time for N3 morning-of-deadline notification (e.g., 9am mentioned as example but not confirmed as final)
- Empty state design for no available time slots within the 3-day window (treated as P0 supply incident, not UX problem)
- Pre-existing booking race condition detection (always show the post-purchase flow regardless)
- Deadline-warning banner on Level+Time screen (largely unnecessary due to calendar cap, kept only as safety net for edge cases)

## Existing Codebase Context

- **grape** (`/Users/johnsong/grape`)
- **podo-app** (`/Users/johnsong/podo-app`)
- **podo-backend** (`/Users/johnsong/podo-backend`)

---
*PM ID: pm_seed_interview_20260413_052848*
*Interview ID: interview_20260413_052848*
