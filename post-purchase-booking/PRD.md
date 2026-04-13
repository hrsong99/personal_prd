# PRD: Post-Purchase First Lesson Booking Flow

## Overview

After a user completes a lesson plan purchase, they enter a guided flow designed to convert them into an active learner by booking their first lesson. The user receives a bonus incentive if they complete their first lesson by the end of the bonus deadline. The flow strongly encourages booking immediately but does not punish the user for leaving — the incentive remains available throughout the bonus window, and the deadline is automatically extended once if the user misses the initial window.

This PRD covers the immediate post-purchase booking flow: a brief celebration screen → Booking Encouragement screen → Level + Time Selection → Booking Confirmed, plus the two Home screen states that reflect booking status, and the bonus deadline extension behavior.

---

## User Segments

### Language pack x Trial class matrix

|  | Single-language | Double-pack (EN + JP) |
|---|---|---|
| **With trial class** | Level pre-set by tutor recommendation. Banner: "체험 레슨 튜터가 {level}을 추천했어요!" | Language toggle shown. Default language = the language of their most recent trial class. Level for that language pre-set by tutor. The other language falls through the level-default chain (see "Level Defaults" below). Banner only appears for the trial-recommended language. |
| **No trial class** | Level defaulted via the level-default chain (onboarding data → lowest level). No banner. | Language toggle shown. Default language = English. Both languages use the level-default chain. No banner. |

### Plan type (orthogonal to above)

| Plan | Description | First-lesson incentive |
|---|---|---|
| **Count plan (회차권)** | Fixed number of lessons (e.g. 48 classes / 6 months) | +N bonus classes on first lesson completion within the bonus window (varies by package duration) |
| **Unlimited plan (무제한)** | Unlimited lessons for a fixed period (e.g. 3 months) | +N day extension on first lesson completion within the bonus window (varies by package duration) |

### Package duration variants

Both plan types scale their bonus by purchased duration:

| Plan Duration | Count Plan Bonus | Unlimited Plan Bonus |
|---|---|---|
| 3 months | +2 bonus classes | +21 day extension |
| 6 months | +4 bonus classes | +30 day extension |
| 12 months | +8 bonus classes | +60 day extension |

> Count-plan bonus values are placeholder defaults — to be revisited by product before launch.

Every combination of language pack, trial state, and plan type flows through the same screens — only the defaults, banners, and incentive copy differ.

---

## Bonus Window Definition

The bonus window has two phases. The user only ever has one active deadline at a time.

| Phase | Deadline | How it starts |
|---|---|---|
| **Initial window** | End of day (23:59:59 user local time) on **purchase_day + 2** | Begins at the moment of purchase |
| **Extended window** | End of day (23:59:59 user local time) on **purchase_day + 7** | Automatically begins the moment the initial window expires without a completed first lesson |

Both phases use the **same bonus reward** — the only difference is the deadline date. The user gets one chance to earn the bonus across the combined window. Once the extended window expires without a completed lesson, the bonus is forfeited permanently.

All user-facing copy uses the **absolute date** of the currently active deadline (e.g. "4월 17일까지", "4월 22일까지").

---

## Screen-by-Screen Specification

### Screen 1: Purchase Celebration (auto-advance)

A brief, full-screen celebration that acknowledges the purchase. **It has no CTAs** — it auto-advances to the Booking Encouragement screen after **2–3 seconds**. The user cannot interact with this screen, dismiss it, or back out of it.

**What the user sees:**

- White background
- Vertically centered content stack:
  - Bright green checkmark icon inside a bright green circle
  - Title: **"구매가 완료되었어요!"** (bold, centered)
  - Subtitle: **plan name** in muted gray, dynamically populated from the user's purchase. Examples:
    - "영어 무제한 레슨권 12개월"
    - "영어 회차권 6개월"
    - "일본어 무제한 레슨권 3개월"
- No buttons, no incentive card, no other elements

**Auto-advance behavior:**

| Event | Destination |
|---|---|
| 2–3 seconds elapsed (no user action required) | → Screen 2: Booking Encouragement |

The 2–3 second window is intentional: long enough for the user to register the success state, short enough to feel snappy and not block them from booking.

---

### Screen 2: Booking Encouragement (the "main screen")

The main screen of the post-purchase flow. The user lands here automatically after the celebration screen auto-advances. This is a single-action funnel screen with high emotional energy designed to push the user toward booking. **It does NOT show levels or time slots** — those live on the next screen. This screen exists purely to (a) celebrate, (b) surface the bonus, and (c) get the user to tap the booking CTA.

**What the user sees:**

- Continuous **confetti animation** falling across the background (animated GIF / Lottie loop)
- Centered **cheerful Podo mascot** holding a wrapped gift box (signaling reward)
- Bold title: **"첫 레슨 예약해봐요!"**
- Pinned at the bottom (above the CTA), incentive info card with a downward speech-bubble tail pointing at the CTA button:
  - Light blue background (#F2F5FF) with rounded corners
  - Gift icon on the left
  - Bold blue headline (default unlimited example): e.g. "21일 연장 혜택"
  - Description (default unlimited example): "지금 바로 첫 레슨하면 이용 기간을 연장해 드려요"
  - Standard package wording note: the headline uses class-count language (e.g. "4회 추가 지급 혜택"), and the description becomes "지금 바로 첫 레슨하면 추가 레슨권 드려요"
- **Primary CTA: "첫 수업 예약하기"** — full-width primary button (blue/violet treatment), always enabled
- **Weak exit text link: "혜택 포기하고 나가기"** — small gray text link directly below the CTA, intentionally de-emphasized typography

The entire bottom-of-screen stack (incentive card → primary CTA → weak exit link) is the single funnel point. There is no other navigation, no back arrow, no header.

**Bottom CTAs:**

| Action | Destination |
|---|---|
| "첫 수업 예약하기" (primary) | → Screen 3: Level + Time Selection |
| "혜택 포기하고 나가기" (weak gray text link) | → Exit Reminder Bottom Sheet |

The "혜택 포기하고 나가기" copy is **intentionally scary** ("forfeit benefit and exit") even though tapping it does NOT actually forfeit the bonus — see the Exit Reminder Bottom Sheet section for the full explanation. This is a deliberate retention pattern.

---

### Screen 3: Level + Time Selection

The booking interaction screen. Reached by tapping **"첫 수업 예약하기"** on the Booking Encouragement screen, OR by tapping **"지금 예약하기"** in the Exit Reminder Bottom Sheet. Combines level confirmation and time selection into a single scrollable page.

#### Double-pack language selector (conditional)

If the user has a double-pack (both EN and JP), a language toggle ("영어" / "일본어") appears at the top of the screen as two equal-width buttons.

- **Default language (with trial):** The language of the user's most recent trial class is pre-selected. That language uses the tutor-recommended level; the other language falls through the level-default chain (see "Level Defaults").
- **Default language (no trial):** English is pre-selected. Both languages use the level-default chain.
- **Switching language** re-runs the level-default chain for the newly selected language and clears any selected lesson date/time.
- Language selections are **not remembered per language** inside this screen. If the user switches from EN → JP → EN, the EN side re-runs its defaulting logic and returns to its default state rather than restoring the user's previous EN selection.
- **Active state:** Light green background (#F2FCEC) with green outline (#6ABE36)
- **Inactive state:** White background with gray outline (#E8E8E8)

#### Section: 레슨 선택

- Displays the currently selected level as a tappable card:
  - Book cover placeholder (green rectangle)
  - Level name (e.g. "Start 1") + description text
  - Chevron right icon indicating it opens the Level Change Bottom Sheet
- Below the card, a recommendation banner (blue background #F2F5FF) — **only shown when the default level came from a trial class recommendation**:
  - **Trial user:** "체험 레슨 튜터가 **{level}**을 추천했어요!"
  - Second line: "다른 레벨도 선택할 수 있어요."
- If the default level came from onboarding data or the lowest-level fallback, **no banner is rendered** — only the level card is shown.

**Tapping the level card** → opens the Level Change Bottom Sheet.

**Changing level behavior:**

- Selecting a different level clears any selected lesson date/time.
- If the user had picked a custom time via the Calendar Bottom Sheet, the screen returns to the default **"추천 시간"** state after the level change instead of preserving the old custom selection.
- Rationale: tutor matchability can differ by level, so time availability must be recalculated from a clean state whenever the level changes.

#### Section: 추천 시간 (default state)

- Header: "추천 시간"
- Subtitle: "레슨 일정을 선택해 주세요."
- 6 recommended time slots displayed in a 2-column grid (3 rows)
- The grid shows the **next 6 closest available times** for the currently selected language + level, ordered chronologically across the 3-day bonus-window range
- Each slot shows date + time (e.g. "오늘 10:00", "내일 21:30")
- **Selected state:** Light green background (#F2FCEC) with green outline (#6ABE36)
- **Unselected state:** White background with gray outline (#E8E8E8)
- Below the grid: "다른 시간 보기" button (ghost style) → opens the Calendar Bottom Sheet

#### Section: 선택된 레슨 일정 (after custom time selection)

If the user picks a time via the Calendar Bottom Sheet instead of the recommended slots, the entire "추천 시간" section (header, subtitle, 6-slot grid, and "다른 시간 보기" button) is replaced by a compact "선택된 레슨 일정" section:

- Section header: **"선택된 레슨 일정"** (small label, top-left)
- Selected time displayed as a single full-width pill:
  - Light green background (#F2FCEC) with green outline (#6ABE36)
  - Centered text: e.g. **"4월 21일 06:30"**
- Full-width ghost button below the pill: **"날짜 변경"** → reopens the Calendar Bottom Sheet
  - White background, gray border, dark gray text
- This compact layout replaces the recommended-slots grid entirely — there is no way to revert to the recommended-slots grid without going through the calendar again

#### Bottom CTA: "예약 확정"

- Primary green button, full-width
- **Disabled** (gray) until a time slot is selected
- Tapping it (with a time selected) finalizes the booking
- No incentive card and no exit link on this screen — the bonus surfacing and the exit path both live on the Booking Encouragement screen (Screen 2)

| Action | Destination |
|---|---|
| Select time + tap "예약 확정" | → Screen 4: Booking Confirmed |
| Tap back arrow (top-left) | → Screen 2: Booking Encouragement |

---

### Exit Reminder Bottom Sheet

Triggered when the user taps **"혜택 포기하고 나가기"** on the **Booking Encouragement screen (Screen 2)**. This is a confirmation dialog asking the user to reconsider before leaving the post-purchase flow.

**Critical note on copy:** The bottom sheet's language strongly implies the user may lose the benefit if they leave ("혜택을 놓칠 수 있어요") — but **this is a retention nudge, not the actual rule**. In reality, the bonus remains fully active after the user exits: the deadline still runs, the Home toast still appears, the automatic deadline extension still fires if needed, and the user can still earn the bonus by booking and completing within the active window via the standard booking path. The copy is intentionally manipulative-feeling to discourage drop-off, but the underlying entitlement is unchanged.

**What the user sees:**
- Dark backdrop overlay covering the Booking Encouragement screen behind it (the cheerful mascot and confetti are still visible, dimmed)
- Bottom sheet with drag handle at top
- Centered **sad Podo mascot** illustration (Podo character holding a handkerchief with teary infinity-symbol eyes, fallen gift box at its feet) — visual contrast to the cheerful mascot underneath, makes leaving feel like a loss
- Title: **"정말 나가시겠어요?"** (bold, centered)
- Subtitle uses **plan-specific** copy:
  - **Count plan:** "지금 나가면 추가 레슨권 혜택을 놓칠 수 있어요."
  - **Unlimited plan:** "지금 나가면 이용 기간 연장 혜택을 놓칠 수 있어요."
- Primary **green** button: **"지금 예약하기"** (full-width, emphasized — note: green here, not the blue/violet of the encouragement screen CTA, to feel like a fresh affirmative action)
- Smaller gray text link below: **"혜택 포기하고 나가기"** (intentionally weaker than the primary button)

**User actions:**

| Action | Result |
|---|---|
| "지금 예약하기" (primary green button) | Closes the bottom sheet AND navigates **forward** to Screen 3: Level + Time Selection |
| "혜택 포기하고 나가기" (text link) | Closes the bottom sheet AND exits the post-purchase flow → Home screen. The bonus remains active — the user has NOT actually forfeited anything |
| Tap outside / drag down | Closes the sheet without navigating — user returns to the Booking Encouragement screen |

---

### Level Change Bottom Sheet

Slides up from the bottom with a dark overlay.

**What the user sees:**
- Drag handle
- "레벨 변경" header
- List of level cards (varies by language):
  - **English:** Start 1, Level 2, Level 3, Level 4
  - **Japanese:** Start 1, Level 2, Level 3, Level 4
- Each card shows: book cover placeholder (gold/tan rectangle) + level name (bold) + description
- Currently selected level has a green checkmark icon

**User actions:**

| Action | Result |
|---|---|
| Tap a level | Selects it, closes sheet, updates level on main screen |
| Tap outside / drag down | Closes sheet without changes |

---

### Calendar Bottom Sheet

Slides up from the bottom. Used when the user wants a time beyond the 6 recommended slots.

**What the user sees:**
- Drag handle
- "레슨 일정을 선택해주세요." title
- 3-day horizontal date selector (purchase_day + 0, +1, +2 — i.e. today, tomorrow, day-after-tomorrow). The calendar is intentionally capped at +2 days so every selectable slot falls inside the initial bonus window.
  - Each day shows: day label ("오늘", "내일", or weekday) + date number
  - Selected day: green background (#F2FCEC) with green outline (#6ABE36)
- "예약 가능 시간" header with "예약 마감" legend (red dot for unavailable)
- Time slot grids separated by AM / PM:
  - 3 columns per row
  - **Available:** White background with gray border
  - **Unavailable (booked):** Gray background (#F5F5F5), disabled, strikethrough or grayed text
  - **Today:** Past times / near-term times inside the existing **2-hour booking cutoff** are hidden entirely
  - **Selected:** Green background (#F2FCEC) with green outline (#6ABE36)
- Bottom "확인" button (primary green, disabled until a time is selected)

**User actions:**

| Action | Result |
|---|---|
| Select a day | Switches to that day's time grid, clears time selection |
| Select a time slot | Highlights it |
| Tap "확인" | Closes sheet, shows selected time on main screen in "선택된 레슨 일정" section |
| Tap outside / drag down | Closes sheet without changes |

---

### Screen 4: Booking Confirmed

The final screen of the post-purchase flow, shown after the user taps "예약 확정" on the Level + Time Selection screen with a time selected.

**What the user sees:**

- Centered **Podo study mascot** illustration near the top of the screen — Podo character with infinity-symbol eyes holding a clipboard (signaling preparation / study mode). This is a different mascot pose from the cheerful gift-holding mascot on Screen 2.
- Bold title: **"레슨이 예약됐어요!"**
- Gray subtitle: **"교재로 미리 예습하면 편하게 대화할 수 있어요"**
- Booking detail card (light blue-lavender background, rounded corners), centered below the subtitle, containing two text rows:
  - **Top row:** date and time in coral/red accent color (e.g. **"2월 28일(수) 16:30"**) followed inline on the right by a small **D-day badge** in a blue rounded pill (e.g. **"D-2"**)
  - **Bottom row:** lesson identifier in dark gray (e.g. **"영어 Level 1"**, **"일본어 Start 1"**) — just the language + level, not the lesson topic title
  - Note: tutor name is intentionally not shown on this screen even though a tutor is auto-assigned in the background

**D-day badge rules** (same rules used in Home State B):

| Time until lesson | Badge |
|---|---|
| ≥ 24h | "D-2", "D-1", etc. |
| 1h–24h | "{N}시간 전" |
| < 1h | "{N}분 전" |

**Bottom CTAs (stacked vertically):**

- **Primary green button: "예습하기"** (full-width)
- **Weak gray text link below: "홈으로"** (small, centered, intentionally de-emphasized)

| Action | Destination |
|---|---|
| "예습하기" (primary green button) | → Pre-Study screen |
| "홈으로" (gray text link) | → Home screen |

The bottom CTA hierarchy intentionally pushes the user toward pre-study (the high-value next step) while still giving them a soft exit to Home. Pre-study is presented as the default action because users who pre-study before their first lesson have a meaningfully better lesson experience.

---

## Home Screen States

After the post-purchase flow, the Home screen reflects the user's booking status. These are the two possible states.

### State A: Not Booked

If the user left the post-purchase flow without booking, the Home screen shows a personalized card with the user's recommended level and a primary booking CTA.

**What the user sees (top to bottom):**

- **Hero illustration** at the top of the card — Podo mascot in an active/working pose (signaling momentum)
- **Personalized greeting:** "{userName}님, 안녕하세요!"
- **Subtitle:** "미루지 말아요! 지금 바로 레슨 예약하러 갈까요?"
- **Level preview card** (white background, light gray border) showing the user's resolved default level via the level-default chain:
  - Book cover thumbnail (e.g. red "DISCUSSION" cover for Start 1)
  - Level name in bold (e.g. "Start 1")
  - First lesson title (e.g. "2. 기초 영어의 첫걸음: 일상 표현부터 시작하기")
- **Two buttons in a row below the level card:**
  - **"다른 레슨보기"** (ghost button, left) → navigates to the global **Lesson tab** in the bottom GNB. This is a hand-off to the existing lesson browse experience, not a post-purchase-specific screen
  - **"예약하기"** (primary green button, right) → reuses the app's **existing Home booking entry flow**. In the current implementation this means the app resolves the user's next course / booking target through the standard Home flow, may route through the existing pre-study gate if needed, and then enters the standard booking experience. This does NOT re-enter the post-purchase Level + Time Selection screen. The active bonus window is honored by the backend regardless of which standard entry point creates the booking

**Persistent bonus toast (Home screen only):**

A static pill-shaped toast is pinned above the bottom GNB **only on the Home screen** — it does not follow the user into other tabs. The toast is **display-only and not clickable**; it has a single X button on the right edge for explicit dismissal.

- **Placement:** Just above the bottom GNB, Home screen only
- **Style:** Dark gray (#1C1C1C / near-black) pill with subtle drop shadow, white text, gift icon on the left, X button on the right
- **Copy (two lines):** Line 1: `"{deadline_date}까지 첫 레슨 완료하면"` (with the deadline date in coral/orange accent). Line 2: `"{bonus_reward}!"` (default unlimited example: "이용 기간 21일 연장해 드려요!")
  - Example (unlimited plan 3mo, extended window): "4월 22일까지 첫 레슨 완료하면 / 이용 기간 21일 연장해 드려요!"
  - Standard package wording note: "4월 17일까지 첫 레슨 완료하면 / 추가 레슨권 4회 드려요!"
  - `{deadline_date}` is the absolute calendar date of the **currently active** deadline (initial or extended), rendered in coral
  - `{bonus_reward}` is filled in from the user's plan type and package duration
- **Interaction:**
  - Body is **not tappable** — it is purely informational and does not navigate anywhere
  - Tapping the X button dismisses the toast for the current window only
- **Lifecycle:**
  - Appears immediately when the user first lands on Home after purchase
  - Persists across app sessions until any of: (a) user taps X, (b) the active bonus window expires, or (c) the user completes their first lesson and the bonus is awarded
  - **Re-appears on extension:** If the initial window expires without completion and the deadline is automatically extended, the toast **re-appears with the new deadline date even if the user previously dismissed it** via X. The dismissal state is per-window, not per-purchase.
  - The user can dismiss the extended-window toast independently. Once dismissed in the extended window, it does not come back again.
- **Dismissal persistence:** The X-dismissal state is stored server-side, scoped to `(purchase_id, window_phase)` so it survives app reinstall, logout/login, and multi-device usage. The two phases (initial, extended) have independent dismissal flags.
- **Multiple purchases edge case:** If the user has multiple unconsumed bonus-eligible purchases simultaneously, only one toast is shown at a time, prioritized by earliest active deadline.

### State B: Booked

If the user completed booking, the Home screen shows the upcoming lesson.

**What the user sees (top to bottom):**

- **Hero illustration** — light blue sky/mountain background with Podo mascot in a relaxed pose floating on a pink flamingo float, signaling that the booking is taken care of
- **Title:** **"예약된 레슨이 있어요!"** (bold)
- **Subtitle:** "교재로 미리 예습하면 편하게 대화할 수 있어요"
- **Booking details card** (light blue-lavender background, rounded corners) — three labeled rows with a left-side label column and right-side value column:
  - **일정** — `{lesson_date}({weekday}) {lesson_time}` in coral/red accent color, with the **D-day badge inline** to the right of the time (small blue rounded pill, e.g. "D-2"). Example: "2월 28일(수) 16:30 [D-2]"
  - **레슨** — full lesson topic title (e.g. "2. 기초 영어의 첫걸음: 일상 표현부터 시작하기")
  - **튜터** — auto-assigned tutor name (e.g. "Andrew")
- **Two buttons in a row below the card:**
  - **"일정 변경"** (ghost button, left) — white background with gray border. Tap → opens the standard reschedule flow (out of scope for this PRD; reuses the existing reschedule experience)
  - **"예습하기"** (primary green button, right) — always enabled. Tap → Pre-Study screen

> **Note on lesson entry:** The "입장하기" / lesson-room entry mechanism is not part of this card. It surfaces via a separate UI surface closer to the lesson start time and is owned by another PRD.

**Persistent bonus toast (Home screen only):**

The same persistent bonus toast described in State A is still shown on Home while the user is in State B, as long as the active bonus window is open and the bonus has not been awarded. Same placement (above the GNB, Home tab only), same dismissal rules, and same re-appearance behavior on deadline extension.

The toast styling (consistent across States A and B):
- Dark gray (#1C1C1C) pill background with subtle drop shadow
- **Gift icon (🎁)** on the left side
- Two-line copy with the **deadline date in coral/orange accent**:
  - Line 1: "**{deadline_date}까지** 첫 레슨 완료하면" (deadline date in coral)
  - Line 2: "{bonus_reward}!"
  - Example (unlimited plan): "4월 17일까지 첫 레슨 완료하면 / 이용 기간 21일 연장해 드려요!"
  - Standard package wording note: "4월 17일까지 첫 레슨 완료하면 / 추가 레슨권 4회 드려요!"
- White X button on the right edge
- Body is non-tappable; only the X button is interactive

It disappears on bonus award, deadline expiry (after extension is exhausted), or explicit X-dismissal for the current window.

**D-day badge inside the booking details card** (separate from the persistent toast — this badge always shows for any booked lesson, not just bonus-eligible ones):

| Time until lesson | Badge |
|---|---|
| ≥ 24h | "D-2", "D-1", etc. |
| 1h–24h | "{N}시간 전" |
| < 1h | "{N}분 전" |

> The Home screen also contains a "레슨 준비" section and the global bottom navigation bar (홈 / 레슨 / 예약 / AI 학습 / 마이포도). Both render below the booking card in both states but are owned by other PRDs and are out of scope here.

---

## Complete User Journeys

### Journey A: Happy Path (book immediately)

```
Purchase → Celebration (2–3s auto-advance)
→ Booking Encouragement → tap "첫 수업 예약하기"
→ Level+Time → pick recommended time → "예약 확정"
→ Booking Confirmed → "예습하기" → Pre-Study
→ (complete lesson within initial window) → bonus awarded
```

### Journey B: Try to exit, change mind via the modal

```
Purchase → Celebration → Booking Encouragement
→ tap "혜택 포기하고 나가기" → Exit Reminder Bottom Sheet
→ tap "지금 예약하기" (green button) → Level+Time
→ pick time → "예약 확정" → Booking Confirmed
```

The modal's primary action navigates **forward** into the booking flow, not back to the encouragement screen — once the user has signaled second thoughts, the system gets them past the funnel point as quickly as possible.

### Journey C: Actually exit, come back later to book

```
Purchase → Celebration → Booking Encouragement
→ tap "혜택 포기하고 나가기" → Exit Reminder Bottom Sheet
→ tap "혜택 포기하고 나가기" again → Home (not-booked state, bonus toast above GNB)
→ later: tap "예약하기" on Home → existing standard Home booking flow → booking created
→ complete within initial window → bonus awarded
```

The Exit Reminder Bottom Sheet copy implies the user will lose the bonus, but they don't — the deadline keeps running and the Home toast still appears. The post-purchase flow screens (Encouragement, Level+Time) are only used during the immediate post-purchase entry path. Once the user has exited via the modal, all subsequent booking goes through the standard booking experience — the bonus window is honored by the backend regardless of which path creates the booking.

### Journey D: Miss the initial deadline → automatic extension → still complete

```
Purchase → Celebration → Booking Encouragement → exit → Home
→ end of purchase_day + 2 passes without completion → bonus does NOT yet expire
→ system auto-extends deadline to end of purchase_day + 7
→ extension push + alimtalk fired (N5)
→ toast re-appears on Home with the new deadline date (even if previously dismissed)
→ user books via standard booking and completes within the extended window
→ bonus awarded
```

### Journey E: Miss both deadlines (full forfeit)

```
Purchase → Celebration → Booking Encouragement → exit → Home
→ initial window expires → auto-extension fires → toast re-appears
→ user still doesn't book or complete
→ end of purchase_day + 7 passes → bonus permanently forfeited
→ toast disappears from Home, no further bonus notifications fire
→ Home not-booked card stays (no bonus copy on it)
```

### Journey F: Book now, lesson is tomorrow (within initial window)

```
Purchase → Celebration → Booking Encouragement → "첫 수업 예약하기"
→ Level+Time → book for tomorrow → "예약 확정"
→ Booking Confirmed → Home (booked state)
→ complete lesson next day, still within initial window → bonus awarded
```

### Journey G: Use custom time via calendar

```
Purchase → Celebration → Booking Encouragement → "첫 수업 예약하기"
→ Level+Time → "다른 시간 보기"
→ Calendar Bottom Sheet opens → pick day and time → "확인"
→ "선택된 레슨 일정" section replaces recommended slots
→ "예약 확정" → Booking Confirmed
```

### Journey H: Double-pack user, with trial class

```
Purchase → Celebration → Booking Encouragement → "첫 수업 예약하기"
→ Level+Time → language toggle shown, default = language of last trial class (e.g. 영어)
→ level pre-set by tutor for that language
→ banner: "체험 레슨 튜터가 Start 1을 추천했어요!"
→ pick time → "예약 확정" → Booking Confirmed
```

If they switch to the other language (e.g. 일본어):
```
→ tap 일본어 → level resets via the level-default chain for JP
→ if onboarding signals a level → that level is set, no banner
→ if no onboarding data → falls back to Start 1, no banner
→ pick time → "예약 확정" → Booking Confirmed
```

### Journey I: Double-pack user, no trial class

```
Purchase → Celebration → Booking Encouragement → "첫 수업 예약하기"
→ Level+Time → language toggle shown, default = 영어
→ level resolved via chain: onboarding data → lowest level (Start 1)
→ no banner shown (tier 1 didn't win)
→ switch to 일본어 → same chain runs for JP
→ pick time → "예약 확정" → Booking Confirmed
```

### Journey J: Change level before booking

```
Purchase → Celebration → Booking Encouragement → "첫 수업 예약하기"
→ Level+Time → tap level card
→ Level Change Bottom Sheet opens → select different level → sheet closes
→ level updated → pick time → "예약 확정" → Booking Confirmed
```

---

## Incentive Logic

| Plan Type | Incentive | Condition |
|---|---|---|
| Count (회차권) | Configured bonus classes (default initial config: +2 / +4 / +8 for 3/6/12mo) | First lesson **completed** within the active bonus window (initial or extended) |
| Unlimited (무제한) | Configured day extension (default initial config: +21 / +30 / +60 for 3/6/12mo) | First lesson **completed** within the active bonus window (initial or extended) |

### Key rules

- The bonus has two phases: **initial window** (end of purchase_day + 2) and **extended window** (end of purchase_day + 7). The extension is automatic and fires exactly once, the moment the initial window expires without a completed first lesson.
- All user-facing copy uses the **absolute date** of the currently active deadline (e.g. "4월 17일까지", "4월 22일까지").
- **Leaving the post-purchase flow does not forfeit the incentive.** The deadline keeps running regardless.
- The incentive requires the user to **complete** (not just book) their first lesson within the active window. Booking alone is not enough.
- Rescheduling a booked lesson does not reset, extend, or cancel the bonus deadline.
- The Level+Time calendar in the post-purchase flow is capped at purchase_day + 0/+1/+2, and lesson length is 25 minutes, so any lesson booked through this flow is structurally **completable** inside the initial window. Bookings made later via the standard booking path may fall outside the active window; in that case no bonus applies.
- The bonus award itself is idempotent and fires at most once per purchase, regardless of how many lessons the user completes.
- Once the extended window passes without a completed lesson, the bonus is permanently forfeited and no further extensions are offered.

### Existing-system alignment notes

- The immediate post-purchase screens in this PRD are a **new purchase-triggered funnel** layered on top of the app's existing first-lesson / booking infrastructure. They are not the same thing as the legacy first-lesson booster / pre-study dialog flow that already exists in the app.
- Once the user exits to Home, all subsequent booking should reuse the app's **existing standard booking entry flow** rather than introducing a second Home-specific booking implementation.
- Bonus state is tracked **per purchase_id**. If multiple bonus-eligible purchases are active at the same time, a completed lesson can satisfy **at most one** purchase; the backend should bind the completion to the earliest-deadline active unawarded purchase.
- The active deadline must be stored and evaluated **server-side** per purchase as an absolute timestamp. Recommended contract: compute the purchase's initial / extended deadlines at purchase time using the user's timezone at purchase, store those timestamps, and use them as the single source of truth for award eligibility, extension jobs, and notification timing.

### Rollout & admin controls

- **Global kill switch:** The entire feature should be gated by a server-controlled feature flag so it can be turned on/off without deploy. When the flag is off, the purchase flow falls back to the existing success / Home behavior, the post-purchase funnel does not render, no purchase-bonus records are created, and no related notifications / award logic run.
- **Dual gating:** Gate both the **app experience** and the **backend logic**. The app flag controls whether the funnel / Home toast are shown; the backend flag controls whether purchase-bonus state is created, evaluated, extended, and awarded. This prevents partial rollout or accidental awards when the UI is off.
- **Staged rollout support:** Optional targeting is allowed (for QA users / testable cohorts / percentage rollout), but the default production behavior is a single global on/off switch.
- **Admin-configurable reward amounts:** Bonus amounts must not be hardcoded in the app. The source of truth should live in a `grape` admin-managed config surface (or equivalent admin table/UI) where operators can edit the reward for each eligible product / package.
- **Purchase-time snapshot:** When a qualifying purchase happens, the system should snapshot the effective reward config onto the purchase-bonus record (`reward_type`, `reward_amount`, copy-facing label fields if needed). Later admin edits affect **future purchases only** unless a deliberate migration tool is run.
- **Recommended ownership split:** `grape` owns the admin UI / config editing surface; `podo-backend` owns reading the snapped purchase-bonus config and applying the actual entitlement change.

### Where the incentive is shown

| Location | What's shown |
|---|---|
| Booking Encouragement screen (Screen 2) | Incentive info card pinned above the CTA, with bonus headline (default unlimited example: "21일 연장 혜택") and reinforcement copy. Standard package version uses class-count wording instead (e.g. "4회 추가 지급 혜택"). Anchors the bonus visually to the "첫 수업 예약하기" button. |
| Exit Reminder Bottom Sheet | Sad Podo mascot + "정말 나가시겠어요?" + plan-specific "혜택을 놓칠 수 있어요" copy — intentionally frames leaving as a loss, even though the bonus is actually still active |
| Home screen | Persistent bonus toast pinned above the GNB (Home only), non-clickable, with X dismiss and absolute-date copy. Re-appears with new deadline if extended. |
| Push + alimtalk notifications | N1 (booking confirmed in window), N3 (morning before deadline day), N4 (bonus awarded), N5 (deadline extended) |

The Celebration screen (Screen 1) and the Level + Time Selection screen (Screen 3) do not surface the bonus directly — Celebration is a transient 2–3 second auto-advance with no copy beyond the purchase confirmation, and Level+Time is purely a booking interaction screen. All in-flow bonus messaging is concentrated on the Booking Encouragement screen and its Exit Reminder Bottom Sheet.

---

## Bonus Award & Deadline Extension

### Automatic award

When the user's first lesson is **completed** within the currently active bonus window (initial OR extended), the system automatically grants the bonus tied to their plan — no manual claim, no in-app prompt to confirm.

**Trigger:** Lesson-completed event for the user's first lesson after purchase, where `lesson.completed_at <= active_deadline` (active_deadline = initial deadline if not yet extended, otherwise the extended deadline).

**Action by plan type:**

| Plan Type | Action |
|---|---|
| Count plan (회차권) | Add the configured bonus class count captured on the purchase-bonus record (default initial config: +2 / +4 / +8 by package duration) to the user's pack balance |
| Unlimited plan (무제한) | Extend the pack's `valid_until` date by the configured day count captured on the purchase-bonus record (default initial config: +21 / +30 / +60 by package duration) |

**Idempotency:** The award fires exactly once per purchase. If the lesson-completed event is delivered more than once, the second delivery is a no-op. If the user somehow completes a second lesson within the window, no additional bonus is granted — only the first qualifying lesson triggers the award.

### Implementation notes for current systems

- **Completion source of truth:** The frontend should not decide whether the lesson was completed. Today that completion is written in `grape` when the class is finalized: `GT_CLASS.CLASS_STATE = 'FINISH'`, `GT_CLASS.INVOICE_STATUS = 'COMPLETED'`, and `GT_CLASS.COMP_DATETIME` is stamped. `le_class_status_history.after_status = 'COMPLETED'` can be used as an additional audit trail, but `COMP_DATETIME` should be the canonical completion timestamp for bonus eligibility.
- **Qualification check:** On lesson completion, the server should look up the earliest-deadline active unawarded `purchase_bonus` record for that user, verify that the completed lesson belongs to that purchase's eligible first-lesson journey, and compare `COMP_DATETIME` (or the normalized completion timestamp derived from it) against the purchase's stored `active_deadline`.
- **Award path for count plans:** Reuse the existing bonus entitlement pattern in `podo-backend` rather than inventing a frontend-only balance patch. Recommended shape: call a dedicated backend award service that creates or updates BONUS subscribe/ticket records using the same infrastructure family that already handles bonus subscribe mappings / ticket issuance.
- **Award path for unlimited plans:** Reuse the existing backend expiry-extension methods to push the user's pack end date forward by the configured number of days. Recommended shape: the same backend award service updates the active unlimited entitlement's final/expiry date and records the purchase bonus as awarded.
- **Primary trigger strategy:** Award qualification should be checked **immediately on each lesson completion** via the existing `grape` completion write path, not via a delayed scan of all lessons. Every completion event for that user can safely attempt the check because the purchase-bonus award is idempotent.
- **Cron usage:** Use cron only for scheduled responsibilities that are naturally time-based: deadline extension at the initial-window boundary, reminder sends (N3), and a low-frequency reconciliation / repair job for rare cases where a completion event succeeded but the downstream award call failed.
- **Recommended ownership split:** `grape` (or the system that currently owns lesson completion writes) detects that the lesson actually finished, then hands off to a `podo-backend` bonus-award service for entitlement changes and notification N4. This keeps the qualification check close to the real completion event while centralizing reward issuance in the backend that already owns tickets / subscribes / notifications.

### Automatic deadline extension

When the **initial** bonus window expires without a completed first lesson, the system automatically extends the deadline once.

**Trigger:** A scheduled job runs at the moment the initial deadline passes (end of purchase_day + 2, user local time). For each purchase where the bonus has not been awarded and not been extended yet:

1. Set `extended_deadline = end of day on purchase_day + 7` (user local time)
2. Reset the toast dismissal flag for the new window phase (so the toast re-appears on Home next time the user opens the app)
3. Fire notification N5 (push + alimtalk) telling the user about the new deadline

**Extension is one-shot:** The extension fires exactly once per purchase. If the user misses the extended deadline as well, the bonus is permanently forfeited and no further extensions are offered.

**No retroactive awards:** If the user happens to complete a lesson during the brief moment between the initial deadline passing and the extension job running, that lesson still counts — the system always evaluates against `max(initial_deadline, extended_deadline_if_set)`.

### Notification lifecycle

The post-purchase flow sends notifications at up to five moments across the bonus window. **All notifications go out on both channels (push + alimtalk)** unless noted. There is no in-app celebration screen or modal in this scope — push and alimtalk are the entire out-of-app communication surface.

**Variable conventions used below:**
- `{lessonDateLabel}` = user-facing localized lesson date label (e.g. `4월 17일(수)`)
- `{lessonTime}` = localized lesson start time (e.g. `오후 8:30`)
- `{deadlineDate}` = absolute localized deadline date (e.g. `4월 17일`)
- `{rewardCount}` = snapped count-plan reward amount for this purchase (e.g. `4`)
- `{rewardDays}` = snapped unlimited-plan reward amount for this purchase (e.g. `21`)

| # | When it fires | Trigger condition | Purpose |
|---|---|---|---|
| **N1** | **On booking confirmation** — first lesson booked within the active bonus window | User taps "예약 확정" on Level+Time screen, OR creates a booking via the standard booking path with `lesson.scheduled_end_at <= active_deadline` | Confirm booking + reinforce that the bonus is earned by *completing* the class |
| **N2** | **On booking confirmation** — first lesson booked **outside** the active bonus window | Booking created via the standard booking path with `lesson.scheduled_end_at > active_deadline` | Confirm booking. Do not mention the bonus — the user is knowingly past the deadline |
| **N3** | **Morning of the day before the active deadline day** (purchase_day + 1 for the initial window, purchase_day + 6 for the extended window), not yet booked | At 9am local on the day before the active deadline day, no lesson has been booked yet AND the bonus has not been forfeited or awarded | Urgency push to book and complete before the next night |
| **N4** | **Bonus awarded** — first lesson completed within the active window | `lesson.completed_at <= active_deadline` and award has been applied | Celebrate the win and confirm what was added to the user's account |
| **N5** | **Deadline extended** — initial window expired without completion, system auto-extended to purchase_day + 7 | Triggered by the extension job at the moment the initial deadline passes, only if the bonus is not yet awarded and not yet forfeited | Inform the user of the new deadline and re-engage them with a fresh chance to earn the bonus |

### Notification copy drafts

#### N1 — Booking completed inside the active bonus window

| Channel | Count plan copy | Unlimited plan copy |
|---|---|---|
| **Push** | Title: `첫 레슨 예약 완료!` Body: `{lessonDateLabel} {lessonTime} 수업까지 완료하면 보너스 레슨 {rewardCount}회를 드려요.` | Title: `첫 레슨 예약 완료!` Body: `{lessonDateLabel} {lessonTime} 수업까지 완료하면 이용 기간 {rewardDays}일 연장 혜택을 드려요.` |
| **Alimtalk** | `안녕하세요, 포도입니다.\n첫 레슨 예약이 완료되었어요.\n{lessonDateLabel} {lessonTime} 수업을 {deadlineDate}까지 완료하면 보너스 레슨 {rewardCount}회를 드려요.` | `안녕하세요, 포도입니다.\n첫 레슨 예약이 완료되었어요.\n{lessonDateLabel} {lessonTime} 수업을 {deadlineDate}까지 완료하면 이용 기간 {rewardDays}일 연장 혜택을 드려요.` |

#### N2 — Booking completed outside the active bonus window

| Channel | Copy |
|---|---|
| **Push** | Title: `첫 레슨 예약 완료!` Body: `{lessonDateLabel} {lessonTime}에 만나요.` |
| **Alimtalk** | `안녕하세요, 포도입니다.\n첫 레슨 예약이 완료되었어요.\n{lessonDateLabel} {lessonTime}에 만나요.` |

#### N3 — Reminder on the morning before deadline day

| Channel | Count plan copy | Unlimited plan copy |
|---|---|---|
| **Push** | Title: `혜택 마감이 내일이에요` Body: `내일 밤까지 첫 레슨을 완료하면 보너스 레슨 {rewardCount}회를 드려요.` | Title: `혜택 마감이 내일이에요` Body: `내일 밤까지 첫 레슨을 완료하면 이용 기간 {rewardDays}일 연장 혜택을 드려요.` |
| **Alimtalk** | `안녕하세요, 포도입니다.\n{deadlineDate}까지 첫 레슨을 완료하면 보너스 레슨 {rewardCount}회를 드려요.\n마감 전 첫 레슨을 예약해 보세요.` | `안녕하세요, 포도입니다.\n{deadlineDate}까지 첫 레슨을 완료하면 이용 기간 {rewardDays}일 연장 혜택을 드려요.\n마감 전 첫 레슨을 예약해 보세요.` |

#### N4 — Bonus awarded

| Channel | Count plan copy | Unlimited plan copy |
|---|---|---|
| **Push** | Title: `보너스가 지급됐어요!` Body: `첫 레슨 완료 축하드려요. 보너스 레슨 {rewardCount}회가 추가됐어요.` | Title: `보너스가 지급됐어요!` Body: `첫 레슨 완료 축하드려요. 이용 기간이 {rewardDays}일 연장됐어요.` |
| **Alimtalk** | `안녕하세요, 포도입니다.\n첫 레슨 완료를 축하드려요.\n보너스 레슨 {rewardCount}회가 지급되었어요.` | `안녕하세요, 포도입니다.\n첫 레슨 완료를 축하드려요.\n이용 기간이 {rewardDays}일 연장되었어요.` |

#### N5 — Initial window expired, extended window opened

| Channel | Count plan copy | Unlimited plan copy |
|---|---|---|
| **Push** | Title: `혜택 기회를 한 번 더 드려요` Body: `{deadlineDate}까지 첫 레슨을 완료하면 보너스 레슨 {rewardCount}회를 드려요.` | Title: `혜택 기회를 한 번 더 드려요` Body: `{deadlineDate}까지 첫 레슨을 완료하면 이용 기간 {rewardDays}일 연장 혜택을 드려요.` |
| **Alimtalk** | `안녕하세요, 포도입니다.\n첫 레슨 혜택 기간을 한 번 더 열어드렸어요.\n{deadlineDate}까지 첫 레슨을 완료하면 보너스 레슨 {rewardCount}회를 드려요.` | `안녕하세요, 포도입니다.\n첫 레슨 혜택 기간을 한 번 더 열어드렸어요.\n{deadlineDate}까지 첫 레슨을 완료하면 이용 기간 {rewardDays}일 연장 혜택을 드려요.` |

**Notes on each notification:**

- **N1 vs N2 split:** A post-purchase-flow booking always triggers N1 (the calendar is structurally capped inside the initial window). N2 is only possible via the standard booking path with a lesson end time past the active deadline. A user can never get both for the same booking.
- **N3 timing:** N3 fires on the morning **before** the deadline day at 9am local. Copy explicitly tells the user they have until "tomorrow night" to complete. N3 fires for both phases — once for the initial window (morning of purchase_day + 1) and once for the extended window (morning of purchase_day + 6), suppressed in each case if the user has already booked or if the bonus is already awarded/forfeited.
- **N3 suppression:** N3 does not fire if the user has already booked a qualifying lesson (no reminder needed) or if the bonus has already been awarded or forfeited.
- **N4 idempotency:** N4 fires exactly once, tied to the same idempotency rule as the bonus award itself.
- **N5 idempotency:** N5 fires exactly once per purchase, tied to the extension job which is also one-shot.
- **Post-N4 silence:** Once N4 fires, no further bonus-related notifications are sent for this purchase (no N5, no second N3).
- **Post-forfeit silence:** Once the extended window expires without completion, no further bonus-related notifications are sent.

**Channels:**

| Channel | Role |
|---|---|
| **Push notification** | Tap-through to Home; surfaces on the device lock screen for immediate visibility |
| **Alimtalk (KakaoTalk 알림톡)** | Persistent record in the user's KakaoTalk; reaches users who have in-app push disabled |

**Failure handling:** If either channel fails to deliver, the underlying state (booking, award, extension) is unaffected. Notification delivery is logged but not retried inside this flow. If only one of the two channels succeeds, that is acceptable — they are intentionally redundant.

---

## Level Defaults

The default level is resolved per-language using a 3-tier fallback chain. The first tier with a value wins.

| Priority | Source | Banner shown? |
|---|---|---|
| 1 | **Trial class recommendation** — the level recommended by the tutor in the user's most recent trial class for this language | Yes — "체험 레슨 튜터가 **{level}**을 추천했어요!" |
| 2 | **Onboarding data** — the level inferred from the user's onboarding answers (this signal exists today) | No banner |
| 3 | **Lowest level** — Start 1 for both EN and JP, used only when neither tier 1 nor tier 2 has data | No banner |

Key behavior:
- The chain is evaluated **per language**. A double-pack user might get a tier-1 result for EN (trial taken in English) and a tier-2 result for JP (no JP trial, but onboarding signals).
- The recommendation banner only appears when tier 1 wins. Tiers 2 and 3 show the level card with no banner above it.
- Switching language on the Level+Time screen re-runs the chain for the newly selected language and clears the selected lesson date/time. The screen does **not** remember prior EN/JP selections when toggling back.

**Default language for double-pack:**
- With trial → the language of their most recent trial class
- Without trial → English

---

## Time Selection Rules

1. **Recommended slots:** The **next 6 closest available time slots** across the initial bonus window (purchase_day + 0/+1/+2), displayed in a 2-column grid and ordered chronologically
2. **Calendar sheet:** Shows 3 days (purchase_day + 0/+1/+2 — today, tomorrow, day-after-tomorrow). For today, past times / near-term times inside the existing **2-hour booking cutoff** are hidden entirely. The 3-day cap is intentional so every selectable slot falls inside the initial bonus window
3. **Slot availability:** ~85% of slots are available; unavailable slots are shown as disabled (gray) in the calendar sheet
4. **AM/PM separation:** Calendar sheet separates time slots into AM and PM sections, displayed in 3-column grids
5. **Lesson duration:** 25 minutes (the Booking Confirmed screen still shows only the lesson start time, e.g. "2월 28일(수) 16:30")

---

## Visual Design Notes

This flow uses the existing PrimaryButton and GhostButton components from the global design system. Two color treatments are specific to this flow and worth calling out:

| Usage | Color |
|---|---|
| Celebration screen checkmark circle (Screen 1) | Bright green fill, dark checkmark |
| Booking Encouragement screen (Screen 2) primary CTA — "첫 수업 예약하기" | Blue/violet treatment (distinct from the green used elsewhere — visually marks the funnel CTA) |
| Incentive info card (Booking Encouragement screen, pinned above CTA) | Background #F2F5FF, outline #DFE6FF, accent text #6184FF |
| Exit Reminder Bottom Sheet primary CTA — "지금 예약하기" | Bright lime green (distinct from Screen 2's blue/violet — feels like a fresh affirmative action) |
| Persistent bonus toast (Home screen only, above GNB) | Background #1C1C1C (near-black), text #FFFFFF, subtle drop shadow |

All other colors (selection outlines, level/time selected states, disabled states) follow the global tokens.
