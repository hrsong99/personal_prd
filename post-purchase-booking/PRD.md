# PRD: Post-Purchase First Lesson Booking Flow

## Overview

After a user completes a lesson plan purchase, they enter a guided flow designed to convert them into an active learner by booking their first lesson. The user receives a bonus incentive if they complete their first lesson by the end of the bonus deadline. The flow strongly encourages booking immediately but does not punish the user for leaving — the incentive remains available throughout the bonus window, and the deadline is automatically extended once if the user misses the initial window.

This PRD covers the immediate post-purchase booking flow: a brief celebration screen → Booking Encouragement screen → Level + Time Selection → Booking Confirmed, plus the two Home screen states that reflect booking status, and the bonus deadline extension behavior.

---

## Funnel Eligibility

Not every purchase enters the full booking funnel. Eligibility is split into two paths.

### "First real purchase" — full funnel path

A user enters the full post-purchase funnel (Celebration → Booking Encouragement → Level+Time → Booking Confirmed, plus the bonus window, Home states, and notifications) on what we consider their **"first real purchase"**. A purchase qualifies as a first real purchase if:

- The user has never previously made a paid lesson-pack purchase, **OR**
- **Every** prior paid purchase on the user's account was fully refunded under the 7-day cooling-off rule (see below)

Trial classes never count as a paid purchase for this rule.

This is the only entry point that creates a `purchase_bonus` record and the only path that surfaces the bonus incentive in-app.

#### 7-day cooling-off rule (청약철회) — auto-renewed eligibility after a clean refund

A prior purchase is **treated as if it never happened** for funnel eligibility purposes if ALL of the following are true:

1. The purchase was **fully refunded** (100% refund, not partial)
2. **Zero lessons were completed** on that purchase before the refund — trial lessons still don't count, but any finalized regular lesson on the pack disqualifies it
3. The refund was issued **within 7 days** of the purchase date, matching the Korean 청약철회 cooling-off window

If a user's entire purchase history on their account consists of purchases that all meet those 3 criteria, the next purchase is treated as a first real purchase and they receive the full funnel + bonus + N1–N5 notifications. Example: user buys a 6-month 무제한 pack, has second thoughts, refunds on day 3 with 0 lessons taken → 6 weeks later buys a 3-month 라이트 루틴 pack → this 3-month purchase is treated as their first real purchase.

Conversely, if ANY prior purchase fails even one of the 3 criteria (partial refund, any completed lesson, or day-8+ refund), the user is treated as a repurchaser on every subsequent purchase and routed to the celebration-only variant below. One "real" purchase anywhere in the user's history permanently moves them out of the funnel.

**Implementation note:** This check runs server-side at purchase time. The backend queries the user's full purchase history, filters for any purchase that fails the 3 criteria, and only creates a `purchase_bonus` record if every prior purchase passes. The check is cheap (bounded by the user's lifetime purchase count) and should live next to the existing post-purchase hook that routes users into the celebration screen.

### Other purchases — celebration-only path

Every other purchase (repurchases, plan upgrades, language additions to an existing user, renewal of an active plan, etc.) does **not** enter the full funnel. Instead:

- The user sees **Screen 1 (Purchase Celebration) only**, with a small variant: instead of auto-advancing after 2–3 seconds, an **"확인" button** appears at the bottom and tapping it routes back to Home
- No Booking Encouragement screen, no Level+Time screen, no bonus card, no exit modal
- No `purchase_bonus` record is created
- No bonus toast on Home, no N1–N5 notifications
- The standard existing first-lesson alimtalks (`pd_reg_weeklyclass_2`, `pd_reg_infinity_2`) still fire when these users eventually book through the standard booking path — see "Existing-system alignment notes" below

### Admin override — re-grant the bonus eligibility (no funnel re-entry)

For edge cases where a first-time buyer loses their bonus eligibility through no fault of their own (refunded to switch packages, support escalation, never received the experience due to a bug, etc.), `grape` should expose an **admin action** to re-create or re-activate a `purchase_bonus` record on the user's behalf.

The admin-granted bonus path is **notification-and-toast only** — the user does NOT re-enter the post-purchase funnel screens. Specifically:

- A new `purchase_bonus` record is created with a fresh deadline (initial window starts at admin-grant time, same purchase_day + 2 / + 7 phasing)
- Home shows the bonus toast as in State A / State B
- N1 / N3 / N4 / N5 notifications fire as normal against the new deadline
- N2 still suppresses the bonus mention if the user books a lesson outside the window

Admin grants are auditable (who granted, when, against which purchase_id, reason text).

---

## User Segments

### Language pack x Trial class matrix

|  | Single-language | Double-pack (EN + JP) |
|---|---|---|
| **With trial class** | Level pre-set by tutor recommendation. Banner: "체험 레슨 튜터가 {level}을 추천했어요!" | Language toggle shown. Default language = the language of their most recent trial class. Level for that language pre-set by tutor. The other language falls through the level-default chain (see "Level Defaults" below). Banner only appears for the trial-recommended language. |
| **No trial class** | Level defaulted via the level-default chain (onboarding data → lowest level). No banner. | Language toggle shown. Default language = English. Both languages use the level-default chain. No banner. |

### Plan type (orthogonal to above)

The two currently-sold plan shapes are:

| Plan | Description | First-lesson incentive |
|---|---|---|
| **무제한 레슨권 (Unlimited)** | Unlimited lessons for a fixed period (3 / 6 / 12 months) | **Day extension only** — +21 / +30 / +60 days on first lesson completion within the bonus window |
| **라이트 루틴 레슨권 (Light Routine, 월8회)** | 8 lessons per month for a fixed period (3 / 6 / 12 months) | **Day extension AND bonus classes** — +21 days + 5회 / +30 days + 8회 / +60 days + 12회 on first lesson completion within the bonus window |

Both plans receive a day extension; only Light Routine also receives additional class credits.

### Package duration variants

| Plan Duration | 무제한 (Unlimited) | 라이트 루틴 (Light Routine, 월8회) |
|---|---|---|
| 3 months | +21 day extension | +21 day extension **and** +5 bonus classes |
| 6 months | +30 day extension | +30 day extension **and** +8 bonus classes |
| 12 months | +60 day extension | +60 day extension **and** +12 bonus classes |

Every combination of language pack, trial state, and plan type flows through the same screens — only the defaults, banners, and incentive copy differ.

---

## Bonus Window Definition

The bonus window has two phases. There is exactly one **currently communicated** deadline at any given time, but eligibility is always evaluated against `max(initial_deadline, extended_deadline_if_set)` to handle the brief gap between the initial-window expiry and the extension job firing (see "Automatic deadline extension" below).

| Phase | Deadline | How it starts |
|---|---|---|
| **Initial window** | End of day (23:59:59 in the timezone snapshotted at purchase) on **purchase_day + 2** | Begins at the moment of purchase |
| **Extended window** | End of day (23:59:59 in the timezone snapshotted at purchase) on **purchase_day + 7** | Automatically begins the moment the initial window expires without a completed first lesson |

The window is **at least 48 hours** for any purchase (a 11:59 PM purchase still gets to end of the day-after-tomorrow, ~48h+; an early-morning purchase gets close to ~72h). This is intentional — the window is "at least 2 days," not "exactly N hours."

Both phases use the **same bonus reward** — the only difference is the deadline date. The user gets one chance to earn the bonus across the combined window. Once the extended window expires without a completed lesson, the bonus is forfeited permanently.

### Timezone source of truth

The deadline is snapshotted **once at purchase time** and stored as an absolute UTC timestamp on the `purchase_bonus` record, computed using the user's device timezone at the moment of purchase. This snapshotted timestamp is the **single source of truth** for every downstream surface:

| Surface | What it reads |
|---|---|
| Eligibility check (award qualification) | The stored absolute UTC timestamp |
| Extension job scheduling | The stored absolute UTC timestamp |
| Notification timing (N3, N5) | The stored absolute UTC timestamp, scheduled in the snapshotted timezone |
| Home toast `{deadline_date}` copy | Localized date string derived from the snapshotted timezone (NOT the device's current timezone) |
| Booking calendar `오늘 / 내일` labels | Localized in the snapshotted timezone, NOT the device's current timezone |
| Alimtalk relative-day phrasing | Computed against the snapshotted timezone |

This means a user who purchases in Seoul and then travels to LA still sees the same "오늘 / 내일" labels and the same deadline date that they would have seen in Seoul. Trade-off: a user who permanently relocates may briefly see slightly stale-feeling labels, but eligibility and the displayed dates always agree, which is the more important property.

### User-facing copy: in-app vs alimtalk

- **In-app surfaces** (Home toast, screen copy, calendar labels) use the **absolute date** of the currently active deadline (e.g. "4월 17일까지").
- **Alimtalk and push notifications** prefer **relative phrasing** ("이틀 안에 첫 레슨 완료하면", "내일 밤까지") because copy in messaging channels reads more naturally in conversational tone and avoids "당일/익일" mid-stream confusion. Specific drafts are below in the Notification section.

---

## Screen-by-Screen Specification

### Screen 1: Purchase Celebration

A brief, full-screen celebration that acknowledges the purchase. The screen has **two variants** depending on whether the user is eligible for the full funnel (see "Funnel Eligibility" above).

**Common visuals (both variants):**

- White background
- Vertically centered content stack:
  - Bright green checkmark icon inside a bright green circle
  - Title: **"구매가 완료되었어요!"** (bold, centered)
  - Subtitle: **plan name** in muted gray, dynamically populated from the user's purchase. Examples:
    - "영어 무제한 레슨권 12개월"
    - "영어 라이트 루틴 레슨권 6개월"
    - "일본어 무제한 레슨권 3개월"

#### Variant A — First real purchase (auto-advance)

The user is eligible for the full funnel. The screen has **no CTAs** — it auto-advances to the Booking Encouragement screen after **2–3 seconds**. The user cannot interact with this screen, dismiss it, or back out of it.

| Event | Destination |
|---|---|
| 2–3 seconds elapsed (no user action required) | → Screen 2: Booking Encouragement |

The 2–3 second window is intentional: long enough for the user to register the success state, short enough to feel snappy and not block them from booking.

#### Variant B — Other purchases (manual confirm)

The user is NOT eligible for the full funnel (repurchase, upgrade, plan switch, etc.). The same celebration visuals are shown, but with a single bottom CTA:

- **Primary green button: "확인"** — full-width, always enabled

| Action | Destination |
|---|---|
| "확인" | → Home (no funnel, no Booking Encouragement, no bonus toast) |

There is no auto-advance and no exit modal in this variant. The user dismisses on their own.

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
  - Bold blue headline and description vary by plan type:
    - **무제한 (3 / 6 / 12 mo):** `"21일 연장 혜택"` / `"30일 연장 혜택"` / `"60일 연장 혜택"` — description: `"지금 바로 첫 레슨하면 이용 기간을 연장해 드려요"`
    - **라이트 루틴 (3 mo):** `"21일 연장 + 5회 추가 혜택"` — description: `"지금 바로 첫 레슨하면 이용 기간 연장과 보너스 레슨을 드려요"`
    - **라이트 루틴 (6 mo):** `"30일 연장 + 8회 추가 혜택"` — same description
    - **라이트 루틴 (12 mo):** `"60일 연장 + 12회 추가 혜택"` — same description
  - **Drop shadow:** soft neutral shadow to lift the card off the confetti background: `0 4px 12px rgba(15, 23, 42, 0.08)`, no blur on the card itself
- **Primary CTA: "첫 수업 예약하기"** — full-width primary button (blue/violet treatment), always enabled
  - **Drop shadow:** blue-tinted so the button visually belongs to the same color family as its fill: `0 8px 20px rgba(97, 132, 255, 0.28)` (the same `#6184FF` accent used by the incentive card), slightly more pronounced than the card above it so the CTA reads as the top of the visual hierarchy
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
- Each slot shows date + time:
  - Today's slots use the relative label: **"오늘 10:00"**
  - Tomorrow's slots use: **"내일 21:30"**
  - Slots for the day after tomorrow (still inside the initial window) use the absolute calendar label: **"4월 21일 21:30"**
- **Padding from later days when a day runs thin:** The grid always shows 6 slots whenever at least 6 are available inside the 3-day window. If today has fewer than 6 remaining slots (e.g. the user purchased late at night and the 2-hour booking cutoff has trimmed today down to 2 slots), the grid continues filling from tomorrow, then the day after tomorrow, using the chronologically next available slots across the 3-day window. Slots from different days are labeled with their respective "오늘 / 내일 / 4월 21일" prefix as described above so the user can always tell which day a slot belongs to
- **When fewer than 6 slots are available in the entire 3-day window:** Render only the available slots (no placeholders, no padding to 6). The "다른 시간 보기" button remains visible
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
  - **무제한 (Unlimited):** "지금 나가면 이용 기간 연장 혜택을 놓칠 수 있어요."
  - **라이트 루틴 (Light Routine):** "지금 나가면 이용 기간 연장과 보너스 레슨 혜택을 놓칠 수 있어요."
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

- **Placement:** Just above the bottom GNB, Home screen only. The toast visually overlaps the top edge of the GNB so the GNB icons are partially covered and readable-through thanks to the backdrop blur described below
- **Style:** **Translucent** dark gray pill: background `rgba(28, 28, 28, 0.72)` (not solid — the Home content behind it bleeds through), **backdrop filter: `blur(16px) saturate(140%)`** so the GNB icons beneath it are visibly blurred and the pill reads as a floating layer, white text, gift icon on the left, X button on the right
- **Drop shadow:** `0 8px 24px rgba(0, 0, 0, 0.24)` — softer and wider than the Screen 2 CTA's shadow to match the translucent floating feel
- **Copy (two lines):** Line 1: `"{deadline_date}까지 첫 레슨 완료하면"` (with the deadline date emphasized in the app's primary green `#B5FD4C`). Line 2: `"{bonus_reward}!"`
  - `{deadline_date}` is the absolute calendar date of the **currently active** deadline (initial or extended), rendered in `#B5FD4C`
  - `{bonus_reward}` is filled by plan type and package duration per the table below:

  | Plan | Duration | `{bonus_reward}` |
  |---|---|---|
  | 무제한 | 3 months | `이용 기간 21일 연장해 드려요` |
  | 무제한 | 6 months | `이용 기간 30일 연장해 드려요` |
  | 무제한 | 12 months | `이용 기간 60일 연장해 드려요` |
  | 라이트 루틴 | 3 months | `추가 레슨권 5회 드려요` |
  | 라이트 루틴 | 6 months | `추가 레슨권 8회 드려요` |
  | 라이트 루틴 | 12 months | `추가 레슨권 12회 드려요` |

  The 라이트 루틴 variants **intentionally omit the day-extension half** — the pill has limited horizontal room and the class-count half is the more visible win. The full combined reward (days + classes) is still communicated on Screen 2's incentive card and in the alimtalks.

  - Example (무제한 3mo, extended window): "4월 22일까지 첫 레슨 완료하면 / 이용 기간 21일 연장해 드려요!"
  - Example (라이트 루틴 6mo, initial window): "4월 17일까지 첫 레슨 완료하면 / 추가 레슨권 8회 드려요!"
- **Interaction:**
  - Body is **not tappable** — it is purely informational and does not navigate anywhere
  - Tapping the X button is a **24h snooze** (not terminal) — see Lifecycle below
- **Lifecycle:**
  - Appears immediately when the user first lands on Home after purchase
  - Persists across app sessions until (a) the active bonus window expires, or (b) the user completes their first lesson and the bonus is awarded. X-tap is a 24h snooze, not terminal — see below.
  - **X = 24h snooze.** Tapping X hides the toast for **24 hours** from the dismissal timestamp; it reappears automatically on the next Home mount after the snooze elapses. Each subsequent X-tap resets the 24h timer. **If the active deadline passes (forfeit) or the bonus is awarded while the snooze is still running, the toast stays hidden permanently** — no reason to re-surface it after the bonus is resolved.
  - **Re-appears on extension:** If the initial window expires without completion and the deadline is automatically extended, the toast **re-appears with the new deadline date regardless of any running snooze** — the extension event flips the phase (initial → extended) and resets the dismissal row for the new phase. The 24h snooze rule applies independently inside the extended phase (user can keep re-dismissing; each tap buys another 24h of silence until the extended window expires).
- **Dismissal persistence:** The X-dismissal is stored server-side as a `dismissed_at` timestamp scoped to `(purchase_id, window_phase)`, so the 24h countdown survives app reinstall, logout/login, and multi-device usage. The two phases (initial, extended) have independent dismissal rows.
- **Multiple purchases edge case:** If the user has multiple unconsumed bonus-eligible purchases simultaneously (rare — practically only possible via admin re-grant on top of a new first purchase), only one toast is shown at a time, and the Home card (State A or State B) reflects the **latest purchase** (by `created_at`). The toast also follows the latest purchase. Rationale: the most recent purchase is what the user is most likely to act on, and showing "earliest deadline" can produce confusing card state where the card refers to a purchase the user is no longer thinking about.

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
- **Translucent** dark gray pill — background `rgba(28, 28, 28, 0.72)` with `backdrop-filter: blur(16px) saturate(140%)` so the Home content and GNB icons beneath it are visibly blurred through the pill
- Drop shadow `0 8px 24px rgba(0, 0, 0, 0.24)` to lift it off the Home content
- **Gift icon (🎁)** on the left side
- Two-line copy with the **deadline date emphasized in the app's primary green `#B5FD4C`**:
  - Line 1: "**{deadline_date}까지** 첫 레슨 완료하면" (deadline date in `#B5FD4C`)
  - Line 2: "{bonus_reward}!"
  - `{bonus_reward}` uses the same plan × duration table defined in State A above — single source of truth across both Home states.
- White X button on the right edge
- Body is non-tappable; only the X button is interactive

It disappears on bonus award or deadline expiry (after extension is exhausted). Explicit X-dismissal is a 24h snooze — the toast reappears on the next Home mount after 24h have elapsed unless the bonus has already been awarded or forfeited (see State A → Lifecycle for the full rule).

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
→ extension push + alimtalk fired (N5); N6 and N7 scheduled for the extended window
→ toast re-appears on Home with the new deadline date (even if previously dismissed)
→ morning of purchase_day + 6: N6 fires (if still unbooked)
→ 6h before deadline: N7 fires (if still unbooked)
→ user books via standard booking and completes within the extended window
→ pending N6/N7 cancelled, bonus awarded (N4)
```

### Journey E: Miss both deadlines (full forfeit)

```
Purchase → Celebration → Booking Encouragement → exit → Home
→ initial window expires → auto-extension fires (N5) → toast re-appears; N6/N7 scheduled
→ user still doesn't book or complete; N6 fires on D-1 morning; N7 fires 6h before deadline
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
| 무제한 (Unlimited) | Day extension: **+21 / +30 / +60 days** for 3 / 6 / 12-month packs | First lesson **completed** within the active bonus window (initial or extended) |
| 라이트 루틴 (Light Routine, 월8회) | Day extension **and** bonus classes: **+21d + 5회 / +30d + 8회 / +60d + 12회** for 3 / 6 / 12-month packs | First lesson **completed** within the active bonus window (initial or extended) |

### Key rules

- The bonus has two phases: **initial window** (end of purchase_day + 2) and **extended window** (end of purchase_day + 7). The extension is automatic and fires exactly once, the moment the initial window expires without a completed first lesson.
- All user-facing copy uses the **absolute date** of the currently active deadline (e.g. "4월 17일까지", "4월 22일까지").
- **Leaving the post-purchase flow does not forfeit the incentive.** The deadline keeps running regardless.
- The incentive requires the user to **complete** (not just book) their first lesson within the active window. Booking alone is not enough.
- Rescheduling a booked lesson does not reset, extend, or cancel the bonus deadline. Eligibility is re-evaluated against the rescheduled `scheduled_end_at`.
- **Cancel semantics:** If the user cancels the booked first lesson entirely (without rebooking), the Home state reverts to **State A (Not Booked)** and the bonus toast re-surfaces if the deadline is still active. The `purchase_bonus` record is not affected — the user can still earn the bonus by rebooking and completing within the window.
- **Reschedule out of the window:** If the user reschedules their booked lesson to a time where `scheduled_end_at > active_deadline`, they are effectively voluntarily opting out of the bonus for this booking. In this case:
  - Home stays in State B (the booking still exists)
  - The bonus toast **reappears even if it was previously dismissed**, with the original deadline date still shown, so the user has an immediate visual cue to compare their new booking time against the deadline and reconsider. This is admittedly non-ideal from a "respect explicit dismissal" standpoint, but for v1 it is the simplest way to prevent silent loss of the bonus
  - The user can still reschedule again (or cancel and rebook) to a slot inside the window and earn the bonus as long as they do so before the deadline
  - The Reschedule screen should additionally show a one-time warning sheet when the user picks a new slot with `scheduled_end_at > active_deadline`: **"이 시간으로 옮기면 혜택을 받을 수 없어요"** with Confirm / Cancel. Proactive and honest — see "Reschedule guardrail" below.
- The Level+Time calendar in the post-purchase flow is capped at purchase_day + 0/+1/+2, and lesson length is 25 minutes, so any lesson booked through this flow is structurally **completable** inside the initial window. Bookings made later via the standard booking path may fall outside the active window; in that case no bonus applies.
- The bonus award itself is idempotent and fires at most once per purchase, regardless of how many lessons the user completes.
- Once the extended window passes without a completed lesson, the bonus is permanently forfeited and no further extensions are offered.

### Existing-system alignment notes

- The immediate post-purchase screens in this PRD are a **new purchase-triggered funnel** layered on top of the app's existing first-lesson / booking infrastructure. They are not the same thing as the legacy first-lesson booster / pre-study dialog flow that already exists in the app.
- Once the user exits to Home, all subsequent booking should reuse the app's **existing standard booking entry flow** rather than introducing a second Home-specific booking implementation.
- Bonus state is tracked **per purchase_id**. If multiple bonus-eligible purchases are active at the same time, a completed lesson can satisfy **at most one** purchase; the backend should bind the completion to the **latest** active unawarded `purchase_bonus` (by `created_at`) to match the Home card/toast precedence rule — the card the user saw when they booked should be the card that gets awarded.
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
| Booking Encouragement screen (Screen 2) | Incentive info card pinned above the CTA, with plan-specific bonus headline — 무제한 shows day-extension language (e.g. "21일 연장 혜택"); 라이트 루틴 shows combined language (e.g. "21일 연장 + 5회 추가 혜택"). Anchors the bonus visually to the "첫 수업 예약하기" button. |
| Exit Reminder Bottom Sheet | Sad Podo mascot + "정말 나가시겠어요?" + plan-specific "혜택을 놓칠 수 있어요" copy — intentionally frames leaving as a loss, even though the bonus is actually still active |
| Home screen | Persistent bonus toast pinned above the GNB (Home only), non-clickable, with X dismiss and absolute-date copy. Re-appears with new deadline if extended. |
| Push + alimtalk notifications | N1 (booking confirmed in window), N3 (morning before deadline day), N4 (bonus awarded), N5 (deadline extended) |

The Celebration screen (Screen 1) and the Level + Time Selection screen (Screen 3) do not surface the bonus directly — Celebration is a transient 2–3 second auto-advance with no copy beyond the purchase confirmation, and Level+Time is purely a booking interaction screen. All in-flow bonus messaging is concentrated on the Booking Encouragement screen and its Exit Reminder Bottom Sheet.

---

## Bonus Award & Deadline Extension

### Automatic award

When the user's first lesson is **completed** within the currently active bonus window (initial OR extended), the system automatically grants the bonus tied to their plan — no manual claim, no in-app prompt to confirm.

**Trigger:** The lesson-completed event fired when the tutor finalizes the class in `grape` (`GT_CLASS.CLASS_STATE = 'FINISH'`, `INVOICE_STATUS = 'COMPLETED'`, `COMP_DATETIME` stamped). The write path on tutor finalize is the authoritative signal that the lesson actually finished.

**Eligibility check:** Compare the lesson's **`scheduled_end_at`** (the planned lesson end time) — NOT `COMP_DATETIME` — against the active deadline: `scheduled_end_at <= max(initial_deadline, extended_deadline_if_set)`.

The reason eligibility uses `scheduled_end_at` rather than `COMP_DATETIME`:

- `COMP_DATETIME` is stamped by the tutor's finalize action and can lag the real lesson end by several minutes (occasionally more). A lesson that was scheduled 23:30–23:55 on the deadline day but gets finalized at 00:02 the next day should still qualify — the user did everything right, only the tutor's paperwork was slow.
- `scheduled_end_at` is known at booking time and is entirely in the user's control. If they book a slot whose `scheduled_end_at` falls inside the window, the system can truthfully promise them the bonus in N1.
- The finalize event is still the **trigger** (we only check eligibility once we know the lesson actually happened), but the **comparison** is done against `scheduled_end_at`.

**Action by plan type:**

| Plan Type | Action |
|---|---|
| 무제한 (Unlimited) | Extend the pack's `valid_until` date by the configured day count (+21 / +30 / +60 by package duration) captured on the purchase-bonus record |
| 라이트 루틴 (Light Routine, 월8회) | **Both actions as a single atomic award:** (1) extend the pack's `valid_until` date by the configured day count (+21 / +30 / +60), AND (2) add the configured bonus class count (+5 / +8 / +12) to the user's pack balance. Both mutations must succeed together and count as a single idempotent award event — N4 fires exactly once regardless of which mutation ran first |

**Idempotency:** The award fires exactly once per purchase. If the lesson-completed event is delivered more than once, the second delivery is a no-op. If the user somehow completes a second lesson within the window, no additional bonus is granted — only the first qualifying lesson triggers the award.

### Implementation notes for current systems

- **Completion source of truth:** The frontend should not decide whether the lesson was completed. Completion is written in `grape` when the class is finalized: `GT_CLASS.CLASS_STATE = 'FINISH'`, `GT_CLASS.INVOICE_STATUS = 'COMPLETED'`, and `GT_CLASS.COMP_DATETIME` is stamped. `le_class_status_history.after_status = 'COMPLETED'` can be used as an audit trail. The finalize event is the **trigger**; the eligibility **comparison** uses the lesson's `scheduled_end_at`, not `COMP_DATETIME`, to avoid penalizing users when the tutor's paperwork lags past midnight.
- **Qualification check:** On lesson completion, the server should look up the **latest** active unawarded `purchase_bonus` record for that user (matching the Home card precedence rule), verify that the completed lesson belongs to that purchase's eligible first-lesson journey, and compare the lesson's `scheduled_end_at` against the purchase's stored `active_deadline`.
- **Award path for 무제한 (Unlimited) plans:** Reuse the existing backend expiry-extension methods to push the user's pack end date forward by the configured number of days. Recommended shape: the backend award service updates the active unlimited entitlement's final/expiry date and records the purchase bonus as awarded.
- **Award path for 라이트 루틴 (Light Routine) plans:** Two mutations in one atomic award: (1) expiry extension via the same pattern as 무제한, AND (2) bonus class credit via the existing BONUS subscribe/ticket infrastructure (same family that already handles bonus subscribe mappings / ticket issuance). Wrap both in a single transactional award path so partial failure reverts cleanly — a user should never end up with the extension applied but the class credit missing, or vice versa.
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

The post-purchase flow sends notifications at up to **seven moments** across the bonus window. **All notifications go out on both channels (push + alimtalk)** unless noted. There is no in-app celebration screen or modal in this scope — push and alimtalk are the entire out-of-app communication surface.

> **Source of truth for alimtalk template bodies, headlines, and button labels:** see **[PRD-alimtalk.md](./PRD-alimtalk.md)**. The Figma canvas `결제 후 첫 레슨 유도_260414` is the designer-owned master. The tables in this section cover timing, triggers, deep-link targets, and backend routing — but the exact copy lives in `PRD-alimtalk.md`.

**Variable conventions used below:**
- `{lessonDateLabel}` = user-facing localized lesson date label (e.g. `4월 17일(수)`)
- `{lessonTime}` = localized lesson start time (e.g. `오후 8:30`)
- `{deadlineDate}` = absolute localized deadline date (e.g. `4월 17일`)
- `{rewardDays}` = snapped day-extension amount for this purchase (e.g. `21`). Populated for both plan types.
- `{rewardCount}` = snapped bonus-class amount for this purchase (e.g. `5`). Populated **only for 라이트 루틴**; the value is not referenced in 무제한 templates at all
- `{deadlineDaysLeft}` = integer days remaining until the active deadline (snapshot-timezone-based); used by N5 only

| # | When it fires | Trigger condition | Purpose |
|---|---|---|---|
| **N1** | **On booking confirmation** — first lesson booked within the active bonus window | User taps "예약 확정" on Level+Time screen, OR creates a booking via the standard booking path with `lesson.scheduled_end_at <= active_deadline` | Confirm booking + reinforce that the bonus is earned by *completing* the class |
| **N2** | **On booking confirmation** — first lesson booked **outside** the active bonus window | Booking created via the standard booking path with `lesson.scheduled_end_at > active_deadline` | Confirm booking. Do not mention the bonus — the user is knowingly past the deadline |
| **N3** | **Morning before the initial-window deadline day** (purchase_day + 1), not yet booked | At 9am local on `purchase_day + 1`, no lesson has been booked yet AND the bonus has not been forfeited or awarded | Urgency push for the initial window — book and complete before tomorrow night |
| **N4** | **Bonus awarded** — first lesson completed within the active window | Tutor finalizes the class in `grape` AND `lesson.scheduled_end_at <= active_deadline` AND award has been applied | Celebrate the win and confirm what was added to the user's account |
| **N5** | **Deadline extended** — initial window expired without completion, system auto-extended to purchase_day + 7 | Triggered by the extension job at the moment the initial deadline passes, only if the bonus is not yet awarded and not yet forfeited | Inform the user of the new deadline and re-engage them with a fresh chance to earn the bonus |
| **N6** | **Morning before the extended-window deadline day** (purchase_day + 6), not yet booked | At 9am local on `purchase_day + 6`, scheduled at the moment N5 fires. Suppressed if already booked, awarded, or forfeited | Second-window D-1 urgency — framed as the last real chance |
| **N7** *(new)* | **6 hours before the extended deadline expires**, not yet booked | `extended_deadline.minusHours(6)` in the snapshotted timezone, scheduled at the moment N5 fires. Suppressed if already booked, awarded, or forfeited | Final last-chance nudge before the bonus is permanently forfeited |

### Relationship to existing alimtalk templates

`podo-backend` already sends two "first regular lesson booked" alimtalks at
`PodoScheduleServiceImplV2.book()` when `regularCnt == 0`:

- **`pd_reg_weeklyclass_2`** — first regular lesson booked on a count/weekly-class package
- **`pd_reg_infinity_2`** — first regular lesson booked on an unlimited (infinity) package

These are the **fallback** for the new N1. The new bonus-aware templates are **plan-split** (one for 무제한, one for 라이트 루틴) except N2, which is a single template for both plans:

| # | 무제한 (Unlimited) code | 라이트 루틴 (Count) code |
|---|---|---|
| N1 | `pd_bonus_reg_unlim` | `pd_bonus_reg_count` |
| N2 | `pd_reg_book_all_now` *(single template — both plans)* | `pd_reg_book_all_now` |
| N3 | `pd_bonus_unlim_bd1` | `pd_bonus_count_bd1` |
| N4 | `pd_bonus_noti_unlim` | `pd_bonus_noti_count` |
| N5 | `pd_bonus_unlim_bd4` | `pd_bonus_count_bd4` |
| N6 | `pd_bonus_2_unlim_bd1` | `pd_bonus_2_count_bd1` |
| N7 | `pd_bonus_2_unlim_h6` | `pd_bonus_2_count_h6` |

Routing rule at `PodoScheduleServiceImplV2.book()` (the `regularCnt == 0` branch):

| Situation | Alimtalk sent |
|---|---|
| First regular lesson booking AND `purchase_bonus` is active AND `scheduled_end_at <= active_deadline` | **New N1** — `pd_bonus_reg_unlim` or `pd_bonus_reg_count` by plan |
| First regular lesson booking AND `purchase_bonus` is active AND `scheduled_end_at > active_deadline` | **New N2** — `pd_reg_book_all_now` |
| First regular lesson booking AND NO `purchase_bonus` exists (user not eligible — repurchase, pre-launch account, feature flag off) | **Existing `pd_reg_weeklyclass_2` / `pd_reg_infinity_2`** — unchanged |

The decision point lives inside `PodoScheduleServiceImplV2.book()` at the template-selection branch: before picking a template, the service should check whether the user has an active unawarded `purchase_bonus` record and, if so, route to the new N1/N2 templates instead of the legacy ones. Push notifications for N1/N2 should be added alongside the alimtalk branch (the legacy branch does not currently send push).

### Deep link targets

Every push / alimtalk deep-links back into the app. Targets:

| Notification | Tap target | Rationale |
|---|---|---|
| **N1** | The **Booking Confirmed detail view** (or Home State B card if the detail view is not yet implemented as a standalone screen) | User already booked — show them the confirmation + prestudy CTA |
| **N2** | Same as N1 — the Booking detail view / Home State B card | Same reasoning; the bonus isn't mentioned so no need to route elsewhere |
| **N3** | **Home State A** — the not-booked Home card with the `예약하기` CTA and the bonus toast still visible | User has not booked; we want them to see the urgency copy and tap into the standard Home booking flow (Screen 2/3 cannot be re-entered after exit) |
| **N4** | **Home State B** (or the most recent lesson's detail view) | User just finished a lesson; let them see the reward reflected on Home and book their next lesson |
| **N5** | **Home State A** (not-booked) with the refreshed toast reflecting the new extended deadline | User hasn't booked and we just gave them a second chance; Home is the single place where the extended deadline is rendered in-app |
| **N6** | **Home State A** — same target as N3/N5, with the extended-window deadline in the toast | Same reasoning as N3 — push the user back into the standard Home booking flow |
| **N7** | **Home State A** — same as N6 | Last-chance nudge; keep the target consistent with N3/N5/N6 so the user always lands on the same booking surface |

Deep link behavior if the app is cold-started from the notification: the app boots to Home with the appropriate state (A or B) — it does not skip onboarding, auth, or the legacy Home entry logic. If auth is missing, the login screen intercepts and routes back to the intended target after sign-in.

### Alimtalk buttons

KakaoTalk alimtalk templates in podo-backend attach **one or two web-link buttons** at the bottom of the message body. N1 and N2 ship with **two** buttons (prestudy + study guide); N3–N7 each have **one** button pointing at Home. Each button is a pair of Mobile / PC URLs that reuse the existing **auth-wrapped redirect pattern** already populated by `PodoScheduleServiceImplV2.book()` — `{moHomeLink}` and `{pcHomeLink}` are computed by the backend exactly as they are for the legacy templates. Two new link variables are introduced for N1 / N2 to deep-link into prestudy:

| Variable | What it resolves to |
|---|---|
| `{moHomeLink}` / `{pcHomeLink}` | Existing — auth-wrapped redirect to Home (app picks State A or State B based on current booking state) |
| `{moPrestudyLink}` / `{pcPrestudyLink}` | **New** — auth-wrapped redirect to the Prestudy screen for the first-lesson `booking_id`. Only used on N1 and N2, which are the only post-booking notifications |

Alimtalk button spec per notification — all button labels below are pulled **verbatim from Figma** (see PRD-alimtalk.md):

| # | Button(s) | Mobile 링크 | PC 링크 | Resolves to |
|---|---|---|---|---|
| **N1** | `예습하러 가기` (primary) + `학습 가이드` (secondary) | `{moPrestudyLink}` / `{moHomeLink}` | `{pcPrestudyLink}` / `{pcHomeLink}` | Primary → Prestudy screen for the booked first lesson. Secondary → Home study-guide |
| **N2** | `예습하러 가기` + `학습 가이드` | Same as N1 | Same as N1 | Same targets as N1 — N2 is just N1 minus the bonus block |
| **N3** | `🔥일단 레슨 예약` | `{moHomeLink}` | `{pcHomeLink}` | Home State A — the not-booked Home card with the `예약하기` CTA |
| **N4** | `🎁혜택 확인하기` | `{moHomeLink}` | `{pcHomeLink}` | Home State B with the reward reflected in the pack / validity |
| **N5** | `🔥지금 첫 레슨 예약하기` | `{moHomeLink}` | `{pcHomeLink}` | Home State A with the refreshed toast showing the new extended deadline |
| **N6** | `🔥일단 레슨 예약` | `{moHomeLink}` | `{pcHomeLink}` | Home State A — same as N3 |
| **N7** | `🔥당장 레슨 예약` | `{moHomeLink}` | `{pcHomeLink}` | Home State A — last-chance target |

**Push notification deep links** follow the same destinations as the alimtalk buttons above, but the push payload carries a structured deep link (app scheme or universal link) rather than a web URL — the app resolves the target screen directly. Concretely: N1/N2 → booking detail overlay in Home State B; N3/N5/N6/N7 → Home State A; N4 → Home State B.

### Notification copy

**Canonical source:** **[PRD-alimtalk.md](./PRD-alimtalk.md)** — contains the exact alimtalk body, headline-card text, and buttons for all 13 template codes (7 notifications × 2 plan variants, minus the single-template N2) pulled verbatim from the Figma canvas `결제 후 첫 레슨 유도_260414`. The backend team should treat PRD-alimtalk.md as the source of truth when populating the `notification_message` DB rows.

The copy style follows podo's existing alimtalk conventions: emoji clusters at the top, `{studentName}님!` salutation, playful dot-separated emphasis like `시.작.`, `────────────` divider lines, `🔥 / ⏰ / ⭐ / 💚 / ⚠` accent marks, casual ending particles. N1 preserves the visual cadence of the legacy `pd_reg_weeklyclass_2` / `pd_reg_infinity_2` tone so it feels continuous with the template it replaces.

**Push notifications** (short device-lockscreen format) follow the same plan-split and window-state logic as the alimtalks; titles and bodies are one-liners carrying `{studentName}`, `{classDatetime}`, `{rewardDays}`, and (for 라이트 루틴) `{rewardCount}`. Push deep-link targets mirror the alimtalk button targets in the table above.

**Notes on each notification:**

- **N1 vs N2 split:** A post-purchase-flow booking always triggers N1 (the calendar is structurally capped inside the initial window). N2 is only possible via the standard booking path with a lesson end time past the active deadline. A user can never get both for the same booking.
- **N3 timing (initial window D-1):** N3 fires on the morning of `purchase_day + 1` at 9am local. Copy explicitly tells the user they have until "tomorrow night" to complete. Suppressed if already booked, awarded, or forfeited.
- **N6 timing (extended window D-1):** N6 fires on the morning of `purchase_day + 6` at 9am local — scheduled at the moment N5 fires. Copy language is intentionally stronger than N3 ("영영 사라져요") because this is the last full-day reminder. Suppressed if already booked, awarded, or forfeited.
- **N7 timing (extended window T-6):** N7 fires exactly 6 hours before the extended deadline expires — `extended_deadline.minusHours(6)` in the snapshotted timezone — scheduled at the same call site as N6. Purpose is a final last-chance nudge. Suppressed if already booked, awarded, or forfeited.
- **N4 idempotency:** N4 fires exactly once, tied to the same idempotency rule as the bonus award itself.
- **N5 idempotency:** N5 fires exactly once per purchase, tied to the extension job which is also one-shot. N6 and N7 are also one-shot (each has a unique `uniqueKey = "{userId}-{TEMPLATE_CODE}"` in the reserved-send queue).
- **Post-N4 silence:** Once N4 fires, no further bonus-related notifications are sent for this purchase (no N5, N6, or N7). Any pending scheduled sends must be cancelled via `disableFutureAlim` in the award path.
- **Post-booking silence:** As soon as the user books a qualifying lesson, N3 / N6 / N7 are cancelled for this purchase by adding their template codes to `AFTER_BOOK_DISABLE_TARGETS` in `PodoScheduleServiceImplV2.java:142` (see PRD-alimtalk.md §6).
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
| 1 | **Trial class recommendation** — the level recommended by the tutor in the user's most recent trial class for this language, read from `le_level_test.level` (see "Data Sources & Lesson Assignment Logic" below for the 1:1 mapping to `CLASS_LEVEL` and the trial-class skip-ahead rule) | Yes — "체험 레슨 튜터가 **{level}**을 추천했어요!" |
| 2 | **Onboarding data** — the level inferred from the user's onboarding answers. The onboarding level field is not yet deployed — this tier is currently a placeholder hook that always returns empty, and will become active once the onboarding feature ships | No banner |
| 3 | **Lowest level** — Start 1 for both EN and JP (resolves to `CLASS_LEVEL = 1, CLASS_WEEK = 1`), used only when neither tier 1 nor tier 2 has data | No banner |

Key behavior:
- The chain is evaluated **per language**. A double-pack user might get a tier-1 result for EN (trial taken in English) and a tier-2 result for JP (no JP trial, but onboarding signals).
- The recommendation banner only appears when tier 1 wins. Tiers 2 and 3 show the level card with no banner above it.
- Switching language on the Level+Time screen re-runs the chain for the newly selected language and clears the selected lesson date/time. The screen does **not** remember prior EN/JP selections when toggling back.

**Default language for double-pack:**
- With trial → the language of their most recent trial class
- Without trial → English

---

## Data Sources & Lesson Assignment Logic

This section supplements the Level Defaults chain above with the underlying data sources and the concrete starting-lesson (`CLASS_LEVEL`, `CLASS_WEEK`) that the backend hands to the booking flow. Any downstream feature consuming level-test data should follow these rules so that product UIs stay consistent with the legacy PDF reports.

### Trial-class results data source: `le_level_test`

Trial-class results live in **`le_level_test`** (GWATOP MySQL, Metabase collection "GWATOP / Le Level Test"). One row per completed trial class.

Key columns:

| Column | Meaning |
|---|---|
| `id` | Test ID |
| `created_at` | Submission timestamp |
| `student_id` | FK → `GT_USER.ID` |
| `language` | `EN` or `JP` |
| `level` | Canonical evaluated level (1–10) — use this as the numeric key |
| `level_name` | Korean nickname label (e.g. "갓 태어난 베이비", "아장아장 베이비") |
| `student_name`, `job`, `reason` | Student profile context |
| `url` | S3 URL to the generated PDF report |

**Access note:** `le_level_test` is **not** currently mirrored into the ClickHouse `podo_mysql` database. Until it is added to the CDC/materialized-view pipeline, queries must run against the source MySQL (GWATOP) or go through Metabase. Any service depending on this table should either (a) read MySQL directly, or (b) request that it be added to the ClickHouse mirror.

### Level → displayed "Recommended Curriculum" label (PDF generator)

The archived `podo-trial-pdf-generator` defines the canonical display rules. Any new surface that shows a recommended curriculum label MUST reproduce these rules exactly.

#### English label rule
Source: `d2_en_each_page.py:7–11`

Rule: `level ≤ 2 → "Start {level}"`, otherwise `"Lv.{level - 2}"`.

| `level` | Displayed label |
|---:|---|
| 1 | `Start 1` |
| 2 | `Start 2` |
| 3 | `Lv.1` |
| 4 | `Lv.2` |
| 5 | `Lv.3` |
| 6 | `Lv.4` |
| 7 | `Lv.5` |
| 8 | `Lv.6` |
| 9 | `Lv.7` |
| 10 | `Lv.8` |

#### Japanese label rule
Source: `d2_jp_each_page.py:6–12`, `d2_jp_each_page_beginner.py:5`

Rule: `"Lv.{min(level, 8)}"` — capped at 8.

| `level` | Displayed label |
|---:|---|
| 1 | `Lv.1` |
| 2 | `Lv.2` |
| 3 | `Lv.3` |
| 4 | `Lv.4` |
| 5 | `Lv.5` |
| 6 | `Lv.6` |
| 7 | `Lv.7` |
| 8 | `Lv.8` |
| 9 | `Lv.8` (capped) |
| 10 | `Lv.8` (capped) |

⚠ Levels 9 and 10 collapse to `Lv.8`. Analytics/segmentation should still use the raw `level` value; only the user-facing label is capped.

#### Korean nickname label (optional)
Already stored in `le_level_test.level_name`. Underlying mapping is in `functions.py:130–143` (EN) and `functions.py:160–173` (JP). Prefer the stored column over recomputing.

### Legacy Home-screen "Book Next Lesson" flow — hardcoded curriculum buckets

The legacy home-screen booking flow (`GET /api/v2/lecture/podo/getNextLectureList` → `bookingLesson(classId)` → `getBookingLectureInfo`) exposes **four** hardcoded curriculum-grade codes per language. These are the `classCourseGrade` values returned only for trial classes (`GC.CITY = 'PODO_TRIAL'`).

Source of truth: `podo-backend/.../LectureOnlineJpaRepository.java:181-196` (production SQL `CASE` expression). Localized display names are joined in via system code `{CLASS_TYPE}_{LANG_TYPE}_LEVEL` at `LectureQueryServiceImpl.java:1496-1497`.

#### EN — 4 codes: `B`, `C1`, `C2`, `D`

| classCourseGrade | `CLASS_LEVEL` | `CLASS_WEEK` | KR label (from `LevelUtils` doc) |
|---|---:|---:|---|
| `B`  | 3 | 1  | 초급 |
| `C1` | 4 | 1  | 중급 |
| `C2` | 5 | 10 | 중고급 |
| `D`  | 7 | 1  | 고급 |

#### JP — 4 codes: `A`, `B`, `C`, `D` (different letter set from EN!)

| classCourseGrade | `CLASS_LEVEL` | `CLASS_WEEK` |
|---|---:|---:|
| `A` | 1 | 1 |
| `B` | 1 or 2 | 4 or 1 |
| `C` | 3 or 4 | 1 |
| `D` | 5 or 8 | 1 |

JP uses the letter `A` where EN uses `B`, and collapses multiple `(CLASS_LEVEL, CLASS_WEEK)` tuples into the same grade letter.

#### `le_level_test.level` → legacy curriculum-grade mapping

`LevelUtils.testLevelToCourseLevel`:
- EN: `courseLevel = testLevel + 2`
- JP: `courseLevel = testLevel`

Applied to the SQL buckets above:

| `le_level_test.level` | EN courseLevel | EN grade | JP courseLevel | JP grade |
|---:|---:|---|---:|---|
| 1  | 3  | B  | 1 | A (week 1) / B (week 4) |
| 2  | 4  | C1 | 2 | B |
| 3  | 5  | C2 *(only if week=10)* | 3 | C |
| 4  | 6  | — (no bucket) | 4 | C |
| 5  | 7  | D  | 5 | D |
| 6  | 8  | — | 6 | — |
| 7  | 9  | — | 7 | — |
| 8  | 10 | — | 8 | D |
| 9  | 11 | — | 9 | — |
| 10 | 12 | — | 10 | — |

⚠ Many test-levels have **no matching trial curriculum** — the buckets fire only on specific `(CLASS_LEVEL, CLASS_WEEK)` tuples. For non-trial classes, `classCourseGrade` is empty.

#### Known discrepancy

`LevelUtils.java:30-72` (`getCourseLevelAndWeek`) documents JP grades as `B/C1/C2/D`, but the production SQL emits `A/B/C/D` for JP. **The SQL is authoritative.** New code should align with the SQL until the helper is reconciled.

### Level + Time screen — lesson assignment logic

Post-purchase, the user lands on the Level + Time Selection screen (Screen 3). The system must pick a **starting lesson** (a `(CLASS_LEVEL, CLASS_WEEK)` tuple from `GT_CLASS_COURSE`) that the user is then booked into via the existing booking flow.

#### Level source — priority order

This is the implementation of the Level Defaults chain above:

1. **`le_level_test`** — if a row exists for `(student_id, language)`, use `le_level_test.level` directly as the target `GT_CLASS_COURSE.CLASS_LEVEL`. No `+2` offset (the legacy `LevelUtils.testLevelToCourseLevel` EN offset does **not** apply here; the new path maps 1:1).
2. **Onboarding self-reported level** — placeholder. The onboarding level field is not yet deployed. Leave a clearly marked hook (e.g. `getOnboardingLevel(userId) → Optional<Integer>`) that currently always returns empty. When the onboarding feature ships, this slot takes over as the fallback.
3. **Default** — `CLASS_LEVEL = 1, CLASS_WEEK = 1` (first lesson of the first level).

#### Starting lesson rule

Let `L` = resolved level (1–10). The default starting lesson is `(CLASS_LEVEL=L, CLASS_WEEK=1)` — the first lesson of level `L` — for **both** EN and JP.

This gives 10 canonical starting lessons per language. The PDF-label nomenclature is informational only; e.g. for EN, `L=1` is labelled `Start 1` and `L=3` is labelled `Lv.1`, but the backend still uses `CLASS_LEVEL=1` and `CLASS_LEVEL=3` respectively — the 1:1 mapping from `le_level_test.level` to `CLASS_LEVEL` is what matters.

#### Trial-class skip-ahead rule

If the user completed a trial class (i.e. an `le_level_test` row exists for `(student_id, language)`), the trial already consumed one specific lesson. To avoid re-serving it, start one lesson later **within the same level**:

Let `(L_trial, W_trial)` = the `(CLASS_LEVEL, CLASS_WEEK)` tuple of the trial class. Start at `(L_trial, W_trial + 1)`, **with one exception**:

**Edge case: EN C2 (level 5, week 10)**

EN trial grade `C2` maps to `(CLASS_LEVEL=5, CLASS_WEEK=10)`. This is a late-level placement probe, not the top of a progression — the student has not seen weeks 1–9. Therefore **override the "next" rule**: start at `(CLASS_LEVEL=5, CLASS_WEEK=1)` (first lesson of the same level).

This is the only known exception; all other trial grades map to `CLASS_WEEK=1` or `CLASS_WEEK=4`, where `W+1` is the natural next lesson.

#### Resolution pseudocode

```text
resolveStartingLesson(userId, language):
    levelTest = findLevelTest(userId, language)   // from le_level_test
    if levelTest exists:
        L = levelTest.level                        // 1..10
        (L_trial, W_trial) = lookupTrialClassTuple(language, L)
        if (language == "EN" && L_trial == 5 && W_trial == 10):
            return (5, 1)                          // EN C2 edge case
        if (L_trial, W_trial) exists:
            return (L_trial, W_trial + 1)          // skip past the trial
        return (L, 1)                              // no trial tuple; default to first week of L

    onboardingLevel = getOnboardingLevel(userId)   // placeholder, returns empty today
    if onboardingLevel exists:
        return (onboardingLevel, 1)

    return (1, 1)                                  // global default
```

`lookupTrialClassTuple` mirrors the SQL table in `LectureOnlineJpaRepository.java:183-193`:

| Language | Test level | (CLASS_LEVEL, CLASS_WEEK) |
|---|---:|---|
| EN | 1 | (3, 1) |
| EN | 2 | (4, 1) |
| EN | 3 | (5, 10) ⚠ edge case |
| EN | 5 | (7, 1) |
| JP | 1 | (1, 1) or (1, 4) |
| JP | 2 | (2, 1) |
| JP | 3–4 | (3, 1) / (4, 1) |
| JP | 5, 8 | (5, 1) / (8, 1) |

Levels not listed above have no known trial-tuple and should fall through to `(L, 1)`.

#### Constraints & validation

- Filter `GT_CLASS_COURSE` by `USE_YN = 'Y'`, `CLASS_TYPE` matching the user's subscription, and integer `CLASS_LEVEL ∈ {1..10}`. Sub-level floats (e.g. 4.1, 4.5) must be excluded from this path.
- If the resolved `(CLASS_LEVEL, CLASS_WEEK)` tuple doesn't exist in `GT_CLASS_COURSE` for the user's `CLASS_TYPE`, fall back to `(1, 1)`.
- Hand the resolved tuple's `ID` (or the corresponding `GT_CLASS.ID`) into the existing booking flow as `classId` — no changes to `getBookingLectureInfo` required.

### Implementation guidelines

1. **Canonical numeric key:** always read `le_level_test.level` (1–10). Do not recompute from raw interview answers.
2. **PDF-report label:** apply the language-specific rule above. Do not mix the Korean nickname and the `Start N` / `Lv.N` labels in the same slot.
3. **Home-screen curriculum grade (legacy):** use `classCourseGrade` from `getNextLectureList`. Do not reconstruct it on the client — the bucket rules are non-obvious and differ per language.
4. **New Level + Time screen:** use the direct 1:1 mapping from `le_level_test.level` to `GT_CLASS_COURSE.CLASS_LEVEL`. Do **not** pipe through the legacy `+2` EN offset or the 4-bucket grade system — those are separate concerns.
5. **Analytics:** bucket by raw `le_level_test.level` (1–10) **and** by `classCourseGrade` separately. They do not map 1:1.
6. **Onboarding hook:** land the placeholder function signature now so the caller site is stable. Swap the body when the onboarding field ships.

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
| Persistent bonus toast (Home screen only, above GNB) | Translucent near-black `rgba(28, 28, 28, 0.72)` with backdrop blur, white text, deadline-date accent in app primary green `#B5FD4C` |

### Shadow & blur tokens (flow-specific)

These are specific enough to this flow that they're called out here rather than buried in the global design system:

| Surface | Drop shadow | Backdrop blur |
|---|---|---|
| Incentive info card (Screen 2, pinned above CTA) | `0 4px 12px rgba(15, 23, 42, 0.08)` — soft neutral, lifts the card off the confetti background | — |
| Primary CTA "첫 수업 예약하기" (Screen 2) | `0 8px 20px rgba(97, 132, 255, 0.28)` — blue-tinted to match the button fill and the `#6184FF` accent from the incentive card | — |
| Exit Reminder Bottom Sheet primary CTA "지금 예약하기" | `0 8px 20px rgba(106, 190, 54, 0.28)` — green-tinted variant, same formula as the Screen 2 CTA but keyed to the lime green `#6ABE36` fill | — |
| Home persistent bonus toast | `0 8px 24px rgba(0, 0, 0, 0.24)` — wider and softer than the CTA shadow so it reads as a floating translucent layer | **`blur(16px) saturate(140%)`** applied to the area behind the pill so GNB icons and Home content bleed through visibly blurred |

The toast is the **only surface in this flow that uses backdrop blur**. The blur is essential — without it the translucent pill reads as a flat gray block; with it the pill feels like a real floating notification layer above the GNB.

All other colors (selection outlines, level/time selected states, disabled states) and every other shadow follows the global tokens.

---

## Analytics

This flow is a funnel, so every screen and every meaningful interaction must be tracked. We reuse the existing event-tracking utility in `podo-app` (`@shared/analytics` — the `track()` function in `packages/analytics/src/core/client.ts`, which writes to ClickHouse via the standard event transport). All events below follow the existing snake_case convention and reuse the existing base event names (`page_viewed`, `button_clicked`, `popup_viewed`) where they apply, adding only a `location` / `name` scoped to this flow.

### Screen / page-view events

Emitted once on mount of each screen in the funnel.

| Event name | Props |
|---|---|
| `page_viewed` | `{ name: 'post_purchase_celebration', purchase_id, plan_type, plan_duration_months, entry_variant: 'first_real' \| 'other' }` |
| `page_viewed` | `{ name: 'post_purchase_encouragement', purchase_id, plan_type, plan_duration_months, reward_type, reward_amount, deadline_phase: 'initial' \| 'extended' }` |
| `page_viewed` | `{ name: 'post_purchase_level_time', purchase_id, plan_type, language, selected_level, level_source: 'trial' \| 'onboarding' \| 'fallback', banner_shown: boolean }` |
| `page_viewed` | `{ name: 'post_purchase_booking_confirmed', purchase_id, plan_type, booking_id, in_window: boolean }` |

### Bottom-sheet / modal-view events

| Event name | Props |
|---|---|
| `popup_viewed` | `{ name: 'post_purchase_exit_reminder', purchase_id, plan_type, reward_type, reward_amount }` |
| `popup_viewed` | `{ name: 'post_purchase_level_change_sheet', purchase_id, language, current_level }` |
| `popup_viewed` | `{ name: 'post_purchase_calendar_sheet', purchase_id, language, current_level }` |
| `popup_viewed` | `{ name: 'post_purchase_reschedule_warning', purchase_id, attempted_slot_scheduled_end_at, active_deadline }` — fires when reschedule would push the booking outside the deadline |

### Button / interaction events

| Event name | Props |
|---|---|
| `button_clicked` | `{ name: 'encouragement_primary_cta', location: 'post_purchase_encouragement', purchase_id }` — "첫 수업 예약하기" |
| `button_clicked` | `{ name: 'encouragement_exit_link', location: 'post_purchase_encouragement', purchase_id }` — "혜택 포기하고 나가기" |
| `button_clicked` | `{ name: 'exit_reminder_primary_cta', location: 'post_purchase_exit_reminder', purchase_id }` — "지금 예약하기" green button |
| `button_clicked` | `{ name: 'exit_reminder_forfeit', location: 'post_purchase_exit_reminder', purchase_id }` — "혜택 포기하고 나가기" (actual exit) |
| `button_clicked` | `{ name: 'level_change_open', location: 'post_purchase_level_time', purchase_id }` |
| `button_clicked` | `{ name: 'level_change_selected', location: 'post_purchase_level_change_sheet', purchase_id, from_level, to_level }` |
| `button_clicked` | `{ name: 'language_toggle', location: 'post_purchase_level_time', purchase_id, from_language, to_language }` |
| `button_clicked` | `{ name: 'recommended_slot_selected', location: 'post_purchase_level_time', purchase_id, slot_scheduled_start_at, slot_index }` (index 0-5) |
| `button_clicked` | `{ name: 'see_other_times', location: 'post_purchase_level_time', purchase_id }` — "다른 시간 보기" |
| `button_clicked` | `{ name: 'calendar_time_selected', location: 'post_purchase_calendar_sheet', purchase_id, slot_scheduled_start_at }` |
| `button_clicked` | `{ name: 'calendar_date_changed', location: 'post_purchase_calendar_sheet', purchase_id, selected_date }` |
| `button_clicked` | `{ name: 'booking_confirmed', location: 'post_purchase_level_time', purchase_id, booking_id, slot_scheduled_end_at, in_window: boolean, level, language }` |
| `button_clicked` | `{ name: 'prestudy_cta', location: 'post_purchase_booking_confirmed', purchase_id, booking_id }` — "예습하기" |
| `button_clicked` | `{ name: 'home_exit_link', location: 'post_purchase_booking_confirmed', purchase_id, booking_id }` — "홈으로" |

### Home-surface events

| Event name | Props |
|---|---|
| `popup_viewed` | `{ name: 'home_bonus_toast', purchase_id, deadline_phase, deadline_date }` — fired once per Home mount per session while the toast is visible |
| `button_clicked` | `{ name: 'home_bonus_toast_dismiss', purchase_id, deadline_phase }` — X-tap |
| `button_clicked` | `{ name: 'home_state_a_book', purchase_id }` — 예약하기 on State A card |
| `button_clicked` | `{ name: 'home_state_a_browse', purchase_id }` — 다른 레슨보기 on State A card |

### Backend / lifecycle events

These are server-side events emitted to the same ClickHouse pipeline by `podo-backend` whenever the lifecycle transitions — they are not tied to a UI action, but they are the metrics backbone.

| Event name | Props |
|---|---|
| `purchase_bonus_created` | `{ purchase_id, user_id, plan_type, plan_duration_months, reward_type, reward_amount, initial_deadline_at, timezone_snapshot, source: 'purchase_flow' \| 'admin_grant' }` |
| `purchase_bonus_deadline_extended` | `{ purchase_id, user_id, extended_deadline_at }` |
| `purchase_bonus_awarded` | `{ purchase_id, user_id, reward_type, reward_amount, deadline_phase, time_from_purchase_minutes, first_lesson_scheduled_end_at }` |
| `purchase_bonus_forfeited` | `{ purchase_id, user_id, final_deadline_at, reason: 'extended_window_expired' }` |
| `notification_sent` | `{ purchase_id, user_id, notification_id: 'N1' \| 'N2' \| 'N3' \| 'N4' \| 'N5' \| 'N6' \| 'N7', channel: 'push' \| 'alimtalk', template_code }` — `template_code` is the lowercase Kakao template code (e.g. `pd_bonus_reg_unlim`, `pd_bonus_2_count_h6`) |

### Funnel queries the team should build on top of these events

- Celebration → Encouragement → Level+Time → Booking Confirmed conversion rate per step
- Exit Reminder conversion rate (modal opened → `exit_reminder_primary_cta` vs `exit_reminder_forfeit`) — this is the single biggest lever for whether the "혜택 포기하고 나가기" dark pattern is worth keeping
- Home State A CTR on `예약하기` by deadline phase (initial vs extended)
- Bonus-award rate within 72h of purchase (ties to the north-star metric below)
- Home bonus toast dismiss rate vs conversion correlation

---

## Success Metrics

### North-star metric

**Book-rate within 72 hours of purchase** — the percentage of eligible first-real purchases where the user books their first regular lesson within 72 hours of the purchase timestamp. This is the metric the entire post-purchase funnel is optimized against. 72h is chosen because it matches the outer bound of the initial bonus window; a booking made after 72h is still valuable but falls outside the "immediate booking" hypothesis this flow is testing.

Query: `count(distinct booking) where booking.created_at - purchase.created_at <= 72h / count(distinct eligible_purchase)`, scoped to purchases with `source = 'purchase_flow'`.

### Guardrail metric

**Refund-rate within 72 hours of purchase** — the percentage of eligible first-real purchases that are refunded within 72 hours of the purchase timestamp. This is the primary guardrail: if the aggressive dark-pattern funnel produces regret-refunds, we will see it here. If refund-rate within 72h rises by more than +X% (X to be set at launch from a 2-week pre-launch baseline), the feature is rolled back via the global kill switch while the team investigates.

Query: `count(distinct refunded_purchase) where refund.created_at - purchase.created_at <= 72h / count(distinct eligible_purchase)`.

### Secondary metrics (not gates, tracked for context)

- Bonus-award rate within the initial window (purchase_day + 2)
- Bonus-award rate within the extended window (purchase_day + 7)
- N3 CTR and resulting book-rate lift
- Post-purchase funnel step-conversion rates (see Analytics section above)
- `exit_reminder_primary_cta` / `exit_reminder_forfeit` split on the Exit Reminder Bottom Sheet
- Prestudy-start rate from the Booking Confirmed screen's "예습하기" CTA
