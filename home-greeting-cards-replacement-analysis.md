# Home Greeting Cards — Replacement Analysis

> Analysis of whether the two post-purchase-booking cards (`HomeBonusWithBookingCard` / `HomeBonusNoBookingCard`) can be used as drop-in replacements for the default home greeting cards.

## Short answer: not cleanly. ~60% coverage, with real gaps.

The two cards handle the "has booking" and "no booking" split fine, but the default greeting system is richer than that — it's a 4-state machine, and two of those states plus a bunch of per-class features aren't represented anywhere in the bonus cards. Here's what breaks down.

## The four current states (in `@features/home-greeting/ui/states/`)

| Default state                     | Triggered when                             | Bonus-card equivalent?                                                                                                                                                                                      |
| --------------------------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`NoTicketState`**               | User has no active subscription at all     | ❌ **None** — bonus flow assumes subscription exists                                                                                                                                                        |
| **`RecommendTrialLessonState`**   | Has only a trial ticket, no booking        | ⚠️ **Partial** — would get the `NoBookingCard`, but the trial UX is simpler (no course preview, just a single "예약하기") — using the bonus card here would add a course-preview box that isn't appropriate |
| **`RecommendRegularLessonState`** | Has a regular ticket, no booking           | ✅ Yes — `HomeBonusNoBookingCard` is almost identical in shape                                                                                                                                              |
| **`ScheduledClassState`**         | Has a regular ticket + has a booked lesson | ⚠️ **Partial** — see features lost below                                                                                                                                                                    |

## What `ScheduledClassState` has that `HomeBonusWithBookingCard` doesn't

This is the big one — the booked-lesson state today does a lot more than just show date/time/tutor:

- **Pre-study progress bar** — "예습 3/5 완료" style indicator
- **"수업 입장하기" (Join class)** — appears when the lesson is within the join window, replacing "예습하기"
- **"튜터 프로필 보기"** — modal with tutor details / history
- **"예약변경" / "예약취소"** — cancel flow, not just change
- **Class notice dialog** — the "세 가지만 기억해주세요" etiquette tips that fire on certain conditions
- **Trial-expiry banner** — warning for trial tickets near expiry

`HomeBonusWithBookingCard` currently collapses all of this to "일정 변경" + "예습하기" and date/time/tutor rows. Using it as the default would be a regression for anyone with a booked lesson.

## What's already lined up

Data shape is **highly compatible** — `userName`, `booking.{bookName, langTypeName, lessonDateTime, lessonEndTime, tutorName, minutesUntilLesson}`, and `coursePreview.{levelThumbnail, levelName, weekName, levelDesc}` all map 1:1 to fields the existing home-greeting queries (`getNextLessonsInfo`, `getLectureCourseList`, `getStartingLesson`, `getCurrentUser`) already return. So the data plumbing is a non-issue.

The `bonus: ActivePurchaseBonus` prop on the no-booking card is genuinely unused (marked `_bonus`), so dropping it for non-bonus contexts is safe.

## Visual identity question

Worth verifying with design: the two new cards use a **light theme** (white card, light illustration band, blue accent info-box), whereas the current default greeting leans darker (`gray-900` panel in `ScheduledClassState`). If designer's goal is "make these the new defaults," they're also implicitly proposing a theme shift. Make sure they've signed off on that, not just the per-card look.

## Three paths forward

### Path A — ship partial, incrementally (recommended)

- **Replace `RecommendRegularLessonState`** with `HomeBonusNoBookingCard` as the non-bonus default. This is the 1:1 substitution that already works.
- **Keep `ScheduledClassState` for now** and plan to port its missing features (pre-study progress, tutor modal, join-class phase, notice dialog, cancel flow) into `HomeBonusWithBookingCard` in a follow-up PR.
- **Keep `NoTicketState` as-is** and **keep `RecommendTrialLessonState` as-is** until design explicitly calls out what the trial/no-ticket versions of the new design look like.

That's a small, safe PR that gets ~one of the two replacements landed immediately.

### Path B — full port, bigger PR

Extend both new cards to handle all four states. Effort probably multiplied 3-5× since:

- With-booking card needs all the pre-class features ported in (non-trivial, involves hooks from `useScheduledClassHandlers`, pre-study query, tutor profile state)
- No-booking card needs a trial-only variant without the course preview
- You'd need a new no-ticket variant of the card (or keep `NoTicketState` as a sibling)

### Path C — confirm intent first

Loop back to the designer with a summary of the 4 states and ask what they intend each to look like in the new design. Possible the design mockups they shared were only for 2 of the 4 states, and they haven't thought about `NoTicket` / trial-only yet.

## Recommended sequencing

1. **Path C first** (15-minute conversation with designer) to confirm design intent on the two states the mockups don't cover.
2. **Path A** (one small PR doing the `RecommendRegularLessonState` → `HomeBonusNoBookingCard` replacement) to land the safe half.
3. Follow-up sprint for the with-booking port — this is where the real work lives (pre-study progress, join-class, tutor modal, cancel flow).

## File references

- **Defaults**: `apps/web/src/widgets/greeting/ui/greeting-content.tsx`, `apps/web/src/widgets/greeting/hooks/use-greeting-status.ts`, `apps/web/src/widgets/greeting/model/status.ts`
- **States**: `apps/web/src/features/home-greeting/ui/states/` (4 files: `scheduled-class-state.tsx`, `no-ticket-state.tsx`, `recommend-regular-lesson.tsx`, `recommend-trial-lesson.tsx`)
- **Bonus cards**: `apps/web/src/widgets/post-purchase-booking/ui/home-bonus-with-booking-card.tsx`, `apps/web/src/widgets/post-purchase-booking/ui/home-bonus-no-booking-card.tsx`, `apps/web/src/widgets/post-purchase-booking/ui/home-bonus-greeting.tsx`
- **Router**: `apps/web/src/views/home/view.tsx` — the `variantA ? <HomeBonusGreeting /> : <GreetingContent />` switch
