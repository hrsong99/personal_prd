# Designated Tutor (지정튜터) Feature — PRD & Wireframes

**Status:** Draft v0.2
**Author:** podo@day1company.co.kr
**Working repo:** `personal_prd`
**Touch repos:** `podo-app` (web/native), `podo-backend`, `grape` (admin)

> The HTML version (`designated-tutor-feature-prd.html` / `designated-tutor-feature-prd-ko.html`) is the source of truth for wireframes. This markdown mirrors its structure and behavior notes.

---

## 1. Goal

Let students favorite specific PODO tutors and designate them for their subscription lessons via a paid **지정튜터 티켓 enabler**, alongside the existing random-matching flow. The ticket does *not* cover the lesson itself — the lesson is drawn from the student's active subscription.

Today the product matches students to any available tutor on a chosen time slot (`ScheduleTimeBlock` aggregated by `cnt` per time). Students can only exclude tutors via `le_tutor_exclusion` — there is no way to actively pick or favorite a tutor, and no public tutor profile.

This PRD introduces the inverse: discovery (profile + search), preference (favorites + private memo), commerce (지정튜터 티켓 — an **enabler** that designates the tutor for a subscription lesson, not a lesson replacement), a tutor-aware booking flow, and a new **튜터** tab in GNB as a parallel entry to the lesson-first flow.

---

## 2. What's new

- **Tutor profile** — public profile with bio, audio intro, hashtags, reviews, view-only schedule, private memo, and 차단 toggle
- **지정튜터 티켓 (enabler)** — paid SKU layered on top of an active subscription; designates a tutor for a subscription lesson (does not add an extra lesson). Purchased / free-seed variants in v1 (compensation variant deferred); auto-use earliest-expiring first
- **찜한 튜터** — favorites list (inverse of existing block), per-favorite private memo
- **튜터 picker (slot-scoped)** — reached from booking confirm dialog after picking lesson + time
- **튜터 tab (NEW GNB entry)** — parallel entry; tutor list → profile → booking page with auto-filled lesson + recommended times
- **Past-lesson cards** — tutor-led variant on the 예약 tab
- **차단 bar on tutor profile** — replaces the previous ⋮ menu plan
- **No 국적 / 성별 filter** — removed to avoid discriminatory screening (search filters: 한국어 가능 toggle + scope chips 전체 튜터 / 함께한 적 있는 / 찜한 튜터만)
- **NPS completion 찜 / 차단 opt-ins** — 4–5★ surfaces a `찜한 튜터에 추가할게요` opt-in; 1–2★ surfaces the existing `다시 레슨하지 않을래요` opt-in (tutor-exclusion). 3★ is neutral — no opt-in.

---

## 3. Wireframes

> Mobile-first (375px viewport). Korean copy is source of truth for v1; existing i18n pipeline handles JP/EN.

### 3.0 — Primary booking flow (lesson-first)

```
레슨 탭 → 레슨 리스트 → 예약하기 → §3.1 → (option) 튜터 선택하기 → §3.2 → confirm
```

A second parallel entry exists via the new **튜터** tab — see §3.7.

GNB ordering after this PRD: 홈 / 레슨 / **튜터 (NEW)** / 예약 / Beta AI 학습 / 마이포도. 6 tabs total.

---

### 3.2 — Tutor picker (slot-scoped) `/booking?classId=…` modal

Reached from §3.1's booking confirm dialog. After the student picks lesson + time, an extra "튜터 선택하기 ›" row appears in the existing `BookingConfirmDialog` when the user has favorites or tickets. Tapping it opens the tutor picker:

```
┌────────────────────────────────────────┐
│ ← 튜터 선택   5/13(수) 12:00     🎫 3장 │
├────────────────────────────────────────┤
│ [평점 높은 순 ⌄]  [필터]                │
├────────────────────────────────────────┤
│ ♥ Jenny    POPULAR                     │
│   ★ 4.9 (312) · 한국어 가능             │
│   함께한 7회                            │
│   📝 발음 꼼꼼함, 차분함                │
│   #발음교정 #초보환영              프로필 →│
├────────────────────────────────────────┤
│ ♥ Sarah ★ 4.7 (156) · 함께한 3회        │
├────────────────────────────────────────┤
│ ♡ Mark  NEW · 신규                      │
├────────────────────────────────────────┤
│ ♡ Lisa  ★ 4.8 (212)                     │
└────────────────────────────────────────┘
```

- Cards favorited (♥) pinned on top with filled hearts; the "내 메모" (§3.6) appears as a small italic accent line.
- Tap card body → confirm dialog (same `wf-dialog` used by §3.1 and §3.3). The dialog now has a **튜터** row that shows the chosen tutor name; **변경 ›** is intentionally absent once a tutor is chosen via the picker.
- Tap "프로필 →" → profile preview (read-only profile shown over picker).
- 휴식 중 (`classPause=true`) tutors hidden.

**Sort options** (single-select): `평점 높은 순` (default) · `리뷰 많은 순` · `함께한 횟수 많은 순`. `함께한 횟수` is counted per-current-user (lessons between this student and this tutor), not global.

**Filter options**: `한국어 가능 튜터만 보기` toggle + scope chips (single-select, default `전체 튜터`): `전체 튜터` / `함께한 적 있는 튜터만` / `찜한 튜터만`. **No 국적 / 성별 filters** — see §5 Policies.

**0-ticket state.** Header ticket badge turns red (`0장`). Tapping a tutor card opens:

```
┌──────────────────────────────┐
│ 티켓이 필요해요              │
│ 지정 튜터를 예약하려면        │
│ 지정튜터 티켓이 필요해요.    │
│                              │
│   [취소]      [티켓 구매]    │
└──────────────────────────────┘
```

- **취소** dismisses the dialog and returns to the picker. Random matching is reached through the existing lesson-first flow (§3.1), not offered as a side-door here.
- **티켓 구매** → ticket purchase page (§3.5).

---

### 3.1 — Booking screen `/booking?classId=…` — MODIFIED

Existing slot grid plus pink-bordered slot tint when one or more **favorited** tutors have availability at that slot. Legend at top right (`♥ 찜한 튜터 · ● 마감`).

Slot tap shows the existing confirm dialog with the new **튜터** row:

```
┌────────────────────────────────────────┐
│ 레슨 일정 확인                          │
│  레슨명     1. 단수 명사와…              │
│  레슨 일정  5월 13일(수) 12:00~12:25     │
│  튜터       랜덤 배정      튜터 선택 ›  │
│                                         │
│   [취소]              [예약하기]         │
└────────────────────────────────────────┘
```

- Default `튜터 | 랜덤 배정` keeps the existing flow; tapping **튜터 선택 ›** opens the picker (§3.2).
- After a tutor is chosen, the row becomes `튜터 | Jenny` with no change affordance (cancel + re-enter to swap).

---

### 3.3 — Tutor profile `/tutors/[tutorId]`

Body order (profile-head is fixed at top):

1. **Profile head** — avatar, name, `5년차 · 한국어 가능`, `★ 4.9 (312) · 함께한 7회`, `▶ 30초 자기소개` audio player, hashtag chips. Header has `←` and ♥ (top-right) when favorited. **No country flag** — see §5 Policies (same rationale as removing 국적/성별 filters).
2. **소개** — bio (`Tutor.tutorIntro`, char limit expanded), `…더보기` truncation.
3. **내 메모** — private per-favorite memo. Inline-editable card (no edit button), `cursor: text`, faint caret indicator; caption reads `· 나만 볼 수 있어요 · 자동 저장`. Autosaves on blur (debounced sync while typing). Surfaced again in the picker (§3.2) and favorites list (§3.6) so the student remembers *why* they favorited. **Authored only here** — never auto-prompted at favoriting or in the NPS opt-in flow.
4. **리뷰** — count + "전체 보기 →"; one card shown (user's own review if exists, else top-helpful recent).
5. **이번 주 가능 시간 보기** — outlined button. Tapping opens a view-only slide-up showing this tutor's open slots ("조회만 가능해요. 예약은 레슨 리스트에서 시작해주세요."). Does NOT start a booking — that flow is owned by §3.1/§3.2/§3.7.
6. **차단 bar** — full-width grey bar with two states:
   - **Unblocked**: `이 튜터를 차단할까요?` + pink `차단` pill. Tap → confirm dialog (reuses tutor-exclusion). If currently favorited, prompt `찜 해제하고 차단할까요?` first (mirror of §3.6's `차단 해제하고 찜할까요?` — favorites and blocks remain mutually exclusive).
   - **Blocked**: `이 튜터를 차단중입니다.` + navy `해제` pill. Header ♥ removed. Sticky CTA replaced with a `차단된 튜터` status pill (booking disabled).
7. **Sticky CTA — `이 튜터로 예약하기`**. CTA state depends on entry point:
   - From the picker (§3.2): lesson + slot already chosen → confirm dialog with this tutor pre-filled, no 변경 affordance.
   - From the 튜터 탭 (§3.7): no lesson/slot yet → routes through §3.7.3 booking page.
   - From a past-lesson card avatar tap (§3.4): booking-enabled — routes through §3.7.3 booking page (strongest "rebook this tutor" moment).
   - From my-podo favorites: view-only (no booking CTA).
   - For non-subscribers / expired-sub users: CTA shows a subscription upsell prompt instead of routing to booking.

**Field source mapping:**

| UI | Backend field |
|---|---|
| Avatar | `Tutor.profileLargeImage` |
| Name | `Tutor.name` (display) — never expose `realName` |
| Years | derived from `Tutor.hireDate` (new) |
| 한국어 가능 | `Tutor.koreanAvailable` |
| Audio | **new** `Tutor.audioIntroUrl` + `audioIntroDuration` — player is hidden entirely while moderation is pending or unrecorded |
| Hashtags | `Tutor.hashTag` |
| 소개 | `Tutor.tutorIntro` (char limit expanded) |
| 리뷰 | **new** `le_tutor_review` aggregating NPS + opt-in free text |
| 예약 가능 시간 (view-only) | `ScheduleTimeBlock` where `tutor_id=…` and `student_id IS NULL` |
| 내 메모 | **new** `le_tutor_favorite.note` (≤100 chars) |

---

### 3.4 — Past lessons (예약 tab) `/reservation` — MODIFIED

Today: `RegularLessonCard` leads with the course thumbnail. After: tutor-led variant for completed lessons.

- Tutor avatar → `/tutors/[tutorId]` deeplink. Profile opens with the booking CTA enabled — strongest "rebook this tutor" moment.
- "내 평가 ★…" only renders when `lesson-review.nps` exists; otherwise show "리뷰 남기기 →".
- Cancelled / no-show cards keep the cancelled style (don't lead with tutor — feels like blame).
- `ReservedLessonsSection` (upcoming) uses the same tutor-led pattern, with the rating row replaced by the existing countdown chip.
- If tutor `canUse=false` (quit), avatar deeplink shows a "더 이상 활동하지 않아요" view (booking disabled). Favorited quit-tutors stay in the favorites list with the same grayed pill — never silently removed.

---

### 3.5 — 지정튜터 티켓 purchase `/tutors/purchase-ticket`

The ticket is an **enabler**: it designates a specific tutor for a lesson the student is already entitled to via their subscription. The ticket does **not** cover the lesson itself — tutor cost is already paid for by the active subscription.

**Subscription prerequisite.** Redeeming a ticket consumes 1 lesson from the active subscription (whatever the subscription would normally entitle the user to that day — unlimited tiers are naturally capped by the existing 1-per-day rule, so the PRD does not expose a separate counter). Without an active subscription → cannot redeem (purchase still allowed with explicit warning; see below).

**Buy without active subscription.** Purchase is allowed, but the purchase page shows an explicit warning popup when:
- The user has no active subscription at all, **or**
- The user has an active subscription for a different language than the tutors they are likely to designate (e.g., EN subscription + JP tutor designation intent).

Warning copy gist: `구독이 있어야 사용할 수 있어요. (선택한 언어의) 구독을 먼저 시작해 주세요.` The user can still complete the purchase. **Expiry clock starts at purchase time** (not redemption) — same 90-day window applies whether the user has a sub or not.

**Single SKU across languages.** Tutor-cost difference no longer flows through to the SKU. EN and JP share the same price; tickets are generic and not language-locked at the SKU level.

**Multi-subscription users.** Ticket attaches to the subscription matching the **tutor's language** at redemption — no explicit user pick. A user with both EN and JP active subscriptions who designates a JP tutor automatically consumes from the JP subscription.

**Pricing — 정가 reuses the prior JP ticket-model prices as the anchor; 출시가 calibrated to ₩2,500/회 at the featured 10회 tier:**

| Pack | 정가 | 출시가 | 출시 회당 | 출시 할인 |
|---|---|---|---|---|
| 1회 | ₩7,000 | ₩3,900 | ₩3,900 | −44% |
| 5회 | ₩29,750 | ₩14,900 | ₩2,980 | −50% |
| 10회 ⭐ | ₩50,000 | ₩25,000 | **₩2,500** | −50% |
| 20회 | ₩84,000 | ₩39,900 | ₩1,995 | −52% |

The 정가 column reuses the previous JP ticket-model prices (the higher of the prior EN/JP tables). They were originally calibrated for a fully-loaded "ticket covers lesson too" model, so they map to a real reference — not a made-up premium feel. Carrying them over as the anchor maximizes the perceived discount and absorbs the per-language tutor-incentive differential into margin (see §5).

The 10회권 is the featured tier — per-회 calibrated to ₩2,500 (the "small treat" zone). Per-회 across packs ranges ₩1,995–₩3,900. Discount tapers after the launch window.

Payment via existing `PaymentGateway`. Constraints (§5):
- Generic ticket (not locked to a specific tutor) — chosen at booking time.
- 90-day expiry for purchased (clock starts at purchase); 30-day for free-seed.
- Auto-use order: earliest-expiring first.

---

### 3.6 — My-podo additions

New rows under `/my-podo`:

- `찜한 튜터` (NEW)
- `지정튜터 티켓` (NEW)
- `차단한 튜터` (existing tutor-exclusion)

#### 3.6.1 — `/my-podo/tutor-favorites`

- No cap on favorites.
- Cards show: name, rating, 함께한 N회, 이번 주 예약 가능 N건, **memo line** (italic accent) or `＋ 메모 추가` prompt when empty.
- Favoriting a blocked tutor → confirm `차단 해제하고 찜할까요?`
- Tap card → tutor profile.
- **찜 메모 (내 메모)** — private per-favorite memo (≤100 chars). Authored inline on the tutor profile (§3.3), no edit button, autosaves on blur (debounced sync while typing). Surfaced on favorites list and in the picker so users remember *why* they favorited. Never visible to the tutor or other students. Prompted at the act of favoriting (`이 튜터를 찜한 이유를 메모해보세요 (선택)`). Cleared when the favorite is removed.

#### 3.6.2 — `/my-podo/designated-tickets`

- Banner: total held + earliest expiry.
- "+ 티켓 더 구매" → §3.5.
- Sections: 보유 티켓 (purchase / free-seed entries) · 사용 내역.
- Auto-use order: earliest-expiring first — so users never lose tickets they would have used.

---

### 3.7 — 튜터 탭 (tutor-first entry) — NEW

```
튜터 탭 (GNB) → 튜터 리스트 → 튜터 프로필 → 예약 페이지 (다음 레슨 + 추천 시간 자동 채움) → confirm
```

Parallel primary entry alongside §3.0's lesson-first flow. Same confirm dialog terminates both paths. Existing lesson-first flow stays unchanged (no migration).

#### 3.7.1 — Tutor tab landing

- Language switcher tab on top: `영어` / `일본어` (defaults to user's primary learning language; only that language's tutors shown).
- Title `튜터 찾기` + sort/filter pills.
- Tutor cards (same shape as §3.2). Tapping the card body opens the profile — no separate "프로필 →" affordance.

#### 3.7.2 — Tutor profile (from tutor tab)

**Identical to §3.3.** Same 소개 / 메모 / 리뷰 / hashtag / audio bio data. Only difference is CTA destination:
- §3.3 CTA → confirm dialog (lesson + slot already chosen from picker)
- §3.7 CTA → booking page (lesson + slot not yet chosen)

The 차단 bar is present here too.

#### 3.7.3 — Booking page `/tutors/[tutorId]/book`

Reached from `이 튜터로 예약하기` on the §3.7 profile. Lesson + time picker on its own page:

- **레슨 선택** card — auto-filled with student's next unfinished lesson in their active course (caption: `· 다음 레슨이 자동 선택됐어요`). Tapping the card opens the lesson-picker slide-up (§3.7.4).
- **추천 시간** grid — 6 buttons showing this tutor's soonest open 25-min slots over ~7 days, **filtered to slots where the auto-selected lesson is actually bookable** (respects existing `LectureCommandService` course/level constraints — avoids "tap recommended slot → error: this tutor can't teach this lesson"). Caption: `레슨 일정을 선택해 주세요.` "다른 시간 보기" button below.
- **예약 확정** sticky CTA — disabled until a time is chosen.

**Two paths to choose a time:**

1. **Recommended slot picked from grid** — tapped slot highlights (primary border + soft fill); CTA enables.
2. **"다른 시간 보기" → full schedule sheet** — slide-up over the booking page:
   - Header `레슨 일정을 선택해주세요.`
   - Date strip (오늘 / 내일 / 요일 + day-of-month), date chip active state
   - `예약 가능 시간 · ● 예약 마감` subhead with legend
   - 오전 group / 오후 group with `wf-slot` cells (white = available, grey = `예약 마감`)
   - `확인` primary button
   - Picking a date+time and tapping 확인 closes the sheet. The booking page now replaces the 추천 시간 grid with a **선택된 레슨 일정** card (primary-soft box showing the chosen time + `날짜 변경` button below).

**예약 확정 → confirm dialog** — same `wf-dialog` component used by §3.1/§3.2/§3.3. Tutor is locked (no 변경) since the user entered through the tutor profile. Rows: 레슨명 / 레슨 일정 / 튜터 + ticket-usage info note + 취소 / 예약하기 buttons.

#### 3.7.4 — Lesson picker (nested slide-up on booking page)

Tap the 레슨 선택 card → slide-up over the booking page.

- **State A — Lessons within current course:** header has `←` arrow + course title (e.g., `Level 1`). List of lessons; current lesson selected (✓). Completed lessons marked with a `완료` pill (no strikethrough — the pill alone is enough).
- **State B — Courses list:** opened by tapping the `←` arrow in State A. Lists all available courses with colored thumbnails (Start 1 / Start 2 / Level 1 ✓ / Level 2 / Level 3 …). The active course gets a ✓.
- Two states share the same sheet component.

#### 3.7.5 — Behavior notes (§3.7)


- **GNB placement** — 튜터 탭 sits between 레슨 and 예약. Parallel entry, no migration.
- **Profile reuse** — identical to §3.3 down to the wireframe. Only the CTA destination differs.
- **Booking page lesson default** — active course's next unfinished lesson. Users without an active course see the courses-list slide-up first (`코스를 선택해 주세요` placeholder).
- **추천 시간 source** — this tutor's next 6 open 25-min slots over ~7 days, soonest first, filtered for lesson-compatibility (see above). If all closed: "이번 주 가능 시간 없음" + "다른 시간 보기" fallback.
- **Language switcher** — defaults to user's primary learning language; selected language gates the visible tutors.
- **Slide-up nesting** — courses picker ↔ in-course lesson list. Same sheet component.
- **예약 확정 CTA** — disabled on entry; activates when a slot is chosen (either path); tap opens confirm dialog.
- **Popular tutor scarcity** — optional caption on 추천 시간 grid: "인기 튜터의 시간은 빠르게 마감돼요." On conflict (slot disappears between view and confirm), graceful toast suggests adjacent slots (same pattern as §3.3).

---

### 3.8 — Lesson NPS — favorite / block opt-ins — NEW

```
레슨 완료 → 별점 → (4–5★ 긍정 / 3★ 중립 / 1–2★ 부정으로 분기) → 피드백 chips → 제출 완료
```

Post-lesson rating. Three-way branch:
- **4–5★** → positive flow → `이 튜터를 찜한 튜터에 추가할게요.` opt-in on the completion screen (NEW).
- **3★** → neutral flow → feedback chips collected, **no 찜/차단 opt-in shown** (avoids pushing "just OK" users to block tutors and erode supply).
- **1–2★** → negative flow → existing `이번 튜터와 다시 레슨하지 않을래요.` opt-in that maps to `tutor-exclusion`.

Star rating still feeds the public review aggregation (§3.3 Option A) regardless of branch.

#### 3.8.1 — Positive flow (4–5★)

**Step 1 — Star rating**

```
┌────────────────────────────────────────┐
│       이번 레슨, 어떠셨나요?            │
│   솔직한 평가는 더 좋은 레슨을…         │
│                                        │
│   [ A ] Alice                          │
│         4월 26일 11:00                 │
│                                        │
│     ★  ★  ★  ★  ☆                    │
│                                        │
│        ┌────────────────┐              │
│        │      다음       │              │
│        └────────────────┘              │
│       평가하지 않고 나가기              │
└────────────────────────────────────────┘
```

**Step 2 — Positive feedback chips** — `어떤 점이 특히 좋았나요?` Multi-select chips (e.g., 자연스러운 대화 속도 · 꼼꼼한 문법 교정 · 정확한 발음 교정 · 새로운 표현 학습 · 활기차고 재미있는 수업 · 친절하고 상냥한 태도 · 그 외 다른 의견) + free-text input. `제출하기` button.

**Step 3 — Completion + 찜 opt-in (NEW)**

```
┌────────────────────────────────────────┐
│                                        │
│           피드백 제출 완료             │
│   소중한 의견 감사해요!                │
│   튜터에게 전달되어 큰 힘이 돼요.      │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ ◯ 이 튜터를 찜한 튜터에 추가할게요.│  │  ← NEW row
│  └──────────────────────────────────┘  │
│                                        │
│        ┌────────────────┐              │
│        │      확인       │              │
│        └────────────────┘              │
└────────────────────────────────────────┘
```

The 찜 opt-in row uses the same visual pattern as the existing 차단 opt-in (light grey rounded container with circle indicator + statement). Hidden when already favorited (or already blocked — favorites and blocks are mutually exclusive, §3.6).

#### 3.8.2 — Neutral flow (3★)

Star + chips submission unchanged from the negative flow shape (chips below); completion screen omits both the 찜 and 차단 opt-in rows. Otherwise identical funnel.

#### 3.8.3 — Negative flow (1–2★)

**Step 1 — Star rating** (2★ shown) — same screen as positive, fewer stars filled.

**Step 2 — Negative feedback chips** — `아쉬웠던 점을 알려주세요.` Chips: 과도한 한국어 사용 · 이해하기 어려운 발음 · 레슨 시간 미준수 · 부정확한 레슨 내용 · 튜터 측 소음 발생 · 불성실한 수업 태도 · 부족한 피드백과 교정 · 재미없는 레슨 주제 · 그 외 다른 의견 + free-text input + `제출하기`.

**Step 3 — Completion + 차단 opt-in (existing)**

```
┌────────────────────────────────────────┐
│                                        │
│           피드백 제출 완료             │
│   솔직한 피드백 감사해요!              │
│   개선하여 더 좋은 수업으로 보답할게요. │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ ◯ 이번 튜터와 다시 레슨하지 않을래요.│  │  ← existing
│  └──────────────────────────────────┘  │
│                                        │
│        ┌────────────────┐              │
│        │      확인       │              │
│        └────────────────┘              │
└────────────────────────────────────────┘
```

#### 3.8.4 — Behavior notes (§3.8)

- **Branch thresholds** — 4–5★ → positive, 3★ → neutral, 1–2★ → negative. Two constants, tunable in one place.
- **찜 opt-in (NEW)** — only on positive (4–5★) completion. Pre-checked **false**; explicit opt-in. Hidden if tutor is already favorited or already blocked. Does **not** capture a memo at this moment — memo is profile-only (see §3.3).
- **차단 opt-in (existing)** — only on negative (1–2★) completion. Maps to existing `tutor-exclusion` add. Hidden if already blocked. If currently favorited, checking it prompts `찜 해제하고 차단할까요?` (same confirm as §3.3 차단 bar).
- **Neutral (3★) completion** — chips + optional free text are saved; no opt-in row appears.
- **Submission timing** — `제출하기` writes the NPS row + chips + optional free text. The 찜 / 차단 opt-in fires on the completion screen's `확인` tap — not on chip submission — so the user can review the choice without prematurely committing.
- **"평가하지 않고 나가기"** — preserved on Step 1 and Step 2. Exits the funnel without writing NPS and without showing the 찜/차단 opt-in.
- **NPS source for public reviews** — star rating still feeds §3.3's public aggregate (Option A). Free text only becomes public if a separate opt-in is added later (Phase 3 / Option B).
- **Entry points** — surfaced after lesson end (existing trigger). Also reachable via the `리뷰 남기기 →` CTA on past-lesson cards (§3.4) when NPS was skipped.

---

## 4. Rollout & seeding policies

Two levers, sequential: **(a) who gets access**, **(b) how they get their first ticket**.

### 4.1 — Heavy-user gate

Feature flag limited to students with **10+ completed lessons**. They have real tutor preferences and proven willingness to pay.

### 4.2 — Free seeding tickets

Grant **3 free tickets** on first picker entry. 30-day expiry. Removes the "try before buy" friction.

### 4.3 — Recommended sequencing

| Stage | What's on | Gate |
|---|---|---|
| 1 | Heavy-user gate (10+ lessons) + 3 seed tickets | Repurchase rate? |
| 2 | Open to 50% of subscribers | Holds at scale? |
| 3 | GA | — |

Implemented as a single feature flag `TBD_2606_DESIGNATED_TUTOR` with GrowthBook **cohort assignment** (`heavy_user` → `50pct_subs` → `ga`). One kill-switch; stages roll by cohort expansion, not by adding new flags.

Each stage is a kill-switch — bad metric → roll back, don't absorb.

> **Compensation tickets for skip days** — deferred out of v1. Considered but explicitly excluded to keep launch scope tight; revisit after Stage 2 metrics.

---

## 5. Policies

| Policy | Owner | Recommended default |
|---|---|---|
| **Tickets** | | |
| Pricing | PM + Finance | Single SKU for EN+JP. 정가 ₩7,000–₩84,000 (reuses prior JP ticket-model prices as anchor) · 출시가 ₩3,900–₩39,900 (~50% off, 10회 calibrated to ₩2,500/회, see §3.5) |
| Tutor-side incentive | PM + Finance | Scaled by language base cost (JP > EN). Absorbed into internal margin at launch — JP designations carry thinner margin than EN. Ship as-is; revisit in post-launch retro (no fixed numeric trigger in v1). |
| Expiration | PM + Finance | Purchased 90d (clock starts at purchase, **not** redemption) · Free seed 30d |
| Auto-use order | PM | Earliest-expiring first |
| Refund | PM + Finance | Purchased: full refund on unused. Free: non-refundable. **On booking cancellation / no-show / tutor cancel**: mirrors existing `useLessonPenalty` rules (inside penalty window → ticket lost; outside → ticket returns to wallet; tutor-side cancel → ticket always returns). |
| Promo stacking | Finance | Launch discount excluded from further promos; post-launch combined ≤ −15% off per-회 |
| Subscription gate to **buy** | PM | None — anyone can buy. Purchase page shows an **explicit warning popup** when the buyer has no active subscription, or has an active subscription for a different language than the likely-designated tutor (e.g., EN sub + JP tutor intent). |
| Subscription gate to **redeem** | PM | Active subscription required. Ticket attaches to the subscription matching the **tutor's language** at redemption (no explicit user pick for multi-sub users). Consumes 1 lesson from that subscription's daily entitlement; unlimited tiers are naturally bounded by the existing 1-per-day rule. |
| Language lock | PM | None at SKU level — tickets are generic; the redemption language is inferred from the tutor. |
| **Free tickets** | | |
| Free seed grant | PM | 3 tickets on first picker entry, 30d expiry |
| Compensation (skip-day) tickets | PM | **Deferred out of v1.** Considered but explicitly excluded; revisit after Stage 2. |
| **Rollout** | | |
| Heavy-user gate | PM | Open to students with **10+ completed lessons** first |
| Flag structure | PM | Single feature flag `TBD_2606_DESIGNATED_TUTOR` + GrowthBook cohort assignment (heavy_user → 50pct_subs → ga). One kill-switch. |
| **Tutor surface** | | |
| Favorites cap | PM | No cap |
| Favorite memo | PM | Private (visible to author only), ≤100 chars, optional, cleared on unfavorite. **Authored only on the tutor profile** — never auto-prompted at favoriting or NPS opt-in. |
| Search filters | PM | 한국어 가능 toggle + scope chips (전체 튜터 default / 함께한 적 있는 / 찜한 튜터만). 국적 · 성별 필터 없음 (차별 소지 방지) |
| Picker sort options | PM | 평점 높은 순 (default) · 리뷰 많은 순 · 함께한 횟수 많은 순 (per-current-user). No "신규 튜터" sort. |
| Hashtag taxonomy | PM + Tutor Ops | Controlled vocabulary, multi-select from preset list (~30 curated tags per language). Free-text not allowed at the tutor side. |
| NEW badge | PM | Tutor hired < 30 days ago. `Tutor.hireDate` backfilled from earliest GT_CLASS taught date (existing tutors will not show NEW after launch). |
| POPULAR badge | PM | Top ~10% of tutors by **user-favorites count** (per language), recomputed daily. |
| "신규" rating | PM | Show "신규" instead of "0.0" until review count ≥ 5 |
| 휴식 중 tutor visibility | PM | Hidden from picker; kept in favorites with 휴식 중 pill |
| Quit tutor (`canUse=false`) visibility | PM | Hidden from picker. Kept in favorites with grayed `더 이상 활동하지 않아요` pill — never silently removed. Profile is view-only. |
| Non-subscriber access | PM | Tutor tab + profiles + audio bio are browsable freely. Booking CTA prompts subscription if no active sub. |
| **Reviews** | | |
| Review source | PM + T&S | Existing post-lesson NPS rating + opt-in free text. NPS branches: 4–5★ positive (찜 opt-in), 3★ neutral (no opt-in), 1–2★ negative (차단 opt-in). |
| Audio bio moderation | Tutor Ops | Tutor self-record + admin review. Audio player is **hidden entirely** on the profile until approved (no placeholder, no half-state). |
| **Migration** | | |
| Existing `le_tutor_exclusion` users | PM | No migration, no in-app announcement. Mutual-exclusion logic ensures existing blocks co-exist with new favorites cleanly. |

---

## 6. Backend changes (high-level, mapped to existing repo)

| Area | Change |
|---|---|
| `applications/user/domain/Tutor.java` | New fields: `audioIntroUrl`, `audioIntroDuration`, `hireDate`. Existing `hashTag`, `tutorIntro`, `youtube` reused. |
| `applications/podo/favorite/**` (new) | Mirror of `applications/podo/exclusion/**`: `TutorFavorite` entity, service, controller. Table `le_tutor_favorite (student_id, tutor_id, note, created_at)`. Note column ≤100 chars. |
| `applications/podo/schedule/**` | New query: tutors available for `class_id + date + time`. Plus favorited-count aggregator. Plus per-tutor "recommended 6" endpoint for the §3.7 booking page. |
| `applications/lecture/service/command/LectureCommandService` | Add `registerWithDesignatedTutor(classId, tutorId, ticketId)` path. Validates ticket ownership & remaining count, then `ScheduleTimeBlock.studentId = userId` for that tutor's slot. |
| `applications/ticket/**` (new) | `DesignatedTutorTicket` entity + service. SKU registry, purchase via `PaymentGateway`. Source-tagged (purchase / free-seed) for analytics — compensation source reserved for v1.1. Auto-use earliest-expiring first. |
| `applications/podo/nps/**` | Extend NPS submit DTO with optional `freeText` + `isPublic`. New query: aggregate rating + recent public reviews per tutor. |
| `applications/podo/exclusion/usecase/TutorExclusionService` | On block → also remove favorite (and vice versa). |
| `grape/admin/**` | Tutor profile editor (audio upload, hashtag editor, bio cap). Review moderation table (defer until Option B is chosen). |

---

## 7. Web changes (mapped to `apps/web/src`)

```
NEW
src/entities/tutor/
src/entities/tutor-favorite/                   ← includes note field
src/entities/designated-ticket/
src/entities/tutor-review/

src/features/tutor-search/
src/features/tutor-favorite/                   ← memo autosave (debounced)
src/features/designated-ticket-purchase/
src/features/tutor-picker/                     ← bottom sheet shared by §3.2 / dialog
src/features/audio-bio-player/

src/views/tutor-search/                        ← powers /tutors + 튜터 tab landing
src/views/tutor-profile/                       ← §3.3 + §3.7.2 (identical render)
src/views/tutor-reviews/
src/views/tutor-book/                          ← NEW §3.7.3 booking page
src/views/designated-tickets/
src/views/tutor-favorites/

src/app/(internal)/tutors/page.tsx
src/app/(internal)/tutors/[tutorId]/page.tsx
src/app/(internal)/tutors/[tutorId]/book/page.tsx     ← NEW (§3.7)
src/app/(internal)/tutors/[tutorId]/reviews/page.tsx
src/app/(internal)/tutors/purchase-ticket/page.tsx
src/app/(internal)/my-podo/tutor-favorites/page.tsx
src/app/(internal)/my-podo/designated-tickets/page.tsx

MODIFIED
src/widgets/gnb/                                ← add 튜터 tab between 레슨 and 예약
src/views/booking/view.tsx                     ← favorite-border slot tint
src/views/booking/ui/booking-confirm-dialog.tsx← 튜터 row (랜덤 배정 / chosen)
src/widgets/completed-lessons/ui/*             ← tutor-led card variant
src/widgets/reserved-lessons/ui/*              ← tutor avatar lead-in
src/features/lesson-review/ui/nps-survey/*     ← "공개 리뷰로 등록" checkbox
```

---

## 8. Things to watch (not in user brief but matter)

1. **Audio bio recording UX** — tutors self-record in `apps/tutor-web`, capped at 30 sec, admin moderation hold before going live. Player is hidden entirely on student-facing profiles until approved (no "coming soon" placeholder).
2. **Tutor capacity guard** — when a popular tutor's grid is mostly closed, prompt "favorite a backup too" + suggest similar tutors on profile. When a slot is consumed by a designated booking and the random pool drops to 0, the slot displays as 마감 to non-designated users (existing 0-cnt behavior — no separate "designated only" state).
3. **Favorite ↔ block conflict** — bidirectional clear on either action (mirrored behavior copy in §3.3 and §3.6).
4. **Lesson cancellation / penalty** — designated-tutor bookings follow the same `useLessonPenalty` rules as today; ticket return follows the same window (see §5 Refund row).
5. **Subscription co-existence** — when both exist, picker defaults to 지정튜터 티켓 only when a tutor is explicitly chosen; otherwise subscription stays default so users don't burn a ticket on random matching. **Multi-sub users**: redemption language is inferred from the tutor — no explicit pick.
6. **Tutor quits while favorited** — tickets are generic, so no refund logic needed for tutor inactivity. Favorite entries are kept with a grayed `더 이상 활동하지 않아요` pill (never silently removed).
7. **Notification when favorite tutor opens a slot** — strong retention lever; **confirmed for v1.1, not v1**. Needs opt-in flow + rate-limit policy + delivery infra; better as a fast follow once we see favorite-list adoption.
8. **`realName` privacy** — never leak `GT_TUTOR.realName` to any student-facing API. Add a test guard (integration test asserting `realName` is absent from all `(internal)/tutors/**` and `(internal)/booking/**` response bodies).
9. **Schedule API payload size** — aggregated favorite-count for the grid; full tutor list lazy-loaded on slot tap; tutor-specific "recommended 6" is its own endpoint, **filtered for lesson-compatibility** (§3.7.3) at query time.
10. **Already-booked → designated upgrade** — explicitly **out of v1 scope**. To designate a tutor for a future random-matched booking, users must cancel and re-book. May surface as CS feedback; revisit for v1.1 alongside the slot-open notification.
11. **Analytics** (extend existing `ANALYTICS_EVENTS`):
    - `tutor_search_viewed`, `tutor_search_filtered { sort, filters }`
    - `tutor_profile_viewed { tutorId, source }` — `source` distinguishes lesson-first vs. tutor-tab vs. past-lesson-card entry
    - `tutor_audio_played { tutorId, duration_played }` (duration_played in ms)
    - `tutor_favorited` / `tutor_unfavorited { tutorId, source }`, `tutor_memo_edited { tutorId, length }`
    - `tutor_blocked` / `tutor_unblocked { tutorId, source }`
    - `designated_ticket_purchase_viewed`, `designated_ticket_purchased { sku, amount, source, hadActiveSub: bool, languageMismatchWarned: bool }`
    - `tutor_tab_viewed { language }`, `tutor_book_page_viewed { tutorId, lessonDefaulted }`
    - `tutor_book_slot_picked { source: grid | sheet }`, `designated_booking_completed { tutorId, ticketId, source, subLanguage }`
12. **Cross-platform parity** — `apps/native` consumes the same Next.js webview. Browser MediaRecorder is fine for the v1 audio recorder.
13. **A/B & rollout** — single feature flag `TBD_2606_DESIGNATED_TUTOR` + GrowthBook cohort assignment (heavy_user → 50pct_subs → ga). Primary KPI: `tutor_profile_viewed`-to-`designated_ticket_purchased` funnel.

---

## 9. Definition of done (v1)

- A user with no past lessons can: open 튜터 탭 → tap a card → land on profile → listen to bio → write a memo → tap CTA → land on booking page with next lesson auto-filled and recommended times → pick a time (either path) → confirm → see the booked tutor on `/reservation`.
- The lesson-first flow: pick lesson → tap a slot → in the confirm dialog tap `튜터 선택 ›` → pick a tutor → confirm.
- A user with past lessons sees the new tutor-led card on `/reservation`, with their own star rating shown when a review exists.
- Existing booking flow (no tutor picked, no ticket) is unchanged for users not in the rollout.
- All new endpoints behind `TBD_2606_DESIGNATED_TUTOR` flag.
- `Tutor.realName` does not appear in any student-facing response (test enforced).
- `le_tutor_favorite` ↔ `le_tutor_exclusion` are mutually exclusive (test enforced); `note` cleared on unfavorite.
- Memo never appears in any tutor-facing or third-party-student-facing response (test enforced).

---

*End of v0.1 draft. Next: PM + design review · Figma hi-fi.*
