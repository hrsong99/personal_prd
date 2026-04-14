# Post-Purchase First Lesson Booking Flow — ASCII Wireframes

Visual reference for every screen in the flow. Read top-to-bottom alongside the
PRD, or skim the Flow Diagram at the bottom to see how everything connects.

The flow has **four screens**: Celebration → Booking Encouragement → Level + Time
Selection → Booking Confirmed. Plus three bottom sheets (Exit Reminder, Level
Change, Calendar) and two Home states (Not Booked, Booked).

> **Funnel eligibility (read this first).** The full funnel only runs on a user's
> **first real paid purchase**. Trial classes don't count, and neither do
> repurchases, upgrades, renewals, or plan switches. Other purchases see
> **Screen 1 only, with a manual 확인 button** — no Encouragement, no Level+Time,
> no bonus toast, no N1–N5 notifications. See "Screen 1 — Variant B" below.
>
> Admin re-grant (for refund-to-switch edge cases) does NOT replay the funnel
> screens; it only activates the Home toast + notifications against a fresh
> deadline.

---

## Screen 1 — Purchase Celebration

Two variants depending on whether the user is eligible for the full funnel.

### Variant A — First real purchase (auto-advance, no CTA)

```
┌─────────────────────────────────┐
│  9:27                ▪▪▪ ▿ ▭   │ ← status bar
│                                 │
│                                 │
│                                 │
│                                 │
│                                 │
│                                 │
│              ┌─────┐            │
│             ╱       ╲           │
│            │   ✓     │          │ ← bright green circle
│             ╲       ╱              w/ dark checkmark
│              └─────┘            │
│                                 │
│       구매가 완료되었어요!       │ ← bold title
│                                 │
│      영어 무제한 레슨권 12개월   │ ← gray subtitle (plan name,
│                                 │    dynamically populated)
│                                 │
│                                 │
│                                 │
│                                 │
│              ▔▔▔▔▔              │ ← home indicator
└─────────────────────────────────┘
        ↓ 2–3 seconds, no user input
```

- White background, no buttons, no incentive card, no back arrow
- User cannot interact — purely a transient acknowledgment
- Auto-advances to **Screen 2: Booking Encouragement**

### Variant B — Other purchases (manual 확인, routes to Home)

Shown on repurchases, upgrades, renewals, plan switches, or any non-first-real
purchase. Same visuals as Variant A, but with a single bottom CTA and no
auto-advance.

```
┌─────────────────────────────────┐
│  9:27                ▪▪▪ ▿ ▭   │
│                                 │
│                                 │
│                                 │
│                                 │
│              ┌─────┐            │
│             ╱       ╲           │
│            │   ✓     │          │ ← same green check circle
│             ╲       ╱              as Variant A
│              └─────┘            │
│                                 │
│       구매가 완료되었어요!       │
│                                 │
│      영어 무제한 레슨권 6개월    │ ← plan name
│                                 │
│                                 │
│                                 │
├─────────────────────────────────┤
│  ┌───────────────────────────┐  │
│  │          확인             │  │ ← primary GREEN button
│  └───────────────────────────┘  │   → Home
│                                 │
│              ▔▔▔▔▔              │
└─────────────────────────────────┘
```

- No auto-advance, no Booking Encouragement, no Exit Reminder modal
- No `purchase_bonus` is created, no Home toast, no N1–N5
- Tapping "확인" routes the user straight to Home

---

## Screen 2 — Booking Encouragement (the "main screen")

The funnel point. Single-action screen that pushes the user to tap the booking
CTA. Does NOT show levels or time slots — those live on Screen 3.

```
┌─────────────────────────────────┐
│  9:27                ▪▪▪ ▿ ▭   │
│   🎉    🎊         🎉    🎊    │ ← confetti animation
│       🎊        🎉              │   falling continuously
│                                 │
│  🎉             🎊      🎉      │
│            ┌────┐               │
│           /  ∞∞ \               │ ← cheerful Podo mascot
│          | (^_^) |              │   holding a wrapped
│           \ 🎁  /               │   gift box
│            ╲___╱                │
│   🎊      [legs]      🎊        │
│                                 │
│       첫 레슨 예약해봐요!       │ ← bold title
│                                 │
│  🎉                       🎊    │
│                                 │
├─────────────────────────────────┤ ← fixed bottom area
│  ┌───────────────────────────┐  │
│  │ 🎁    21일 연장 혜택     │  │ ← incentive card
│  │     지금 바로 첫 레슨하면 │  │   (blue, with downward
│  │  이용 기간을 연장해 드려요│  │    speech tail)
│  └─────────────▽─────────────┘  │
│  ┌───────────────────────────┐  │
│  │     첫 수업 예약하기      │  │ ← primary CTA
│  └───────────────────────────┘  │   (blue/violet, always
│                                 │    enabled)
│       혜택 포기하고 나가기      │ ← weak gray text link
│              ▔▔▔▔▔              │   → Exit Reminder Sheet
└─────────────────────────────────┘
```

- **No back arrow** — the only way out is the weak gray link
- "첫 수업 예약하기" is **always enabled** (no time selection happens here)
- Tapping it → **Screen 3: Level + Time Selection**
- Tapping "혜택 포기하고 나가기" → **Exit Reminder Bottom Sheet**
- Standard package copy note: the incentive card uses class-count wording instead
  (e.g. `4회 추가 지급 혜택` / `추가 레슨권 드려요`)

---

## Exit Reminder Bottom Sheet

Triggered ONLY by tapping "혜택 포기하고 나가기" on the Booking Encouragement
screen.

```
┌─────────────────────────────────┐
│   🎉        🎊         🎉       │ ← confetti & cheerful
│                                 │   mascot dimmed
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │   behind the dark
│                                 │   backdrop
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│┌───────────────────────────────┐│
││            ▬▬▬                ││ ← drag handle
││                               ││
││           ┌────┐              ││
││          /  ∞∞  \             ││ ← SAD Podo mascot
││         | (T_T)  |            ││   (teary infinity-eye,
││          \ 🎁  /              ││    fallen gift box)
││           ╲___╱               ││
││                               ││
││        정말 나가시겠어요?     ││ ← bold title
││                               ││
││  지금 나가면 이 혜택을        ││ ← gray subtitle
││  놓칠 수 있어요.             ││   (intentionally implies
││                               ││    forfeiture — but bonus
││                               ││    actually stays active)
││                               ││
││  ┌─────────────────────────┐  ││
││  │     지금 예약하기       │  ││ ← primary GREEN button
││  └─────────────────────────┘  ││   → Screen 3: Level+Time
││                               ││     (forward navigation,
││                               ││      NOT back to Screen 2)
││     혜택 포기하고 나가기      ││
││            ▔▔▔▔▔              ││ ← weak gray link
│└───────────────────────────────┘│   → Home (bonus still active)
└─────────────────────────────────┘
```

⚠️ **The "혜택을 놓칠 수 있어요" copy is a retention nudge, not the rule.**
The user does NOT actually forfeit the bonus by tapping the gray link.
The deadline keeps running, the Home toast still appears, the auto-extension
still fires if needed, and standard booking still earns the bonus.

Plan-specific copy note:
- Unlimited plan: `지금 나가면 이 혜택을 놓칠 수 있어요.`
- Count plan: `지금 나가면 추가 레슨권 혜택을 놓칠 수 있어요.`

**Action mapping:**
- "지금 예약하기" (green) → forward to Screen 3 (gets the user past the funnel)
- "혜택 포기하고 나가기" (gray link) → exits to Home (bonus still active)
- Tap outside / drag down → close sheet, stay on Screen 2

---

## Screen 3 — Level + Time Selection

The booking interaction screen. Reached from Screen 2 ("첫 수업 예약하기") OR
from the Exit Reminder Bottom Sheet ("지금 예약하기").

```
┌─────────────────────────────────┐
│  ←                              │ ← back arrow → Screen 2
├─────────────────────────────────┤   (Booking Encouragement)
│                                 │
│  ┌────────────┬─────────────┐   │ ← double-pack only:
│  │   영어     │   일본어    │   │   language toggle
│  └────────────┴─────────────┘   │   (omitted for single-pack)
│                                 │
│  레슨 선택                      │
│  ┌─────────────────────────┐    │
│  │ ▓▓ Start 1          ›   │    │ ← level card (tap to change)
│  │    기초 영어의 첫걸음   │    │
│  └─────────────────────────┘    │
│                                 │
│  ┌─────────────────────────┐    │ ← banner only if level came
│  │ 체험 레슨 튜터가         │    │   from trial recommendation
│  │ Start 1 을 추천했어요!   │    │
│  │ 다른 레벨도 선택할 수    │    │
│  │ 있어요.                  │    │
│  └─────────────────────────┘    │
│                                 │
│  추천 시간                      │
│  레슨 일정을 선택해 주세요.     │
│  ┌──────────┐ ┌──────────┐      │
│  │ 오늘     │ │ 오늘     │      │ ← next 6 closest
│  │ 21:00    │ │ 21:30    │      │   available slots,
│  └──────────┘ └──────────┘      │   chronological across
│  ┌──────────┐ ┌──────────┐      │   the 3-day window
│  │ 내일     │ │ 내일     │      │
│  │ 10:00    │ │ 11:00    │      │
│  └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐      │
│  │4월 21일  │ │4월 21일  │      │ ← day-after-tomorrow
│  │ 06:30    │ │ 07:00    │      │   slots use absolute
│  └──────────┘ └──────────┘      │   calendar label
│                                 │
│       [ 다른 시간 보기 ]        │ ← ghost button
│                                 │   → Calendar Bottom Sheet
│                                 │
├─────────────────────────────────┤
│  ┌───────────────────────────┐  │
│  │       예약 확정           │  │ ← primary green CTA
│  └───────────────────────────┘  │   DISABLED (gray) until
│                                 │    a time slot is picked
└─────────────────────────────────┘
```

- **No incentive card here** (it lives on Screen 2)
- **No exit link here** (the only way "out" is the back arrow → Screen 2)
- "예약 확정" is **disabled** until a time slot is selected
- The default grid is the **next 6 closest available times** for the currently
  selected language + level, ordered chronologically across the 3-day window
- **Slot labels:** today → `오늘 HH:MM`, tomorrow → `내일 HH:MM`, day-after-tomorrow → absolute calendar label (e.g. `4월 21일 06:30`)
- **Grid padding:** if today has fewer than 6 remaining slots (late-night purchase + 2h booking cutoff), the grid continues filling from tomorrow, then from the day after, until 6 slots are shown or the 3-day window is exhausted. If fewer than 6 are available in the entire window, render only what's there — no placeholders
- Switching language or changing level clears the selected date/time and recalculates the grid from scratch
- Tapping "예약 확정" with a time selected → **Screen 4: Booking Confirmed**

### Screen 3 alternate state — after picking a custom time via the calendar

When the user picks a time via the Calendar Bottom Sheet, the entire "추천 시간"
section (header, subtitle, 6-slot grid, "다른 시간 보기" button) is replaced
with a compact "선택된 레슨 일정" section:

```
┌─────────────────────────────────┐
│  ←                              │
├─────────────────────────────────┤
│                                 │
│  레슨 선택                      │
│  ┌─────────────────────────┐    │
│  │ ▓▓ Start 1          ›   │    │
│  └─────────────────────────┘    │
│                                 │
│  선택된 레슨 일정               │ ← compact header
│  ┌─────────────────────────┐    │
│  │      4월 21일 06:30     │    │ ← selected time pill
│  └─────────────────────────┘    │   (light green outline)
│  ┌─────────────────────────┐    │
│  │       날짜 변경         │    │ ← ghost button
│  └─────────────────────────┘    │   → reopens Calendar
│                                 │     Bottom Sheet
│                                 │
│                                 │
├─────────────────────────────────┤
│  ┌───────────────────────────┐  │
│  │       예약 확정           │  │ ← now ENABLED
│  └───────────────────────────┘  │   (time is selected)
└─────────────────────────────────┘
```

- The recommended-slots grid is gone — there is no way to revert to it
  without going back through the calendar
- "예약 확정" becomes enabled (green) once a time is in the pill
- Tapping "날짜 변경" reopens the Calendar Bottom Sheet

---

## Level Change Bottom Sheet

Triggered by tapping the level card on Screen 3.

```
┌─────────────────────────────────┐
│                                 │
│  (dimmed Level+Time behind)     │
│                                 │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│┌───────────────────────────────┐│
││            ▬▬▬                ││ ← drag handle
││                               ││
││  레벨 변경                    ││
││                               ││
││  ┌─────────────────────────┐  ││
││  │ ▓▓ Start 1           ✓  │  ││ ← currently selected
││  │    기초 영어의 첫걸음   │  ││   (green check)
││  └─────────────────────────┘  ││
││  ┌─────────────────────────┐  ││
││  │ ▓▓ Level 2              │  ││
││  │    일상 표현 익히기     │  ││
││  └─────────────────────────┘  ││
││  ┌─────────────────────────┐  ││
││  │ ▓▓ Level 3              │  ││
││  │    중급 회화 진입       │  ││
││  └─────────────────────────┘  ││
││  ┌─────────────────────────┐  ││
││  │ ▓▓ Level 4              │  ││
││  │    유창한 대화          │  ││
││  └─────────────────────────┘  ││
│└───────────────────────────────┘│
└─────────────────────────────────┘
```

- List of level cards (varies per language: EN or JP)
- Tapping a level → selects it, closes the sheet, updates Screen 3
- Tap outside / drag down → close without changes

---

## Calendar Bottom Sheet

Triggered by "다른 시간 보기" on Screen 3.

```
┌─────────────────────────────────┐
│                                 │
│  (dimmed Level+Time behind)     │
│                                 │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │
│┌───────────────────────────────┐│
││            ▬▬▬                ││ ← drag handle
││                               ││
││  레슨 일정을 선택해주세요     ││
││                               ││
││  ┌────┐ ┌────┐ ┌────┐         ││
││  │오늘│ │내일│ │수요│         ││ ← 3-day cap:
││  │ 15 │ │ 16 │ │ 17 │         ││   purchase_day +0/+1/+2
││  └────┘ └────┘ └────┘         ││
││                               ││
││  예약 가능 시간   ● 예약 마감 ││
││                               ││
││  ── AM ──                     ││
││  ┌─────┐ ┌─────┐ ┌─────┐      ││
││  │09:00│ │09:30│ │10:00│      ││
││  └─────┘ └─────┘ └─────┘      ││
││  ┌─────┐ ┌─────┐ ┌─────┐      ││
││  │10:30│ │ ─── │ │11:30│      ││ ← grayed = unavailable
││  └─────┘ └─────┘ └─────┘      ││
││                               ││
││  ── PM ──                     ││
││  ┌─────┐ ┌─────┐ ┌─────┐      ││
││  │14:00│ │14:30│ │ ─── │      ││
││  └─────┘ └─────┘ └─────┘      ││
││  ┌─────┐ ┌─────┐ ┌─────┐      ││
││  │19:00│ │19:30│ │20:00│      ││
││  └─────┘ └─────┘ └─────┘      ││
││                               ││
││  ┌─────────────────────────┐  ││
││  │          확인           │  ││ ← primary green
││  └─────────────────────────┘  ││   (disabled until pick)
│└───────────────────────────────┘│
└─────────────────────────────────┘
```

- Date selector capped at 3 days (today + tomorrow + day-after)
- Today's past times and near-term times inside the existing 2-hour cutoff are hidden entirely
- 3-column grids, separated AM / PM
- Tap "확인" → closes sheet, "선택된 레슨 일정" pill replaces "추천 시간" on Screen 3

---

## Screen 4 — Booking Confirmed

Reached after tapping "예약 확정" with a time selected on Screen 3.

```
┌─────────────────────────────────┐
│  9:27                ▪▪▪ ▿ ▭   │
│                                 │
│                                 │
│            ┌─────┐              │
│           /  ∞∞  \              │ ← Podo study mascot
│          | (study) |            │   (infinity-eye, holding
│           \ 📋  /               │    a clipboard)
│            ╲___╱                │
│            [legs]               │
│                                 │
│       레슨이 예약됐어요!        │ ← bold title
│                                 │
│  교재로 미리 예습하면           │ ← gray subtitle
│  편하게 대화할 수 있어요        │
│                                 │
│  ┌───────────────────────────┐  │
│  │  2월 28일(수) 16:30  ┌──┐ │  │ ← date+time (coral)
│  │                      │D-2│ │  │   + D-day badge (blue)
│  │                      └──┘ │  │
│  │       영어 Level 1        │  │ ← language + level only
│  └───────────────────────────┘  │   (no tutor, no topic)
│                                 │
│                                 │
│                                 │
├─────────────────────────────────┤
│  ┌───────────────────────────┐  │
│  │         예습하기          │  │ ← primary green button
│  └───────────────────────────┘  │   → Pre-Study screen
│                                 │
│              홈으로             │ ← weak gray text link
│              ▔▔▔▔▔              │   → Home screen
└─────────────────────────────────┘
```

- **Podo study mascot** (clipboard pose) at the top — different from the
  cheerful gift-holding mascot on Screen 2
- Booking card has just **two rows**: date+time with inline D-day badge,
  and the level (e.g. "영어 Level 1"). No tutor name shown.
- Bottom CTAs are **stacked vertically** — primary green "예습하기" with
  a weak gray "홈으로" link below, intentionally pushing the user toward
  pre-study as the high-value next step

---

## Home — State A: Not Booked

User's Home screen if they haven't yet booked their first lesson.

```
┌─────────────────────────────────┐
│  포도∞스피킹       [수강권 구매]│ ← header
│                                 │
│  ┌───────────────────────────┐  │
│  │     🌱 (mascot active)    │  │ ← hero illustration
│  │                           │  │
│  │  John님, 안녕하세요!      │  │
│  │  미루지 말아요!           │  │
│  │  지금 바로 레슨 예약하러  │  │
│  │  갈까요?                  │  │
│  │                           │  │
│  │  ┌─────────────────────┐  │  │
│  │  │ ▓▓ Start 1          │  │  │ ← level preview
│  │  │    2. 기초 영어의   │  │  │   (resolved via
│  │  │       첫걸음...     │  │  │    3-tier chain)
│  │  └─────────────────────┘  │  │
│  │                           │  │
│  │  ┌──────────┬──────────┐  │  │
│  │  │다른 레슨보│ 예약하기 │  │  │ ← ghost / primary
│  │  │기        │          │  │  │   → Lesson tab
│  │  └──────────┴──────────┘  │  │   → existing standard Home booking flow
│  └───────────────────────────┘  │
│                                 │
│  (other Home content...)        │
│                                 │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 🎁 4월 17일까지 첫 레슨 완료│ │ ← persistent toast
│ │    하면                  ✕  │ │   • dark pill
│ │  이용 기간 21일 연장해 드려요│ │   • gift icon
│ └─────────────────────────────┘ │   • date in coral
├─────────────────────────────────┤   • two-line copy
│  홈   레슨   예약  AI학습  마이 │   • X = dismiss
└─────────────────────────────────┘   • body NOT clickable
```

**Toast lifecycle:**
- Appears immediately after purchase
- Persists across sessions until: user X-dismisses, deadline expires, OR
  bonus is awarded
- **Re-appears with new deadline** if the deadline auto-extends
  (even if previously dismissed)
- **Re-appears when the user reschedules the booking outside the active
  window** (even if previously dismissed) so they can see the deadline
  conflict — paired with a one-time warning sheet at the reschedule step
  (`이 시간으로 옮기면 혜택을 받을 수 없어요`)
- Body is NOT tappable — only the X button is interactive
- **Multi-purchase edge case** (admin re-grant on top of a first purchase):
  only one toast shows at a time, following the **latest** `purchase_bonus`
  by `created_at`

**Cancel semantics:**
- If the user cancels their booked first lesson entirely (without rebooking),
  Home reverts to **State A** and the toast re-surfaces if the deadline is
  still active. The `purchase_bonus` record is untouched — a fresh booking
  inside the window still earns the bonus.

---

## Home — State B: Booked

User's Home screen after they've booked their first lesson.

```
┌─────────────────────────────────┐
│  포도∞스피킹       [수강권 구매]│ ← header
│                                 │
│  ┌───────────────────────────┐  │ ← (other carousel/banner)
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ ░░░░ 🦩 (Podo on flamingo)│  │ ← hero illustration
│  │ ░░░░░░░░░░░░░░░░░░░░░░░░  │  │   (blue sky/mountain bg)
│  │                           │  │
│  │  예약된 레슨이 있어요!    │  │ ← bold title
│  │  교재로 미리 예습하면     │  │
│  │  편하게 대화할 수 있어요  │  │
│  │                           │  │
│  │  ┌─────────────────────┐  │  │
│  │  │ 일정  2월 28일(수)  │  │  │ ← booking details
│  │  │       16:30  [D-2]  │  │  │   • date in coral
│  │  │                     │  │  │   • D-day blue pill
│  │  │ 레슨  2. 기초 영어의│  │  │   • full lesson topic
│  │  │       첫걸음: 일상  │  │  │
│  │  │       표현부터...   │  │  │
│  │  │ 튜터  Andrew        │  │  │   • auto-assigned
│  │  └─────────────────────┘  │  │
│  │                           │  │
│  │  ┌──────────┬──────────┐  │  │
│  │  │ 일정 변경│ 예습하기 │  │  │ ← ghost / primary green
│  │  │          │          │  │  │   → reschedule (out of
│  │  └──────────┴──────────┘  │  │     scope)
│  └───────────────────────────┘  │   → Pre-Study screen
│                                 │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 🎁 4월 17일까지 첫 레슨 완료│ │ ← same toast as State A
│ │    하면                  ✕  │ │   (still shown while
│ │  이용 기간 21일 연장해 드려요│ │    bonus window is open
│ └─────────────────────────────┘ │    and bonus not awarded)
├─────────────────────────────────┤
│  홈   레슨   예약  AI학습  마이 │
└─────────────────────────────────┘
```

- Buttons are **"일정 변경"** (ghost) + **"예습하기"** (primary green)
- "입장하기" / lesson-room entry is **NOT** on this card — it lives on a
  separate UI surface closer to lesson start time, owned by another PRD
- Booking card has **three labeled rows** (일정 / 레슨 / 튜터), unlike the
  Booking Confirmed screen (Screen 4) which only shows two rows

**D-day badge rules** (inside the booking card, separate from the toast):
- ≥ 24h → `D-2`, `D-1`, ...
- 1h–24h → `{N}시간 전`
- < 1h → `{N}분 전`

---

## Bonus Window Phases

```
purchase                                                   forfeit
   │                                                          │
   │      INITIAL WINDOW              EXTENDED WINDOW         │
   │   (purchase_day + 0→2)        (purchase_day + 3→7)       │
   ├───────────────────────────┬──────────────────────────────┤
   │                           │                              │
 day 0                       day 2                         day 7
                              23:59                         23:59
                                │
                                ↓ if not yet awarded:
                          auto-extend, fire N5,
                          re-show toast (with new
                          deadline, even if dismissed)
```

- One bonus, two phases. Same reward in both.
- Extension fires exactly once, automatically, the moment day 2 ends.
- After day 7 ends without completion → bonus permanently forfeited.

---

## Notification Timeline

```
day 0          day 1              day 2          day 6              day 7
purchase       morning 9am        end of day     morning 9am        end of day
   │              │                 │              │                   │
   ├──────────────┼─────────────────┼──────────────┼───────────────────┤
   │              │                 │              │                   │
   N1*            N3                N5             N3                  (forfeit)
   on book       (initial)         extension      (extended)
                                     fires
```

- **N1** — fires on booking confirmation (any time, in-window booking)
- **N2** — fires on booking confirmation outside the window (rare; standard
  booking path only)
- **N3** — fires twice: morning of day 1 AND morning of day 6, suppressed
  if booked / awarded / forfeited
- **N4** — fires when first lesson is completed inside the active window
  (one-shot per purchase)
- **N5** — fires once at the moment the initial window expires unredeemed
  (announces the extension)

After N4 fires → silence (no further bonus notifications).
After day 7 forfeit → silence.

### Notification copy drafts

These are the **exact same drafts as the PRD** — the wireframes doc carries
them verbatim so the two files can never drift. All alimtalks include a single
bottom 웹 링크 button, matching the pattern already used by podo's existing
templates (`pd_reg_infinity_2` → `예습하러 Go`, `레슨권 만료 D-1` → `일기장
몰래보기`).

**Fallback rule.** `pd_reg_weeklyclass_2` / `pd_reg_infinity_2` stay as-is
for users without an active `purchase_bonus`. The new N1/N2 replaces those
templates inside `PodoScheduleServiceImplV2.book()` only when an active
unawarded `purchase_bonus` exists for the user.

**Variables used:**
- `{studentName}`, `{subjectName}`, `{Lessonterm}`, `{langtype}`,
  `{classDatetime}` — already used by the legacy `pd_reg_*_2` templates
- `{rewardCount}` / `{rewardDays}` — snapshotted at purchase time
- `{deadlineDaysLeft}` — integer days remaining until the active deadline
  (used only in N5)
- `{moHomeLink}` / `{pcHomeLink}` — already used by the legacy templates,
  auth-wrapped redirect to Home (app picks State A or B based on booking)
- `{moPrestudyLink}` / `{pcPrestudyLink}` — **new**, auth-wrapped redirect
  to the Prestudy screen for the first-lesson `booking_id`

#### N1 — first lesson booked inside the active window

**Push (both plans):**
- Title: `🎁 {studentName}님, 첫 레슨 예약 완료!`
- Body (count): `{classDatetime} 수업 완료하면 보너스 레슨 {rewardCount}회를 드려요 🔥`
- Body (unlimited): `{classDatetime} 수업 완료하면 이용 기간 {rewardDays}일 연장해 드려요 🔥`
- Push deep link: Booking detail overlay on Home State B

**Alimtalk (count plan):**
```
🏃 {studentName}님! 첫 레슨, 외국어 전설의 시.작.⭐

{subjectName} 레슨 등록 완료
- 레슨 일시 : {classDatetime}
────────────
🎁 첫 레슨 완료하면 {rewardCount}회 추가 지급!
✅ 두.일.안.에 첫 레슨 완료가 조건이야
✅ 수업까지 완료해야 혜택이 지급돼요
────────────

{Lessonterm}분 레슨만으로 원어민과의 5시간 대화만큼 실력 향상 효율을 내는 포도 레슨의 비결은 바로..!

가볍지만 강력한 "🌪폭.풍.예.습"
▶ 예습 1번으로, 레슨 만족도가 아주 좋기로 자자하다구!

🔥 {langtype} 실력 제자리 걸음 NO! 8분 이상 예습 필수!
- 예습 없이 레슨 받으면, 의미 없는 프리토킹에서 그치게 돼 ㅠㅠ
- "찐 실력향상"을 위해 꼭 예습 후 레슨 받기!!

⚠ 안내사항
- 예습 및 레슨은 [태블릿-포도 PODO 앱] 혹은 [노트북-나의 강의장] 에서만 가능합니다.
- 보너스 레슨은 첫 레슨 완료 직후 자동으로 지급돼요.

👇딱 8분만 노오력하자
```
**Button (웹 링크, single):**
| 타입 | 버튼 이름 | Mobile 링크 | PC 링크 |
|---|---|---|---|
| 웹 링크 | `📗 예습하러 Go` | `https://{moPrestudyLink}` | `https://{pcPrestudyLink}` |

**Alimtalk (unlimited plan):** same structure as count plan, with the bonus
block reading `🎁 첫 레슨 완료하면 이용 기간 {rewardDays}일 연장!` and the
footer replacing `보너스 레슨` with `연장 혜택`. Same button spec.

#### N2 — first lesson booked outside the active window

**Push (both plans):**
- Title: `🎉 {studentName}님, 첫 레슨 예약 완료!`
- Body: `{classDatetime}에 만나요. 예습하고 오면 대화가 더 편해져요 📗`
- Push deep link: Booking detail overlay on Home State B

**Alimtalk:** same as N1 minus the divider-wrapped bonus block (the rest of
the body — registration block, 폭.풍.예.습 block, 안내사항, closing line —
is unchanged).

**Button (웹 링크, single):**
| 타입 | 버튼 이름 | Mobile 링크 | PC 링크 |
|---|---|---|---|
| 웹 링크 | `📗 예습하러 Go` | `https://{moPrestudyLink}` | `https://{pcPrestudyLink}` |

#### N3 — morning of the day before the active deadline day

**Push (count plan):**
- Title: `⏰ {studentName}님! 첫 레슨 혜택 마감이 내일이에요`
- Body: `내일 밤까지 첫 레슨 완료하면 보너스 레슨 {rewardCount}회를 드려요 🎁`
- Push deep link: Home State A

**Push (unlimited plan):**
- Title: `⏰ {studentName}님! 첫 레슨 혜택 마감이 내일이에요`
- Body: `내일 밤까지 첫 레슨 완료하면 이용 기간 {rewardDays}일 연장해 드려요 🎁`
- Push deep link: Home State A

**Alimtalk (count plan):**
```
【첫 레슨 혜택 D-1】{studentName}님! 첫 레슨 보너스 혜택이 내일 마감돼요 🔔🔔🔔

{studentName}님, 꼭 확인해주세요💚
내일 밤이 지나면 첫 레슨 보너스 혜택은 더 이상 받을 수 없어요.
────────────
⏰ 내일 밤까지 한정 ⏰
✅ 첫 레슨 예약 + 완료 시
✅ 보너스 레슨 {rewardCount}회 자동 지급
────────────
지금 바로 첫 레슨을 예약하고, 보너스 레슨까지 챙겨가세요!

※ 본 메시지는 첫 구매 혜택 안내에 따라 자동 발송된 메시지입니다.
```
**Button (웹 링크, single):**
| 타입 | 버튼 이름 | Mobile 링크 | PC 링크 |
|---|---|---|---|
| 웹 링크 | `🔥 지금 첫 레슨 예약하기` | `https://{moHomeLink}` | `https://{pcHomeLink}` |

**Alimtalk (unlimited plan):** same structure, replace `보너스 레슨 {rewardCount}회 자동 지급` with `이용 기간 {rewardDays}일 자동 연장` and the closing "연장 혜택까지 챙겨가세요!" wording. Same button spec.

#### N4 — bonus awarded

**Push (count plan):**
- Title: `🎁 {studentName}님, 보너스 레슨 {rewardCount}회 지급 완료!`
- Body: `첫 레슨 완료 축하드려요. 포도와 함께 외국어 전설 가.즈.아⭐`
- Push deep link: Home State B

**Push (unlimited plan):**
- Title: `🎁 {studentName}님, 이용 기간 {rewardDays}일 연장!`
- Body: `첫 레슨 완료 축하드려요. 포도와 함께 외국어 전설 가.즈.아⭐`
- Push deep link: Home State B

**Alimtalk (count plan):**
```
🎉 {studentName}님! 첫 레슨 완.료. 축.하.드.려.요⭐

첫 레슨 완료 혜택으로
보너스 레슨 {rewardCount}회가 방금 지급됐어요 🎁
────────────
💚 지금부터는
✅ 추가된 {rewardCount}회 레슨권도 자유롭게 이용 가능
✅ 꾸준한 예습 + 레슨이 실력 향상의 열쇠!
────────────

🔥 {langtype} 실력 쭉쭉 올리는 단 하나의 비결
▶ 가볍지만 강력한 "🌪폭.풍.예.습" 1번이면 충분해!

다음 레슨도 미루지 말고 지금 바로 예약해봐요 👊
```
**Button (웹 링크, single):**
| 타입 | 버튼 이름 | Mobile 링크 | PC 링크 |
|---|---|---|---|
| 웹 링크 | `🎁 혜택 확인하러 가기` | `https://{moHomeLink}` | `https://{pcHomeLink}` |

**Alimtalk (unlimited plan):** same structure, replace `보너스 레슨 {rewardCount}회가 방금 지급됐어요` with `이용 기간이 {rewardDays}일 연장됐어요` and the `💚 지금부터는` block's first check with `연장된 기간 동안 무제한으로 레슨 수강 가능`. Same button spec.

#### N5 — extension fired (initial window expired)

**Push (count plan):**
- Title: `🎁 {studentName}님, 혜택 한 번 더 드려요!`
- Body: `{deadlineDaysLeft}일 안에 첫 레슨 완료하면 보너스 레슨 {rewardCount}회 🔥`
- Push deep link: Home State A

**Push (unlimited plan):**
- Title: `🎁 {studentName}님, 혜택 한 번 더 드려요!`
- Body: `{deadlineDaysLeft}일 안에 첫 레슨 완료하면 이용 기간 {rewardDays}일 연장 🔥`
- Push deep link: Home State A

**Alimtalk (count plan):**
```
🎁 {studentName}님! 첫 레슨 혜택, 한 번 더 열어드렸어요 ⭐

{studentName}님의 첫 레슨을 기다리다가
포도가 혜택 기간을 한 번 더 연장했어요💚
────────────
⏰ {deadlineDaysLeft}일 안에 한정 ⏰
✅ 첫 레슨 예약 + 완료 시
✅ 보너스 레슨 {rewardCount}회 자동 지급
────────────

🔥 이번 기회 놓치면 보너스 혜택은 영영 사.라.져.요
▶ 지금 바로 첫 레슨 예약하고, 보너스까지 챙겨가세요!

※ 본 메시지는 첫 구매 혜택 안내에 따라 자동 발송된 메시지입니다.
```
**Button (웹 링크, single):**
| 타입 | 버튼 이름 | Mobile 링크 | PC 링크 |
|---|---|---|---|
| 웹 링크 | `🔥 지금 첫 레슨 예약하기` | `https://{moHomeLink}` | `https://{pcHomeLink}` |

**Alimtalk (unlimited plan):** same structure, replace `보너스 레슨 {rewardCount}회 자동 지급` with `이용 기간 {rewardDays}일 자동 연장` and adjust the closing line accordingly. Same button spec.

---

> In-app surfaces (Home toast, Screen copy) use the **absolute date** of
> the currently active deadline. Push and alimtalk copy prefer **relative
> phrasing** (`두 일 안에`, `내일 밤`, `{deadlineDaysLeft}일 안에`) because
> it reads more naturally in messaging channels. Both surfaces derive their
> labels from the **same snapshotted timezone** captured at purchase time
> so they never disagree.

---

## End-to-End Flow Diagram

```
                ┌─────────────────────┐
                │   Purchase complete │
                └──────────┬──────────┘
                           │
                           ↓
                ┌─────────────────────┐
                │ Screen 1: Celebration│  (2–3s auto-advance,
                │  ✓ 구매가 완료...   │   no buttons)
                └──────────┬──────────┘
                           │
                           ↓
        ┌──────────────────────────────────────┐
        │ Screen 2: Booking Encouragement       │
        │  (confetti + happy mascot + 🎁,       │
        │   incentive card, "첫 수업 예약하기", │
        │   weak "혜택 포기하고 나가기" link)   │
        └─────┬────────────────────┬───────────┘
              │                    │
   첫 수업 예약하기          혜택 포기하고 나가기
              │                    │
              │                    ↓
              │       ┌─────────────────────┐
              │       │ Exit Reminder Sheet │
              │       │   sad mascot        │
              │       │ "정말 나가시겠어요?"│
              │       └────┬────────────┬───┘
              │            │            │
              │      지금 예약하기  혜택 포기...
              │            │            │
              │            │            ↓
              ↓◀───────────┘         ┌──────┐
              │  (forward, NOT back) │ Home │
              │                      │  A   │
              │                      └──┬───┘
              │                         │
              │                         │
   ┌──────────────────────────────┐    │
   │ Screen 3: Level + Time       │    │
   │  (level card, 6 slots,       │    │
   │  "다른 시간 보기", 예약 확정)│    │
   └─────┬────────────────────┬───┘    │
         │                    │        │
   pick time + 예약 확정     ←  back arrow returns
         │                       to Screen 2
         ↓
   ┌─────────────────────┐
   │ Screen 4: Confirmed │
   │     예약 완료!      │
   └─────┬───────────┬───┘
         │           │
      홈으로         예습하기
         │           │
         ↓           ↓
	      ┌──────┐  ┌──────────┐
	      │ Home │  │ Pre-Study│
	      │  B   │  └──────────┘
	      └──────┘
	              ⤺ (later: tap "예약하기"
	                in Home A → existing
	                standard Home booking
	                flow → Home B)
```

**Key flow notes:**
- The **only** way into Screen 3 is via Screen 2's CTA OR the modal's "지금 예약하기"
- The modal's primary action is **forward navigation**, not "back to Screen 2"
- The back arrow on Screen 3 returns to Screen 2 (the encouragement screen),
  NOT to Home
- Once the user is on Home, all subsequent booking happens via the standard
  booking path — they cannot re-enter the post-purchase flow

---

## What "completes" the bonus

The bonus only fires when the user **completes** their first lesson AND the
lesson's `scheduled_end_at` falls inside the active bonus window. Booking
alone is not enough, and a late tutor-finalize does not disqualify a user.

```
   booked                 ──────►  no bonus yet
       │
       ↓
   lesson starts          ──────►  no bonus yet
       │
       ↓
   lesson ends (wall)     ──────►  no bonus yet
       │
       ↓
   tutor finalizes in     ──────►  ✅ bonus awarded IFF
   grape (COMP_DATETIME)            scheduled_end_at ≤ active deadline
                                    │
                                    ↓
                                    count plan: +N classes
                                    unlimited:  +N days
                                    (N4 push + alimtalk)
```

- **Trigger** = tutor finalizes the class in `grape` (`GT_CLASS.CLASS_STATE = FINISH`, `INVOICE_STATUS = COMPLETED`, `COMP_DATETIME` stamped)
- **Eligibility comparison** = lesson's `scheduled_end_at` vs the stored
  `active_deadline` (NOT `COMP_DATETIME`). This protects users from tutor
  paperwork lag: a lesson scheduled 23:30–23:55 on the deadline day still
  qualifies even if `COMP_DATETIME` lands at 00:02 the next day
- If the lesson's `scheduled_end_at` is after the active window, no bonus
- If the user never completes a lesson by end of day 7, bonus is permanently
  forfeited

Implementation notes from the current system:
- Lesson completion is currently written in `grape`, where class-finalization updates `GT_CLASS.CLASS_STATE = FINISH`, `GT_CLASS.INVOICE_STATUS = COMPLETED`, and stamps `GT_CLASS.COMP_DATETIME`. The finalize event is the **trigger**; the `scheduled_end_at` field on the booking is the **comparison** input.
- Bonus state is tracked per `purchase_id`, snapshotted at purchase time with an absolute UTC deadline + user timezone. The snapshotted timezone is the single source of truth for eligibility, extension scheduling, notification timing, and the in-app `오늘 / 내일` labels.
- If multiple unawarded `purchase_bonus` records are active at the same time (e.g. first real purchase + admin re-grant on top), bind the completion to the **latest** active record by `created_at` — this matches the Home card/toast precedence rule so the card the user saw is the card that gets awarded.
- After a qualifying completion is detected, reward issuance should happen in `podo-backend`, not in the app UI.
- Count plan reward: create/update BONUS subscribe/ticket records using the existing backend bonus-entitlement infrastructure.
- Unlimited plan reward: extend the user's active entitlement end date using the existing backend expiry/final-date update path.
- The primary trigger is **event-driven on each completed lesson**, not a delayed full scan. Each completion can safely attempt the award check because the purchase-bonus record is idempotent.
- Cron is still needed for the initial-window auto-extension, reminder sends, and a low-frequency reconciliation job if an award call fails after the lesson was marked completed.
- The feature should be behind a **server-controlled kill switch**. App UI and backend award logic should both be gated so the funnel can be turned off cleanly.
- Bonus amounts should be editable in `grape` admin, then **snapshotted at purchase time** onto the purchase-bonus record so later admin edits do not silently change already-promised rewards.
- N4 should be sent only after the backend award succeeds, and the entire award flow should be idempotent per purchase.
- Inside `PodoScheduleServiceImplV2.book()`, when a user is booking their first regular lesson, check for an active unawarded `purchase_bonus` first. If present → route to the new N1 (in-window) or N2 (out-of-window) template. If absent → fall through to the existing `pd_reg_weeklyclass_2` / `pd_reg_infinity_2` templates unchanged.

---

Standard package copy note:
- Incentive card example becomes `4회 추가 지급 혜택`
- Home toast example becomes `추가 레슨권 4회 드려요!`

---

## Analytics & success metrics (summary)

Full spec lives in the PRD. High level:

- **Event tracking** reuses the existing `@shared/analytics` `track()`
  utility in podo-app (writes to ClickHouse). Events use the existing
  snake_case base names: `page_viewed`, `popup_viewed`, `button_clicked`.
  Every screen, bottom sheet, and CTA in this flow emits one.
- **Backend lifecycle events** emitted by `podo-backend` for the funnel
  metrics: `purchase_bonus_created`, `purchase_bonus_deadline_extended`,
  `purchase_bonus_awarded`, `purchase_bonus_forfeited`, `notification_sent`.
- **North-star metric:** book-rate within 72h of purchase (scoped to
  `source = 'purchase_flow'` purchases).
- **Guardrail metric:** refund-rate within 72h of purchase. Feature rolls
  back via the global kill switch if refund-rate rises beyond the launch
  threshold.

---

*This wireframe doc is a quick-read companion to PRD-v3-post-purchase-booking.md.
For full copy, edge cases, color tokens, and acceptance criteria, see the PRD.*
