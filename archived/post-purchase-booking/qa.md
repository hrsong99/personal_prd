# Post-Purchase Booking — QA Checklist

Branch: `release/20260417-first-lesson` (both podo-app and podo-backend)

## Setup (once)

- Feature flag `post_purchase_booking_enabled = true` on backend + app
- SYS_CODE values set: `PURCHASE_BONUS_EXTENSION_DAYS`, `PURCHASE_BONUS_TICKET_COUNT`, `PURCHASE_BONUS_WINDOW.*`
- Prepare 3 test accounts:
  - **User A** — fresh, no paid history
  - **User B** — has a prior paid purchase that was NOT a clean 7-day refund
  - **User C** — all prior purchases were 100% refunded within 7 days, 0 lessons completed
- **Out of v1 scope — do not test:** admin re-grant, N1/N2/N6/N7 alimtalks, backend analytics events, `disableFutureAlim` wiring

---

## State 1 — Right after purchase (User A, first real purchase)

**Action:** Complete payment as User A.

**Expect:**
- Celebration screen: green check, "구매가 완료되었어요!", plan name subtitle, **no buttons**, auto-advances in 2–3s
- Booking Encouragement screen: confetti, gift mascot, "첫 레슨 예약해봐요!", blue incentive card with plan-specific headline (e.g. "60일 연장 + 12회 추가 혜택"), blue/violet "첫 수업 예약하기" button, small gray "혜택 포기하고 나가기" link
- Backend: `GET /api/v1/purchase-bonuses/active` returns `200` + record

---

## State 2 — Right after purchase (User B, repurchase)

**Action:** Complete payment as User B.

**Expect:**
- Celebration screen with same visuals **but** a "확인" button, no auto-advance
- Tap 확인 → Home directly (no funnel, no toast)
- Backend: `GET /api/v1/purchase-bonuses/active` returns `204`, no `purchase_bonus` record created
- No N1–N5 notifications

---

## State 3 — Right after purchase (User C, clean-refund history)

**Action:** Complete payment as User C.

**Expect:** Treated same as User A (Variant A auto-advance, full funnel, bonus record created).

---

## State 4 — On Booking Encouragement screen, tap exit link

**Action (from State 1):** Tap "혜택 포기하고 나가기".

**Expect:**
- Exit Reminder Bottom Sheet: sad mascot, "정말 나가시겠어요?", plan-specific subtitle (무제한 vs 라이트 루틴), green "지금 예약하기" + gray exit link
- Tap "지금 예약하기" → navigates **forward** to Level+Time (not back)
- Tap "혜택 포기하고 나가기" → Home State A

---

## State 5 — On Level+Time screen

**Action (from State 1 or 4):** Land on Level+Time screen.

**Expect:**
- Level card with default level resolved
- If user had a trial class → banner "체험 레슨 튜터가 {level}을 추천했어요!" (only shows when trial-recommended)
- No trial → no banner, Start 1 fallback
- Double-pack → language toggle shown at top (default = trial language, or EN if no trial)
- "추천 시간" grid: 6 slots, labeled "오늘/내일/M월D일", 2-col grid
- "다른 시간 보기" ghost button below
- "예약 확정" disabled until a slot is picked

**Action:** Tap level card → Level Change Bottom Sheet opens, 4 options. Pick different level.

**Expect:** Sheet closes, level updates, **any selected time is cleared**, screen returns to "추천 시간" default.

**Action:** Tap "다른 시간 보기" → Calendar Bottom Sheet.

**Expect:**
- 3-day picker (purchase_day +0/+1/+2), AM/PM sections, 3-col grids
- Today's past times and any slot within 2-hour cutoff are **hidden entirely**
- Pick day + time → 확인
- Back on main screen: "추천 시간" grid is fully replaced by compact "선택된 레슨 일정" pill + "날짜 변경" ghost button

**Action:** On double-pack, toggle language.

**Expect:** Level re-resolves via chain for new language, time selection cleared, no prior state restored when toggling back.

---

## State 6 — Right after booking confirmation

**Action:** Pick a slot, tap "예약 확정".

**Expect:**
- Booking Confirmed screen: study mascot with clipboard, "레슨이 예약됐어요!"
- Date/time in coral + D-day badge, lesson row shows "언어 레벨" (no tutor name)
- Green "예습하기" primary + small gray "홈으로" text link

---

## State 7 — On Home, not booked (after exiting)

**Action:** Exit via modal's forfeit link, land on Home.

**Expect:**
- State A card: hero illustration, greeting, level preview card with book cover thumbnail, "다른 레슨보기" (ghost) + "예약하기" (green)
- **Persistent bonus toast above GNB:**
  - Translucent dark gray pill — GNB icons behind it should look **visibly blurred** (regression risk: flat gray block = broken)
  - Gift icon, 2-line copy with deadline date in app primary green `#B5FD4C`, X on right
  - Body is **non-clickable** — only X dismisses
- Switch to other tabs → toast does NOT follow
- Tap X → toast disappears. Force-close + reopen app within 24h → **stays dismissed** (server-side `dismissed_at` persistence). Reopen after 24h → toast **reappears** with the currently active deadline (X is a snooze, not terminal)
- Tap "예약하기" on card → routes into **existing standard Home booking flow** (NOT back into post-purchase screens)

---

## State 8 — On Home, booked

**Action:** Complete a booking, go to Home.

**Expect:**
- State B card: sky/flamingo hero, "예약된 레슨이 있어요!", 3-row booking card (일정 with D-day inline / 레슨 / 튜터), "일정 변경" ghost + "예습하기" green
- Bonus toast still present above GNB (same behavior as State 7)

---

## State 9 — Right after initial deadline passes (purchase_day + 2 EOD)

**Action:** Let purchase_day + 2 pass without booking (use dev tools to advance deadline, or trigger `PurchaseBonusExtensionScheduler` after setting deadline in past).

**Expect:**
- N5 alimtalk + push delivered
- `purchase_bonus.extended_deadline` now set to purchase_day + 7
- Open app → bonus toast **re-appears on Home even if previously dismissed in the initial window**, showing new deadline (the extension flips the phase and resets the dismissal row)
- Dismiss extended-window toast → disappears for 24h, then **reappears** again on next Home mount after 24h. Snooze rule applies independently in the extended phase until the extended deadline expires

---

## State 10 — Right after extended deadline passes (purchase_day + 7 EOD)

**Action:** Let purchase_day + 7 pass without completing a lesson.

**Expect:**
- Bonus permanently forfeited
- Home toast disappears entirely
- State A card remains but without any bonus copy
- No further bonus alimtalks/pushes ever fire for this purchase

---

## State 11 — Right after completing first lesson (within active window)

**Action:** Tutor finalizes the class in `grape` while the bonus window is still active.

**Expect:**
- N4 alimtalk + push delivered (once, idempotent)
- 무제한: pack `valid_until` extended by configured days
- 라이트 루틴: `valid_until` extended **AND** bonus classes added — both or neither (atomic)
- Home toast disappears
- Replay the completion event → no duplicate award, no duplicate N4

---

## State 12 — After booking, attempt reschedule past deadline

**Action (from State 8):** Open reschedule, pick a slot where `scheduled_end_at > active_deadline`.

**Expect:**
- Warning sheet: "이 시간으로 옮기면 혜택을 받을 수 없어요" + Confirm/Cancel
- If confirmed: Home stays in State B, but bonus toast **re-appears even if previously dismissed**, still showing original deadline
- Reschedule back into window → bonus earnable again

---

## State 13 — After booking, cancel without rebooking

**Action (from State 8):** Cancel the lesson entirely.

**Expect:**
- Home reverts State B → State A
- Bonus toast re-surfaces if deadline still active
- `purchase_bonus` record intact — user can rebook and still earn

---

## Cross-cutting checks (run across all states)

- **Timezone:** purchase in Seoul, change device to LA TZ — deadline dates, "오늘/내일" labels, and toast copy stay in Seoul time
- **Kill switch:** flip feature flag off — new purchases skip funnel, existing toasts/screens stop rendering, already-awarded bonuses untouched
- **Deep links:** N3 → Home State A; N4 → Home State B; N5 → Home State A with refreshed toast
- **Multi-purchase edge:** if two bonus-eligible purchases exist, card + toast reflect the **latest** (by `created_at`); one completed lesson satisfies only one
- **Exit modal copy is intentionally scary** but leaving doesn't forfeit anything — not a bug

---

## Sign-off

| State | Pass |
|---|---|
| 1. Post-purchase Variant A (User A) | ☐ |
| 2. Post-purchase Variant B (User B) | ☐ |
| 3. Clean-refund eligibility (User C) | ☐ |
| 4. Exit modal (forward + forfeit paths) | ☐ |
| 5. Level+Time (level change, calendar, language toggle) | ☐ |
| 6. Booking Confirmed screen | ☐ |
| 7. Home State A + toast behavior | ☐ |
| 8. Home State B + toast behavior | ☐ |
| 9. Initial deadline extension | ☐ |
| 10. Extended deadline forfeit | ☐ |
| 11. Lesson completion award | ☐ |
| 12. Reschedule past deadline guardrail | ☐ |
| 13. Cancel reverts State B → A | ☐ |
| Cross-cutting: timezone, kill switch, deep links, multi-purchase | ☐ |
