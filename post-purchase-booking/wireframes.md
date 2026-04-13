# Post-Purchase First Lesson Booking Flow — ASCII Wireframes

Visual reference for every screen in the flow. Read top-to-bottom alongside the
PRD, or skim the Flow Diagram at the bottom to see how everything connects.

The flow has **four screens**: Celebration → Booking Encouragement → Level + Time
Selection → Booking Confirmed. Plus three bottom sheets (Exit Reminder, Level
Change, Calendar) and two Home states (Not Booked, Booked).

---

## Screen 1 — Purchase Celebration (auto-advance after 2–3s)

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
│  │ 10:00    │ │ 10:30    │      │   available slots,
│  └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐      │
│  │ 오늘     │ │ 오늘     │      │
│  │ 11:00    │ │ 11:30    │      │
│  └──────────┘ └──────────┘      │
│  ┌──────────┐ ┌──────────┐      │
│  │ 오늘     │ │ 오늘     │      │
│  │ 12:00    │ │ 12:30    │      │
│  └──────────┘ └──────────┘      │
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
- The default grid is the **next 6 closest available times** for the currently selected language + level, ordered chronologically
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
- Body is NOT tappable — only the X button is interactive

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

`{lessonDateLabel}` = `4월 17일(수)` 같은 날짜 라벨
`{lessonTime}` = `오후 8:30` 같은 시간
`{deadlineDate}` = `4월 17일` 같은 절대 마감일
`{rewardCount}` / `{rewardDays}` = 구매 시점에 스냅샷된 혜택 값

- **N1 Push**
  Count: `첫 레슨 예약 완료!` / `{lessonDateLabel} {lessonTime} 수업까지 완료하면 보너스 레슨 {rewardCount}회를 드려요.`
  Unlimited: `첫 레슨 예약 완료!` / `{lessonDateLabel} {lessonTime} 수업까지 완료하면 이용 기간 {rewardDays}일 연장 혜택을 드려요.`
- **N1 Alimtalk**
  Count: `안녕하세요, 포도입니다.\n첫 레슨 예약이 완료되었어요.\n{lessonDateLabel} {lessonTime} 수업을 {deadlineDate}까지 완료하면 보너스 레슨 {rewardCount}회를 드려요.`
  Unlimited: `안녕하세요, 포도입니다.\n첫 레슨 예약이 완료되었어요.\n{lessonDateLabel} {lessonTime} 수업을 {deadlineDate}까지 완료하면 이용 기간 {rewardDays}일 연장 혜택을 드려요.`

- **N2 Push**
  `첫 레슨 예약 완료!` / `{lessonDateLabel} {lessonTime}에 만나요.`
- **N2 Alimtalk**
  `안녕하세요, 포도입니다.\n첫 레슨 예약이 완료되었어요.\n{lessonDateLabel} {lessonTime}에 만나요.`

- **N3 Push**
  Count: `혜택 마감이 내일이에요` / `내일 밤까지 첫 레슨을 완료하면 보너스 레슨 {rewardCount}회를 드려요.`
  Unlimited: `혜택 마감이 내일이에요` / `내일 밤까지 첫 레슨을 완료하면 이용 기간 {rewardDays}일 연장 혜택을 드려요.`
- **N3 Alimtalk**
  Count: `안녕하세요, 포도입니다.\n{deadlineDate}까지 첫 레슨을 완료하면 보너스 레슨 {rewardCount}회를 드려요.\n마감 전 첫 레슨을 예약해 보세요.`
  Unlimited: `안녕하세요, 포도입니다.\n{deadlineDate}까지 첫 레슨을 완료하면 이용 기간 {rewardDays}일 연장 혜택을 드려요.\n마감 전 첫 레슨을 예약해 보세요.`

- **N4 Push**
  Count: `보너스가 지급됐어요!` / `첫 레슨 완료 축하드려요. 보너스 레슨 {rewardCount}회가 추가됐어요.`
  Unlimited: `보너스가 지급됐어요!` / `첫 레슨 완료 축하드려요. 이용 기간이 {rewardDays}일 연장됐어요.`
- **N4 Alimtalk**
  Count: `안녕하세요, 포도입니다.\n첫 레슨 완료를 축하드려요.\n보너스 레슨 {rewardCount}회가 지급되었어요.`
  Unlimited: `안녕하세요, 포도입니다.\n첫 레슨 완료를 축하드려요.\n이용 기간이 {rewardDays}일 연장되었어요.`

- **N5 Push**
  Count: `혜택 기회를 한 번 더 드려요` / `{deadlineDate}까지 첫 레슨을 완료하면 보너스 레슨 {rewardCount}회를 드려요.`
  Unlimited: `혜택 기회를 한 번 더 드려요` / `{deadlineDate}까지 첫 레슨을 완료하면 이용 기간 {rewardDays}일 연장 혜택을 드려요.`
- **N5 Alimtalk**
  Count: `안녕하세요, 포도입니다.\n첫 레슨 혜택 기간을 한 번 더 열어드렸어요.\n{deadlineDate}까지 첫 레슨을 완료하면 보너스 레슨 {rewardCount}회를 드려요.`
  Unlimited: `안녕하세요, 포도입니다.\n첫 레슨 혜택 기간을 한 번 더 열어드렸어요.\n{deadlineDate}까지 첫 레슨을 완료하면 이용 기간 {rewardDays}일 연장 혜택을 드려요.`

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

The bonus only fires when the user **completes** their first lesson within
the active bonus window. Booking alone is not enough.

```
   booked         ──────►  no bonus yet
       │
       ↓
   lesson starts  ──────►  no bonus yet
       │
       ↓
   lesson ends    ──────►  ✅ bonus awarded
   (within window)         (N4 push + alimtalk)
                            ↓
                            count plan: +N classes
                            unlimited:  +N days
```

If the lesson ends after the active window closes, no bonus. If the user
never completes a lesson by end of day 7, bonus is permanently forfeited.

Implementation notes from the current system:
- Lesson completion is currently written in `grape`, where class-finalization updates `GT_CLASS.CLASS_STATE = FINISH`, `GT_CLASS.INVOICE_STATUS = COMPLETED`, and stamps `GT_CLASS.COMP_DATETIME`.
- Bonus eligibility should therefore be checked server-side from that completion write path, using `COMP_DATETIME` as the canonical completion timestamp for the purchase-bound deadline comparison.
- After a qualifying completion is detected, reward issuance should happen in `podo-backend`, not in the app UI.
- Count plan reward: create/update BONUS subscribe/ticket records using the existing backend bonus-entitlement infrastructure.
- Unlimited plan reward: extend the user's active entitlement end date using the existing backend expiry/final-date update path.
- The primary trigger is **event-driven on each completed lesson**, not a delayed full scan. Each completion can safely attempt the award check because the purchase-bonus record is idempotent.
- Cron is still needed for the initial-window auto-extension, reminder sends, and a low-frequency reconciliation job if an award call fails after the lesson was marked completed.
- The feature should be behind a **server-controlled kill switch**. App UI and backend award logic should both be gated so the funnel can be turned off cleanly.
- Bonus amounts should be editable in `grape` admin, then **snapshotted at purchase time** onto the purchase-bonus record so later admin edits do not silently change already-promised rewards.
- N4 should be sent only after the backend award succeeds, and the entire award flow should be idempotent per purchase.

---

Standard package copy note:
- Incentive card example becomes `4회 추가 지급 혜택`
- Home toast example becomes `추가 레슨권 4회 드려요!`

*This wireframe doc is a quick-read companion to PRD-v3-post-purchase-booking.md.
For full copy, edge cases, color tokens, and acceptance criteria, see the PRD.*
