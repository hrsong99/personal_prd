# Purchase Bonus — Per-Language Eligibility & Start-Date-Anchored Window

**Status:** Draft v0.1
**Author:** podo@day1company.co.kr
**Date:** 2026-05-20
**Parent feature:** Post-Purchase Booking (`archived/post-purchase-booking/PRD.md`)
**Touch repos:** `podo-backend` (`applications/purchaseBonus`, `applications/payment`), `grape` (extension/expiry crons), `podo-app` (home toast / booking branch — read-only impact)
**Feature flag:** `post_purchase_booking_enabled` (existing killswitch — no new flag)

> This is an amendment to the shipped Post-Purchase Booking feature. It changes **how** the first-lesson bonus (`purchase_bonus`) decides eligibility and computes its deadline. It does not change the reward itself, the notification set, or the booking UI.

---

## 1. Problem

The `purchase_bonus` ("first lesson bonus") is awarded when a user completes their first lesson after a qualifying purchase. Two parts of the current design break when a user studies more than one language or buys a package ahead of time.

### 1.1 Eligibility is account-wide, not per-language

`PurchaseBonusEligibilityService.isFirstRealPurchase(userId)` scans the user's **entire** subscription history across **all** languages. Any prior retained paid pack — in any language — permanently disqualifies every future purchase.

Consequence: a paying Japanese student who later buys English gets **no bonus**, even though English is a brand-new product for them. The first-lesson bonus is meant to reward starting a language, but today it only ever fires once per account.

### 1.2 The deadline is anchored to the purchase date, not the start date

`PurchaseBonusCreateService.create()` sets:

```java
initialDeadlineAt = endOfDay( LocalDate.now()  + initialWindowDays )   // now = purchase day
```

It never reads the subscription's start date. The window (a few days, then a one-time extension) starts ticking the moment payment clears.

Consequence: if a user buys English now but the package starts in a few weeks, the bonus window **expires before the first English lesson can happen**. The grape expiry cron flips the row to a terminal state and `awardIfEligible()` skips it (`scheduledEndAt.isAfter(activeDeadline)`). The bonus is silently lost.

### 1.3 The award path ignores language

`PurchaseBonusAwardService.awardIfEligible()` looks up the bonus with `findActiveLatestForUser(userId)` — filtered only on `user_id` + `status = ACTIVE`. The completed lesson's language is never matched. A Japanese lesson can award an English bonus, and the reward ticket is then issued in whichever language the triggering lesson happened to be in.

---

## 2. Goals & Non-Goals

### Goals

1. A user can earn the first-lesson bonus **once per language** (EN, JP), not once per account.
2. A user who already has a bonus for one language can still earn it for the other.
3. A **double pack (ENJP)** counts as **both** languages — buying it consumes the EN *and* JP opportunity at once.
4. The bonus window is anchored to **when the package starts**, so buying ahead of time no longer burns the window.
5. The award (the actual entitlement issuance) is matched to the **completed lesson's language**.

### Non-Goals

- Changing the reward amount, plan types, window lengths, or `purchase_bonus_policy` schema.
- Changing the notification set (N1–N5), copy, or booking/home UI layouts.
- More than two languages. The model assumes the language universe is exactly `{EN, JP}`.
- Retroactively re-activating bonuses already forfeited/expired under the old rules (see §10 Rollout).
- Issuing **two** rewards for one double-pack purchase — a double pack is still **one** bonus, one reward.

---

## 3. Current behavior (recap)

| Step | Code | Today |
|---|---|---|
| Eligibility ("the chance") | `PurchaseBonusEligibilityService.isFirstRealPurchase(userId)` | Account-wide; any prior retained paid pack disqualifies |
| Window anchor | `PurchaseBonusCreateService.create()` | `purchase day + initialWindowDays` |
| Award ("the actual bonus") | `PurchaseBonusAwardService.awardIfEligible()` → `findActiveLatestForUser(userId)` | Latest ACTIVE bonus, any language |
| Reward language | `buildBonusEntitlementRequest()` | Language of the completed lesson's `subscribe_mapp` |

---

## 4. Proposed model

### 4.1 Language coverage

A purchase **covers** a set of languages `L ⊆ {EN, JP}`, derived from its `langType`:

| `langType` | Covers `L` |
|---|---|
| `EN` | `{EN}` |
| `JP` | `{JP}` |
| `ENJP` (double pack) | `{EN, JP}` |

`LangUtils.separateLanguage()` already splits `langType` into 2-char codes — reuse it.

### 4.2 Per-language eligibility — "the chance"

Replace the account-wide check with a per-language one.

For each language `lang ∈ L`, the language is **claimed** if the user has a *past* paid (`paymentType ∉ {TRIAL, BONUS}`) `subscribe_mapp` whose `langType` overlaps `lang` and which does **not** pass the existing 7-day full-refund exemption. The 7-day refund rule (full refund + refunded within 7 days of purchase) is preserved exactly as today — just evaluated per language.

> A past **double pack** overlaps both EN and JP, so one retained ENJP purchase claims both languages. This is what makes "double pack counts as both languages" fall out automatically — no special case needed.

Define `newLangs = { lang ∈ L : lang is not claimed }`.

- If `newLangs` is empty → **no bonus is created** (skip, as today for `isFirstRealPurchase = false`).
- If `newLangs` is non-empty → **create one bonus**, and record `eligible_lang_type = newLangs` on it.

`eligible_lang_type` is the **award-matching set**: the languages that were genuinely new at creation time. Examples:

- First-ever purchase is `EN` → `eligible_lang_type = "EN"`.
- User already retained a `JP` pack, then buys `ENJP` → `newLangs = {EN}` → `eligible_lang_type = "EN"`.
- First-ever purchase is `ENJP` → `eligible_lang_type = "ENJP"`.

**Invariant:** because a language can only be "new" once, the `eligible_lang_type` sets of a single user's bonuses are always disjoint. Therefore any given lesson language matches **at most one** active bonus (see §4.4).

### 4.3 Start-date-anchored window

Compute the window from the package start date instead of the purchase date:

```
anchorDate         = max( today(snapshotTz), subscribeStartDate(snapshotTz) )
initialDeadlineAt  = endOfDay( anchorDate + initialWindowDays )
```

- `subscribeStartDate` comes from the purchased `subscribe_mapp` (`SubscribeMappDTO.subscribeStartDate`).
- For a normal immediate purchase, `subscribeStartDate ≈ today`, so `anchorDate = today` → **behavior unchanged**.
- For an ahead-of-time purchase, `anchorDate` is the future start date → the window opens when lessons actually begin.
- `max(today, …)` guards against past/blank start dates — the window never opens earlier than today.
- The one-time extension is unchanged in formula (`extendedDeadlineAt = initialDeadlineAt + extendedWindowDays`); it simply inherits the deferred anchor.
- The grape extension/reminder/expiry crons already key off `initial_deadline_at` / `COALESCE(extended_deadline_at, initial_deadline_at)`. A future-dated row is naturally untouched until its (future) deadline approaches — **no cron change required**.

### 4.4 Per-language award — "the actual bonus"

When a lesson completes, resolve the **lesson's language** (`lessonLang`) and look up the active bonus whose `eligible_lang_type` overlaps `lessonLang`:

- `findActiveLatestForUser(userId)` → `findActiveByEligibleLanguage(userId, lessonLang)`.
- An `EN` lesson can award a bonus with `eligible_lang_type ∈ {EN, ENJP}`; a `JP` lesson, `{JP, ENJP}`.
- By the §4.2 invariant there is at most one match — no ambiguity.
- The deadline check (`scheduledEndAt ≤ activeDeadline`) is unchanged but now compares against the start-anchored deadline.
- The reward ticket is issued in the **completed lesson's** language (current `buildBonusEntitlementRequest` behavior is now correct rather than accidental). A double-pack (`ENJP`) bonus is therefore awarded by — and rewarded in — whichever language the user takes their first lesson in.

---

## 5. Scenario truth table

Chronological purchase sequences. "Bonus?" = is a `purchase_bonus` created. Assumes no refunds unless stated.

| # | Sequence | Result |
|---|---|---|
| 1 | `JP` → `EN` | JP bonus, then EN bonus — **2 bonuses** |
| 2 | `JP` → `ENJP` | JP bonus, then ENJP bonus with `eligible_lang_type = EN` — **2 bonuses** |
| 3 | `ENJP` → `EN` → `JP` | ENJP bonus (`eligible = ENJP`); EN and JP later → **no bonus** — **1 bonus** |
| 4 | `EN` → `EN` | EN bonus; second EN → **no bonus** (same language) |
| 5 | `EN` → `ENJP` | EN bonus; ENJP → `newLangs = {JP}` → JP-only bonus (`eligible = JP`) — **2 bonuses** |
| 6 | `JP` (refunded ≤7d, 0 lessons) → `JP` | First JP not claimed (refund exemption); second JP → JP bonus — **1 bonus** |
| 7 | `JP` now, `EN` starting in 3 weeks | JP bonus (window from now); EN bonus, **window from the EN start date** |

Scenarios 1–3 are exactly the behavior described in the request; 4–7 are the implied edge cases.

---

## 6. Functional requirements

**FR-1 — Per-language eligibility.** `PurchaseBonusEligibilityService` exposes a method that, given `userId`, the new purchase's `langType`, and its `subscribeMappId`, returns `newLangs` (the set of unclaimed covered languages). Empty set ⇒ skip creation.

**FR-2 — 7-day refund exemption preserved.** The existing full-refund-within-7-days rule continues to apply, evaluated per language against past overlapping paid `subscribe_mapp`s.

**FR-3 — Record award-matching languages.** A created `purchase_bonus` stores `eligible_lang_type` = `newLangs` (`"EN"`, `"JP"`, or `"ENJP"`).

**FR-4 — Start-date-anchored deadline.** `initial_deadline_at` is computed from `max(today, subscribeStartDate)` per §4.3. `PurchaseBonusCreateService.create()` receives or fetches the purchased `subscribe_mapp`'s start date.

**FR-5 — Language-matched award.** `awardIfEligible()` resolves the completed lesson's language and looks up the active bonus by `eligible_lang_type` overlap. A lesson whose language matches no active bonus is a no-op.

**FR-6 — Single bonus per purchase.** A double-pack purchase still produces exactly one `purchase_bonus` row and one reward, regardless of how many languages are in `newLangs`.

**FR-7 — Concurrent active bonuses.** The system must tolerate a user holding more than one `ACTIVE` bonus at once (e.g. an EN bonus and a JP bonus). All single-active-bonus assumptions in callers of `findActiveLatestForUser` (the N1/N2 booking branch in `PodoScheduleServiceImplV2`, the home persistent toast) must be made language-aware — see §8 and Q-3.

**FR-8 — Immediate purchases unchanged.** When `subscribeStartDate ≈ today` and the purchase covers a never-claimed single language, the observable result is identical to today.

---

## 7. Data model & code changes

### Schema

`purchase_bonus` — **add one column:**

```sql
ALTER TABLE purchase_bonus
  ADD COLUMN eligible_lang_type VARCHAR(16) NOT NULL DEFAULT 'EN'
    COMMENT 'award-matching languages new at creation: EN | JP | ENJP'
  AFTER package_months;
```

No change to `purchase_bonus_policy` (it already has per-`lang_type` rows including `ENJP`).

> Optional: also persist `window_anchor_date` for operational transparency. Not required for logic. (Q-4)

### Code (`podo-backend`)

| Area | Change |
|---|---|
| `PurchaseBonusEligibilityService` | `isFirstRealPurchase(userId)` → `resolveEligibleLanguages(userId, langType, newSubscribeMappId) : Set<String>` |
| `PurchaseBonusCreateService` | Accept `subscribeStartDate`; compute `anchorDate`; persist `eligible_lang_type`; skip when `newLangs` empty |
| `PaymentGateway` (`createIfEligible` call site) | Pass the purchased `subscribe_mapp`'s `subscribeStartDate` |
| `PurchaseBonus` domain | New `eligibleLangType` field |
| `PurchaseBonusDslRepository` | `findActiveLatestForUser(userId)` → `findActiveByEligibleLanguage(userId, lessonLang)`; keep a list variant for callers that need all active bonuses |
| `PurchaseBonusAwardService` | Resolve lesson language; look up by `eligible_lang_type` overlap |
| `PodoScheduleServiceImplV2` (N1/N2 branch), home toast resolver | Make language-aware (Q-3) |

### Code (`grape`)

No logic change expected — the extension/reminder/expiry crons already operate purely on deadline columns. Verify against the future-dated-row case.

---

## 8. Edge cases

- **Overlapping coverage.** Sequence `EN → ENJP` creates a second bonus whose policy `langType` is `ENJP` but whose `eligible_lang_type` is `JP`. Award matching uses `eligible_lang_type`, **not** the policy `langType`, so the second bonus is correctly a JP-only bonus and never collides with the first EN bonus.
- **Two active bonuses, two windows.** Buying EN-ahead then JP produces two ACTIVE rows with different deadlines. The award path handles this via FR-5; the home toast / N1-N2 branch must not assume one (FR-7 / Q-3).
- **Double-pack reward language.** An `ENJP`-eligible bonus is awarded — and the reward ticket issued — in the language of the first completed lesson. The other language gets nothing extra (one bonus, one reward, by design).
- **Lesson language source.** If a double-pack is one `subscribe_mapp` with `langType = ENJP`, `originSubscribeMapp.getLangType()` cannot distinguish an EN lesson from a JP lesson. The lesson language must be resolved from the **`Lecture`/class**, not the `subscribe_mapp`. (Q-2)
- **Discount-excluded prior pack.** A past pack excluded by the `paymentDiscountAmount ≥ 40,000` rule still counts as a retained paid purchase and claims its language — same as today, now per language.
- **Null / past start date.** `subscribeStartDate` null or in the past ⇒ `anchorDate = today` ⇒ current behavior.

---

## 9. Open questions

- **Q-1 — "Start date" definition.** Is `SubscribeMappDTO.subscribeStartDate` the correct anchor, or should it be the date of the first *bookable* lesson? Confirm an ahead-of-time purchase actually produces a future `subscribeStartDate` on the `subscribe_mapp`.
- **Q-2 — Lesson language resolution.** Confirm the field on `Lecture`/`GT_CLASS` that gives a lesson's language, so a double-pack EN vs JP lesson can be told apart at award time.
- **Q-3 — Multiple active bonuses in the UI.** When a user holds an EN *and* a JP active bonus, what does the home persistent toast / N1-N2 booking branch show — the soonest-expiring, both, or the one for the language being booked? This is the main UI decision this PRD surfaces.
- **Q-4 — Operational transparency.** Persist `window_anchor_date` (and/or the covered `langType`) on `purchase_bonus` for CS/debugging, or leave it derivable?
- **Q-5 — Policy snapshot timing.** The `purchase_bonus_policy` is currently snapshotted at purchase time. For an ahead-of-time purchase, should it instead snapshot the policy active on the start date? (Default: keep purchase-time snapshot — simpler, and policy changes are rare.)

---

## 10. Rollout / migration

- Behind the existing `post_purchase_booking_enabled` killswitch — no new flag.
- **Backfill:** existing `purchase_bonus` rows get `eligible_lang_type` set from their policy's `lang_type` (best effort). Deadlines of already-created rows are **not** retroactively shifted.
- Already forfeited/expired bonuses are **not** revived.
- Ship order: schema migration → backend logic → verify grape crons tolerate future-dated rows → QA the §5 truth table.

---

## 11. Summary

| | Before | After |
|---|---|---|
| Eligibility | Once per account | Once per language; double pack claims both |
| Window anchor | Purchase date | Package start date (floored at today) |
| Award lookup | Latest active, any language | Active bonus matching the lesson's language |
| Reward language | Incidental | Deliberate — the completed lesson's language |
| Bonuses per double pack | 1 | 1 (unchanged) |
| Max bonuses per user | 1 | 2 (one EN + one JP) |
