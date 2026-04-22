# Home Persistent Bonus Toast — Spec (temporary extract)

**Temporary focused extraction from `PRD.md`** — covers only the persistent bonus toast pinned above the bottom GNB on the Home screen. Canonical source is `PRD.md` / `PRD-ko.md`. If this doc disagrees with PRD.md, PRD.md wins.

---

## Where it shows

A static pill-shaped toast pinned above the bottom GNB, **Home screen only** — does not follow the user into other tabs. Display-only (not clickable) with a single **X** button on the right edge for explicit dismissal.

Placement visually overlaps the top edge of the GNB so the icons are partially covered and read through the backdrop blur described below.

---

## Visual

| Property | Value |
|---|---|
| Pill fill | Translucent dark gray — `rgba(28, 28, 28, 0.72)` (not solid; Home content bleeds through) |
| Backdrop filter | `blur(16px) saturate(140%)` — GNB icons beneath are visibly blurred so the pill reads as a floating layer |
| Drop shadow | `0 8px 24px rgba(0, 0, 0, 0.24)` — wider / softer than the Screen 2 CTA shadow to match the floating translucent feel |
| Icon (left) | 🎁 gift icon |
| Button (right) | White X (dismiss) |
| Text | White, **deadline date emphasized in app primary green `#B5FD4C`** |

---

## Copy

Two lines:

- **Line 1:** `{deadline_date}까지 첫 레슨 완료하면` — `{deadline_date}` rendered in `#B5FD4C`
- **Line 2:** `{bonus_reward}!`

### `{deadline_date}`

Absolute calendar date of the **currently active** deadline (initial or extended), localized against the **snapshotted timezone** stored on `purchase_bonus` (NOT the device's current timezone — a user who purchases in Seoul and flies to LA still sees the Seoul-relative date).

### `{bonus_reward}` — by plan × duration

| Plan | Duration | `{bonus_reward}` |
|---|---|---|
| 무제한 | 3 months | `이용 기간 21일 연장해 드려요` |
| 무제한 | 6 months | `이용 기간 30일 연장해 드려요` |
| 무제한 | 12 months | `이용 기간 60일 연장해 드려요` |
| 라이트 루틴 | 3 months | `추가 레슨권 5회 드려요` |
| 라이트 루틴 | 6 months | `추가 레슨권 8회 드려요` |
| 라이트 루틴 | 12 months | `추가 레슨권 12회 드려요` |

**라이트 루틴 intentionally omits the day-extension half** — the pill has limited horizontal room and the class-count half is the more visible win. The full combined reward (days + classes) is still communicated on Screen 2's incentive card and in the alimtalks.

### Full rendered examples

- 무제한 3mo, extended window: `4월 22일까지 첫 레슨 완료하면 / 이용 기간 21일 연장해 드려요!`
- 라이트 루틴 6mo, initial window: `4월 17일까지 첫 레슨 완료하면 / 추가 레슨권 8회 드려요!`

---

## Interaction

- **Body:** not tappable — purely informational, does not navigate anywhere
- **X button:** dismisses the toast for the **current window phase only** (see Lifecycle → Dismissal persistence)

---

## Lifecycle

- **Appears** immediately when the user first lands on Home after purchase
- **Persists** across app sessions until either:
  1. Active bonus window expires without completion (toast disappears permanently), OR
  2. User completes first lesson and bonus is awarded (toast disappears permanently)

  User-initiated X-tap is a **24h snooze**, not a terminal state — see below.

### X-dismissal = 24-hour snooze

Tapping X hides the toast for **24 hours** from the dismissal timestamp. On the next Home mount after that window elapses, the toast reappears automatically with the currently active deadline. Each subsequent X-tap resets the 24h timer.

**If the active deadline passes (forfeit) or the bonus is awarded during the snooze, the toast stays hidden permanently** — no reason to re-surface it after the bonus is already resolved.

### Re-appears on extension

If the initial window expires without completion and the deadline is auto-extended (end of `purchase_day + 2` → end of `purchase_day + 7`), the toast **re-appears with the new deadline date regardless of any running snooze** — the extension event flips the phase (initial → extended) and resets the dismissal row for the new phase. The 24h snooze rule applies independently inside the extended phase (the user can keep re-dismissing; each tap buys another 24h of silence until the extended window expires).

### Dismissal persistence

Dismissal is stored **server-side** as a `dismissed_at` timestamp scoped to `(purchase_id, window_phase)`, so the 24h countdown survives app reinstall, logout/login, and multi-device usage. The two window phases (initial, extended) have independent dismissal rows.

### Re-surfacing edge cases

- **Cancel booked lesson without rebooking** → Home reverts to State A and the toast re-surfaces if the active deadline is still open. The `purchase_bonus` record is unchanged; user can still earn the bonus by rebooking and completing within the window.
- **Reschedule booked lesson past the active deadline** → Home stays in State B, but the toast **re-appears even if previously dismissed**, with the original deadline date still shown. Deliberate cue to prevent silent loss of the bonus. User can reschedule again inside the window to re-qualify.

### Multiple purchases edge case

If the user has multiple unconsumed bonus-eligible purchases simultaneously (rare — practically only via admin re-grant on top of a new first purchase): only one toast is shown at a time, and both the toast and the Home card (State A / State B) follow the **latest purchase** by `created_at`.

---

## Analytics

| Event | Name | Props | When |
|---|---|---|---|
| `popup_viewed` | `home_bonus_toast` | `{ purchase_id, deadline_phase, deadline_date }` | Once per Home mount per session while the toast is visible |
| `button_clicked` | `home_bonus_toast_dismiss` | `{ purchase_id, deadline_phase }` | On X-tap |

---

## Cross-references (canonical source in PRD.md)

- **Home Screen States → State A → Persistent bonus toast** — primary spec
- **Home Screen States → State B → Persistent bonus toast** — identical toast, different Home card underneath
- **Visual Design Notes → Shadow & blur tokens** — the translucent pill is the only surface in the flow that uses backdrop blur
- **Incentive Logic** — reward amounts per plan × duration (source for the `{bonus_reward}` table rows)
- **Bonus Window Definition → Timezone source of truth** — `{deadline_date}` timezone behavior
- **Incentive Logic → Key rules (Cancel / Reschedule semantics)** — re-surface edge cases
