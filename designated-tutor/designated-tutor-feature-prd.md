# Designated Tutor (지정튜터) Feature — PRD & Wireframes

**Status:** Draft v0.1 · 2026-05-12
**Author:** podo@day1company.co.kr
**Working repo:** `personal_prd`
**Touch repos:** `podo-app` (web/native), `podo-backend`, `grape` (admin)

---

## 1. Goal

Let students browse, favorite, and book classes with specific PODO tutors they like — parallel to (not replacing) the current subscription-based "any available tutor" booking flow.

The current product matches students to **any** available tutor on a chosen time slot (`ScheduleTimeBlock` aggregated by `cnt` per time). Today, students can only **exclude** tutors via `le_tutor_exclusion` (max-N blocklist) — there is **no** way to actively pick or favorite a tutor, and **no** public tutor profile.

This PRD introduces the inverse: discovery (profile + search), preference (favorites), commerce (지정튜터 티켓), and a tutor-aware booking flow.

---

## 2. Scope summary (what user asked for, mapped to existing code)

| # | User ask | Existing surface to extend | New surface |
|---|---|---|---|
| 1 | Tutor profile page | `GT_TUTOR` (name, hashTag, profileLargeImage, tutorIntro, youtube, badge, education) | `/tutors/[tutorId]` route, audio bio field, public review aggregation |
| 2 | Tutor search page | `applications/user/service/UserInfoService` (admin-side tutor listing) | `/tutors` route with sort/filter/search |
| 3 | "지정튜터 티켓" purchase | `Subscribe` / `SubscribeMapp` / payment flow under `features/payment` | New ticket SKU + `le_designated_tutor_ticket` table + `/my-podo/designated-tickets` |
| 4 | Booking screen tutor choice | `views/booking/view.tsx` + `useSchedule` (aggregated `cnt`) | Per-slot tutor-list endpoint + favorites toggle + tutor picker sheet |
| 5 | Past lesson cards lead with tutor | `widgets/completed-lessons` `RegularLessonCard` (leads with level thumbnail) | Tutor-led card variant with your given rating + profile deeplink |

A 6th surface required to make all of this work but **not** in user's brief:
**(6) Favorites system** (`le_tutor_favorite`) — the inverse of `le_tutor_exclusion`. Needed by surfaces 1, 2, 3, 4.

---

## 3. Information architecture

```
Existing
├── /home
├── /booking?classId=…&type=new                ← MODIFIED (surface 4)
├── /reservation                                ← MODIFIED (surface 5)
│   ├── ReservedLessonsSection
│   └── CompletedLessonsSection
└── /my-podo
    ├── /plan
    ├── /coupon
    ├── /payment-methods
    ├── /tutor-exclusion                        ← inverse already exists
    └── …

NEW
├── /tutors                                     ← surface 2 (search/list)
├── /tutors/[tutorId]                           ← surface 1 (profile)
├── /tutors/purchase-ticket                     ← surface 3 (buy 지정튜터 ticket)
└── /my-podo
    ├── /tutor-favorites                        ← surface 6 (favorites list)
    └── /designated-tickets                     ← surface 3 (owned tickets, history)
```

Entry points to the new surfaces (so the feature is discoverable):
- Home: banner card "지정튜터로 예약해보세요"
- Booking screen: top-right "찜한 튜터만" toggle + "지정튜터로 예약하기" CTA
- Past lesson NPS card: "이 튜터 프로필 보기" deeplink
- Reservation tab card: tap tutor name/avatar → profile
- My-podo: 찜한 튜터, 지정튜터 티켓 menu rows
- Tutor profile: "이 튜터로 예약하기" → triggers ticket-purchase or designated-booking flow

---

## 4. Wireframes

> All wireframes are mobile-first (375px viewport). Native/PWA share the same routes via `apps/web`. Korean copy assumed; the existing translation pipeline (`apps/web/src/i18n`) handles JP/EN later.

### 4.1 — Tutor search/list `/tutors`

```
┌────────────────────────────────────────┐
│ ←   튜터 찾기                    🔍 ⓘ │  ← header (back, title, search-icon, info)
├────────────────────────────────────────┤
│ [🔎 튜터 이름 검색…                  ] │  ← search bar
├────────────────────────────────────────┤
│ ⌄ 정렬: 평점 높은 순     [필터 2 ●]    │  ← sort + filter chips drawer
├────────────────────────────────────────┤
│ ┌──────────────────────────────────┐  │
│ │ ◯ ★ ★ ★ ★ ★ 4.9 (312)             │  │  ← tutor card
│ │ 사진      Jenny       🇵🇭 한국어 ◎  │  │
│ │           #발음교정 #초보환영      │  │
│ │           ▶ 30초 자기소개          │  │  ← audio play button
│ │                              ♡ 찜  │  │
│ └──────────────────────────────────┘  │
│ ┌──────────────────────────────────┐  │
│ │ ◯  Mark      🇵🇭     ★ 4.8 (201) │  │
│ │   #비즈니스 #프리토킹              │  │
│ │   ▶ 25초 자기소개            ♥ 찜됨│  │
│ └──────────────────────────────────┘  │
│         …  infinite scroll  …          │
└────────────────────────────────────────┘
```

**Sort options** (single-select pill):
`평점 높은 순` (default) · `리뷰 많은 순` · `신규 튜터` · `함께한 횟수 많은 순` (only if user has lessons)

**Filter sheet** (multi-select):
- 언어: 한국어 가능 / 영어만
- 국적: 🇵🇭 필리핀 / 🇺🇸 미국 / 🇿🇦 남아공 / …
- 성별: 여성 / 남성
- 함께한 적 있는 튜터만 (toggle)
- 찜한 튜터만 (toggle)
- 지금 예약 가능 (≤7일 내 빈 슬롯 있음)

**Empty / edge states:**
- No results → "검색어와 일치하는 튜터가 없어요" + suggest clearing filters.
- Tutor `canUse=false` or `canTakeClass=false` → hidden from list.
- Tutor `classPause=true` → grayed-out card with "휴식 중" badge.

---

### 4.2 — Tutor profile `/tutors/[tutorId]`

```
┌────────────────────────────────────────┐
│ ←                                ♡  ⋮  │
├────────────────────────────────────────┤
│                                        │
│           ┌──────────┐                 │
│           │ profile  │   ★ 4.9         │
│           │   ↻ 360  │   312개의 리뷰  │
│           └──────────┘                 │
│                                        │
│              Jenny  🇵🇭                │
│         5년차 · 한국어 가능             │
│                                        │
│      ▶  30초 자기소개  ━━━━●─── 0:18   │  ← audio player
│                                        │
│  #발음교정 #초보환영 #친절 #문법강함   │
├────────────────────────────────────────┤
│  소개                                  │
│  안녕하세요! 저는 5년 동안 한국 학생…  │
│  …더보기                                │
├────────────────────────────────────────┤
│  학력 · 경력                           │
│  • University of the Philippines       │
│  • TESOL Certified                     │
│  • 과거 SK텔레콤 비즈니스 영어 강사    │
├────────────────────────────────────────┤
│  나와 함께한 레슨    7회 · 평균 ★ 4.7  │  ← only if classCount > 0
├────────────────────────────────────────┤
│  학생 리뷰  312개            전체 보기→│
│  ┌──────────────────────────────────┐  │
│  │ ★★★★★  김** · 2026-04-21         │  │
│  │ 발음 교정이 정말 꼼꼼해요. 다음에…│  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │ ★★★★☆  이** · 2026-04-18         │  │
│  │ 친절하고 차분해서 처음이어도…    │  │
│  └──────────────────────────────────┘  │
├────────────────────────────────────────┤
│  이번 주 예약 가능 시간                │
│  월 5/13   ●●○○●●●○○○○○ (4)         │  ← dot grid; tap → opens picker
│  화 5/14   ●○○●●●○○○○○○ (5)         │
│  …                                     │
├────────────────────────────────────────┤
│ ╔══════════════════════════════════╗   │ ← sticky bottom bar
│ ║   이 튜터로 예약하기              ║   │
│ ╚══════════════════════════════════╝   │
└────────────────────────────────────────┘
```

**Field source mapping:**
| UI | Backend field |
|---|---|
| Avatar / 360 | `Tutor.profileLargeImage` (+ new `profile_video_url`) |
| Name | `Tutor.name` (display) — never expose `realName` |
| Country flag | `Tutor.country` (`CountryType`) |
| Years | derived from `Tutor.hireDate` (new) |
| 한국어 가능 | `Tutor.koreanAvailable` |
| Audio | **new** `Tutor.audioIntroUrl` + `audioIntroDuration` |
| Hashtags | `Tutor.hashTag` (already a Collection<String>) |
| 소개 (bio) | `Tutor.tutorIntro` (already exists) + **new** longer bio? Reuse `tutorIntro` and expand char limit. |
| Education / 경력 | `Tutor.education`, `Tutor.workExperience` |
| 나와 함께한 레슨 | `lecture` table filtered by `student_id` + `tutor_id` + invoice_status complete |
| 리뷰 | **new** `le_tutor_review` (sourced from NPS rating + optional free-text) |
| 예약 가능 시간 | `ScheduleTimeBlock` where `tutor_id=…` and `student_id IS NULL` |

**Top-right ⋮ menu:** 신고하기, 차단하기 (→ `tutor-exclusion`). Blocking auto-removes the favorite.

**Sticky CTA logic** (matrix):
| User state | CTA |
|---|---|
| Has 지정튜터 ticket ≥ 1 | "이 튜터로 예약하기" → ticket-aware booking |
| No ticket, has subscription | "이 튜터로 예약하기" → ticket purchase sheet |
| No ticket, no subscription | "구독 시작하기" (deflect to existing funnel) |
| Tutor blocked/paused | CTA disabled, replaced with status pill |

---

### 4.3 — Reviews full view `/tutors/[tutorId]/reviews`

```
┌────────────────────────────────────────┐
│ ←  Jenny의 리뷰 (312)            ⌄정렬 │
├────────────────────────────────────────┤
│         ★ 4.9 / 5.0                    │
│  ★★★★★ ████████████████  82%          │
│  ★★★★☆ ████              13%          │
│  ★★★☆☆ █                  3%          │
│  ★★☆☆☆ ▎                  1%          │
│  ★☆☆☆☆ ▎                  1%          │
├────────────────────────────────────────┤
│  필터: 전체 | 5점 | 4점 | …             │
├────────────────────────────────────────┤
│  ★★★★★  김**                          │
│  2026-04-21 · 발음 레슨               │
│  발음 교정이 정말 꼼꼼해요…           │
│  👍 12 · 도움이 됐어요                  │
├────────────────────────────────────────┤
│  …                                     │
└────────────────────────────────────────┘
```

**Review data source decision (needs alignment):**

Today, `lesson-review` collects a 1–5 NPS rating tied to `classId + tutorId` and stores it privately. To populate public reviews, we have **two options**:

- **Option A (lean):** Aggregate existing NPS scores as public star average; show free-text only when student opts in (new checkbox on NPS submission: "다른 학생들에게 이 리뷰를 공개할게요"). Lower content volume early, but no moderation risk.
- **Option B (rich):** Add a separate "튜터 리뷰" step in lesson-review funnel, mandatory star + optional text, default-public with student opt-out. Higher volume, needs moderation pipeline (admin in `grape`).

**Recommend Option A for v1** → reuse existing NPS as the rating source, add opt-in field. Saves a moderation system from being built before we know if students will write reviews.

---

### 4.4 — Booking screen `/booking?classId=…` — MODIFIED

```
Before                                After (변경된 부분에 ●)
┌────────────────────────────────────┐  ┌────────────────────────────────────┐
│ ← 레슨 예약                        │  │ ← 레슨 예약       ● 찜한 튜터만 ⓘ ◎│
├────────────────────────────────────┤  ├────────────────────────────────────┤
│ [날짜 칩 칩 칩 칩 ─ ─ ─ ─]          │  │ [날짜 칩 칩 칩 칩 ─ ─ ─ ─]          │
├────────────────────────────────────┤  ├────────────────────────────────────┤
│ 오전                               │  │ 오전        ● (찜 토글 ON일 때만)  │
│ 09:00  09:30  10:00                │  │ 09:00 ♥3   09:30 ♥1   10:00 ♥0 ✕  │
│ 10:30  11:00  11:30                │  │ 10:30 ♥0✕  11:00 ♥2   11:30 ♥0 ✕  │
│ 오후                               │  │ 오후                                │
│ …                                  │  │ …                                  │
└────────────────────────────────────┘  └────────────────────────────────────┘
```

**Toggle behavior — top right:**
- Off (default): identical to today. Aggregated `cnt` per slot, slot tap opens existing `BookingConfirmDialog`.
- On: each slot shows a heart-count ♥N = number of **favorited** tutors with availability at that slot. Slots with ♥0 are dimmed (still tappable — will fall through to any-tutor matching) or disabled, depending on this decision:

> **Open question A — fallback semantics when toggle is on.** Should ♥0 slots be hidden, dimmed-but-tappable (matches any tutor), or hard-disabled? Recommend **dimmed + tappable with toast confirmation** ("찜한 튜터 없음. 다른 튜터로 진행할까요?") so the toggle doesn't sandbox the user.

**Slot tap when toggle is ON → tutor picker sheet** (replaces `BookingConfirmDialog`):

```
┌────────────────────────────────────────┐
│              ─────                     │
│  10:00 화 5/14  ✕                      │
│  찜한 튜터 중 가능한 분                │
├────────────────────────────────────────┤
│ ┌──────────────────────────────────┐  │
│ │ ◯  Jenny  ★ 4.9                  │  │
│ │    함께한 레슨 7회 · 한국어 가능 │  │
│ │                       [선택]      │  │
│ └──────────────────────────────────┘  │
│ ┌──────────────────────────────────┐  │
│ │ ◯  Mark   ★ 4.7                  │  │
│ │    함께한 레슨 2회               │  │
│ │                       [선택]      │  │
│ └──────────────────────────────────┘  │
├────────────────────────────────────────┤
│ ▢ 지정 안 함 (랜덤 매칭)               │  ← optional escape hatch
├────────────────────────────────────────┤
│ 사용할 티켓                            │
│ ◉ 지정튜터 티켓  (3장 남음)            │
│ ○ 구독 1일 1회 · 오늘 사용 가능        │
└────────────────────────────────────────┘
```

**Alternative the user proposed** ("button inside the existing confirm dialog instead of a toggle"): supported as a **secondary** action on the booking confirm dialog for users who didn't pre-toggle:

```
┌────────────────────────────────────────┐
│ 레슨 일정 확인                     ✕   │
│                                        │
│  레슨명   비즈니스 영어 Lv.3            │
│  레슨 일정 5월 14일(화) 10:00~10:25     │
│                                        │
│  [튜터 선택하기 →]                     │  ← NEW row when user has tickets/favorites
│                                        │
│   [취소]            [예약하기]          │
└────────────────────────────────────────┘
```

> **Open question B — pick one or both?** The toggle is more discoverable; the button is less intrusive for users who don't care. Recommend **shipping both** behind a single feature flag — top toggle for power users, in-dialog button as a fallback path. Cost is small because both surfaces share the same `TutorPickerSheet` component.

**Per-slot tutor count source:** `ScheduleTimeBlock` already stores `tutor_id`. New endpoint:

```
GET /api/v3/podo/schedule/{classId}/tutors?date=…&time=…
→ [{ tutorId, name, profileImage, rating, lessonsWithMe, isFavorite }]
```

A separate aggregated endpoint feeds the heart count without revealing individual tutors (privacy + payload size):

```
GET /api/v3/podo/schedule/{classId}/favorite-counts?date=…
→ { "09:00": 3, "09:30": 1, … }
```

---

### 4.5 — Past lessons (예약 tab) `/reservation` — MODIFIED

Today: `RegularLessonCard` leads with the **course thumbnail** and level.
After: tutor-led variant for completed lessons.

```
Before                                After
┌────────────────────────────────────┐  ┌────────────────────────────────────┐
│ [thumb] Lv.3 비즈니스 영어         │  │  ◯  Jenny  🇵🇭                     │
│         5월 12일(화) 10:00         │  │      Lv.3 비즈니스 영어            │
│         튜터 Jenny                 │  │      5월 12일(화) 10:00            │
│         [복습하기] [리포트]        │  │      내 평가  ★★★★★               │
│                                    │  │      [복습하기]  [리포트]          │
│                                    │  │      [튜터 프로필 →]               │
└────────────────────────────────────┘  └────────────────────────────────────┘
```

**Rules / edge cases:**
- Tutor avatar → `/tutors/[tutorId]` (deeplink).
- "내 평가 ★…" only renders if `lesson-review.nps` exists for the class; otherwise show "리뷰 남기기 →".
- Lessons with `invoice_status ∈ HIDE_CANCEL_INVOICE_STATUS` already hidden by today's toggle — preserve.
- Cancelled/no-show lessons keep the cancelled card style (don't lead with tutor — feels like blame).
- If tutor `canUse=false` (quit/deleted), avatar deeplink shows a "더 이상 활동하지 않는 튜터예요" view instead of profile.

`ReservedLessonsSection` (upcoming) cards: same tutor-led pattern, but rating row is replaced by countdown chip (existing `MORE_THAN_ONE_DAY` / `MORE_THAN_ONE_HOUR` / etc.). Skip rating for upcoming lessons.

---

### 4.6 — 지정튜터 티켓 purchase `/tutors/purchase-ticket`

```
┌────────────────────────────────────────┐
│ ←  지정튜터 티켓                       │
├────────────────────────────────────────┤
│  내가 원하는 튜터를 골라서             │
│  하루에 여러 번도 예약하세요.          │
│  ─────────────────────────────────     │
│   • 구독과 별개로 사용 가능            │
│   • 하루 횟수 제한 없음                │
│   • 구매 후 90일 이내 사용             │
├────────────────────────────────────────┤
│ ┌──────────────────────────────────┐  │
│ │  1회권          ₩9,900            │  │
│ │  부담없이 한 번                    │  │
│ │                        [선택]      │  │
│ ├──────────────────────────────────┤  │
│ │  5회권          ₩44,500   (-10%)  │  │
│ │  가장 인기 ⭐                      │  │
│ │                        [선택]      │  │
│ ├──────────────────────────────────┤  │
│ │  10회권         ₩84,000   (-15%)  │  │
│ │  꾸준한 학습용                     │  │
│ │                        [선택]      │  │
│ └──────────────────────────────────┘  │
├────────────────────────────────────────┤
│  결제 수단                             │
│  ◉ 등록된 카드 (1234)                  │
│  ○ 카카오페이                          │
├────────────────────────────────────────┤
│                                        │
│ ╔══════════════════════════════════╗   │
│ ║   5회권 결제하기 (₩44,500)        ║   │
│ ╚══════════════════════════════════╝   │
│  [약관 보기]                            │
└────────────────────────────────────────┘
```

**Ticket data model** (new `le_designated_tutor_ticket`):
```
id, student_id, sku, total_count, remaining_count,
purchased_at, expires_at, refunded_at, source_order_id
```

**Constraints to align on (open questions):**
- **C1 — Pricing/expiry:** placeholders ₩9.9k / 5회 ₩44.5k / 10회 ₩84k, 90-day expiry. PM/Finance to confirm.
- **C2 — Refund policy:** unused tickets refundable within X days? Existing `Subscribe` refund rules (`SubscribeServiceImpl`) probably apply. Recommend: full refund if 0 used in 7 days; pro-rated after.
- **C3 — Tier gating:** is the SKU available only to active subscribers, or to anyone? Recommend: anyone can buy, but a no-subscription user is gently nudged into a starter bundle on first launch.
- **C4 — Tutor specificity:** does the ticket lock to a specific tutor at purchase time, or is it generic and the tutor is chosen at booking time? Recommend **generic** — matches how the user described it ("a ticket that allows them to book a tutor they want"), simpler inventory.

---

### 4.7 — My-podo additions

```
/my-podo
├── … existing rows …
├── 찜한 튜터              12명     →   ← NEW (surface 6)
├── 지정튜터 티켓          3장 보유  →   ← NEW (surface 3)
└── 차단한 튜터            2명      →   ← existing tutor-exclusion
```

#### 4.7.1 — `/my-podo/tutor-favorites`

```
┌────────────────────────────────────────┐
│ ←  찜한 튜터 (12 / 30)                 │  ← cap parallels tutor-exclusion
├────────────────────────────────────────┤
│ 정렬: 최근 찜한 순 ⌄                   │
├────────────────────────────────────────┤
│ ┌──────────────────────────────────┐  │
│ │ ◯ Jenny  ★ 4.9                  │  │
│ │   함께한 레슨 7회                 │  │
│ │   이번 주 예약 가능 4건           │  │
│ │                       ♥ 해제      │  │
│ └──────────────────────────────────┘  │
│ …                                      │
└────────────────────────────────────────┘
```

- Max 30 favorites (matches `tutor-exclusion` pattern of `currentCount/maxCount`).
- Favoriting an excluded tutor → confirm dialog "차단 해제하고 찜할까요?"
- Tap card → tutor profile.

#### 4.7.2 — `/my-podo/designated-tickets`

```
┌────────────────────────────────────────┐
│ ←  지정튜터 티켓                       │
├────────────────────────────────────────┤
│  보유 중      3장                       │
│  가장 빠른 만료  2026-08-10            │
├────────────────────────────────────────┤
│  [+ 티켓 더 구매]                       │
├────────────────────────────────────────┤
│  사용 내역                             │
│  ─ 5/12 Jenny와 비즈니스 영어         │
│  ─ 5/10 Mark와 프리토킹                │
│  ─ 5/03 구매 (5회권)                   │
└────────────────────────────────────────┘
```

---

## 5. Backend changes (mapped to existing repo)

| Area | Change |
|---|---|
| `applications/user/domain/Tutor.java` | New fields: `audioIntroUrl`, `audioIntroDuration`, `hireDate`. Existing `hashTag`, `tutorIntro`, `youtube` already usable. |
| `applications/podo/favorite/**` (new) | Mirror of `applications/podo/exclusion/**`: `TutorFavorite` entity, `TutorFavoriteService`, `TutorFavoriteController`. Table `le_tutor_favorite (student_id, tutor_id, created_at)`. Cap of 30 enforced at service. |
| `applications/podo/schedule/**` | New query: tutors available for `class_id + date + time`. Today `ScheduleTimeBlock` already stores `tutor_id`, so this is a `findByClassIdAndUtcScheduleDateTimeBetweenAndStudentIdIsNull` projection. Add **favorited-count** aggregator endpoint. |
| `applications/lecture/service/command/LectureCommandService` | Add `registerWithDesignatedTutor(classId, tutorId, ticketId)` path. Validates ticket ownership & remaining count, then `ScheduleTimeBlock.studentId = userId` for that specific tutor's slot. |
| `applications/ticket/**` (new) | `DesignatedTutorTicket` entity + service. SKU registry + purchase via existing payment gateway (`PaymentGateway`). |
| `applications/podo/nps/**` | Extend NPS submit DTO with optional `freeText` + `isPublic`. New query: aggregate rating + recent public reviews per tutor. |
| `applications/podo/exclusion/usecase/TutorExclusionService` | On block → also remove favorite (and vice versa). |
| `grape/admin/**` | Tutor profile editor (audio upload, hashtag editor, bio cap). Review moderation table (if Option B is chosen — defer). |

---

## 6. Web changes (mapped to `apps/web/src`)

```
NEW
src/entities/tutor/                            ← public tutor API + types
src/entities/tutor-favorite/                   ← mirror tutor-exclusion
src/entities/designated-ticket/
src/entities/tutor-review/

src/features/tutor-search/                     ← search/sort/filter logic
src/features/tutor-favorite/                   ← favorite toggle + cap
src/features/designated-ticket-purchase/
src/features/tutor-picker/                     ← bottom sheet shared by booking
src/features/audio-bio-player/                 ← reused on profile + cards

src/views/tutor-search/
src/views/tutor-profile/
src/views/tutor-reviews/
src/views/designated-tickets/
src/views/tutor-favorites/

src/app/(internal)/tutors/page.tsx
src/app/(internal)/tutors/[tutorId]/page.tsx
src/app/(internal)/tutors/[tutorId]/reviews/page.tsx
src/app/(internal)/tutors/purchase-ticket/page.tsx
src/app/(internal)/my-podo/tutor-favorites/page.tsx
src/app/(internal)/my-podo/designated-tickets/page.tsx

MODIFIED
src/views/booking/view.tsx                     ← top-right toggle, picker sheet entry
src/views/booking/hooks/use-schedule.ts        ← optional favorite-count layer
src/views/booking/ui/booking-confirm-dialog.tsx← "튜터 선택하기" button
src/widgets/completed-lessons/ui/*             ← tutor-led card variant
src/widgets/reserved-lessons/ui/*              ← tutor avatar lead-in
src/features/lesson-review/ui/nps-survey/*     ← "공개 리뷰로 등록" checkbox
```

---

## 7. Things the user did NOT mention but matter

1. **Audio bio recording UX (where does the audio come from?).** The user said "maybe a short audio clip would be nice" — but who records it? Recommend tutors record in `apps/tutor-web` (which already exists at `apps/tutor-web/`), self-recorded, capped at 30 sec, with admin moderation hold before going live.
2. **Tutor capacity guard.** If 200 students all favorite the same star tutor, the slot grid will be ♥0 most of the time. Need a "favorite a backup too" nudge + a "suggest similar tutors" affordance on the tutor profile when fully booked.
3. **Favorite cap.** Mirror `tutor-exclusion`'s 30-cap. Without one, the "찜한 튜터만" toggle becomes a fancy "show all tutors" toggle for power users.
4. **Favorite ↔ block conflict resolution.** Today blocking shows up in `BlockedTutor[]`. Add bidirectional clear on either action (already noted above).
5. **Lesson cancellation / penalty rules for ticket-booked lessons.** Today `useLessonPenalty` gates the booking screen. Should designated bookings be subject to the same weekly-change-limit? Recommend **yes, identical rules** — students get penalty waivers via existing flow.
6. **Subscription co-existence.** When a user has both, the picker should default to "지정튜터 티켓" only when a tutor is selected; otherwise default to subscription. Avoids unintentionally burning a ticket on random matching.
7. **Refund of unused tickets when tutor quits.** If a favorited tutor goes inactive, do their dedicated tickets refund or convert? Recommend: tickets are generic (constraint C4) so this is a non-issue.
8. **Notification on favorite tutor opens a slot.** Powerful retention lever, but a separate feature — flag as v1.1.
9. **Public reviews moderation.** See §4.3 — Option A defers this risk.
10. **Tutor profile privacy of `realName`.** `GT_TUTOR.realName` must never leak to student-facing API; only `name`. Add API filter test.
11. **Schedule API payload size.** Per-slot tutor list × 30-min slots × 7 days × N tutors is heavy. Recommend: aggregated favorite-count for the grid view, full tutor list lazy-loaded on slot tap.
12. **Analytics events** (rough cut, extend existing `ANALYTICS_EVENTS`):
    - `tutor_search_viewed`, `tutor_search_filtered { sort, filters }`
    - `tutor_profile_viewed { tutorId, source }`
    - `tutor_audio_played { tutorId, duration_played }`
    - `tutor_favorited` / `tutor_unfavorited { tutorId }`
    - `designated_ticket_purchase_viewed`, `designated_ticket_purchased { sku, amount }`
    - `booking_favorite_toggle { on }`, `tutor_picker_opened`, `designated_booking_completed { tutorId, ticketId }`
13. **Internationalization.** All copy goes through the existing i18n pipeline; Korean is source-of-truth for v1.
14. **Cross-platform parity.** `apps/native` consumes the same Next.js webview — surfaces should not require platform-specific divergence except for the audio recorder (browser MediaRecorder is fine for v1; native recorder later).
15. **A/B & rollout.** Wire under one feature flag (e.g. `TBD_2606_DESIGNATED_TUTOR`) → 5% → 25% → 100%, with `tutor_profile_viewed`-to-`designated_ticket_purchased` funnel as the primary KPI.

---

## 8. Phased rollout proposal

**Phase 0 — data foundation (1–2 sprints, no UI):**
- `le_tutor_favorite` table + APIs
- `Tutor` extra fields + admin editors
- Public NPS aggregation (Option A)
- Per-slot tutor list endpoint

**Phase 1 — discovery (no commerce, no booking change):**
- Tutor search `/tutors`
- Tutor profile `/tutors/[id]` (without booking CTA — "곧 만나요" placeholder)
- My-podo `찜한 튜터` row
- Tutor-led lesson cards on `/reservation` (surface 5)
→ Ship behind 5% flag; measure profile→favorite rate.

**Phase 2 — commerce + booking integration:**
- 지정튜터 티켓 purchase + ownership view
- Booking toggle + tutor picker sheet
- Designated booking backend path
→ Ramp 5 → 25 → 100% if Phase 1 favorite rate ≥ target (e.g. 15% of profile viewers).

**Phase 3 (v1.1):**
- Public review free-text (Option B if Phase 2 numbers justify moderation cost)
- Push notification: favorite tutor opened new slots
- Tutor recommendation engine on profile bottom

---

## 9. Open questions to resolve before kicking off

| # | Question | Owner | Recommended default |
|---|---|---|---|
| A | Toggle-off behavior for ♥0 slots when "favorites only" is on | PM + Design | Dimmed + tap-with-toast |
| B | Toggle vs in-dialog button — pick one or both | PM + Design | Both, behind same flag |
| C1 | Ticket pricing & expiry | PM + Finance | 1/5/10 회권, 90일 |
| C2 | Refund policy for unused tickets | PM + Finance | Pro-rata after 7d |
| C3 | Subscription gating for ticket purchase | PM | Anyone can buy |
| C4 | Ticket = specific tutor vs generic | PM | Generic |
| D | Public reviews — aggregate NPS only vs new free-text step | PM + Trust&Safety | Option A (aggregate NPS + opt-in text) |
| E | Audio bio recorder location (tutor-web vs admin upload) | Tutor Ops | tutor-web self-record, admin holds for review |
| F | Favorite cap | PM | 30 (mirror exclusion) |
| G | Slot tutor-list endpoint shape (eager vs lazy) | Backend | Lazy on tap, eager count |

---

## 10. Definition of done (v1, phase 1 + 2)

- A user with no past lessons can: search tutors → open a profile → listen to bio → read 5 reviews → favorite → buy a 5-ticket bundle → return to booking → toggle "찜한 튜터만" → tap a slot → pick a favorited tutor → confirm booking → see the booked tutor on `/reservation`.
- A user with past lessons sees the new tutor-led card on `/reservation`, with their own star rating shown when a review exists.
- Existing booking flow (no toggle, no ticket) is unchanged for users not in the rollout.
- All new endpoints behind `TBD_2606_DESIGNATED_TUTOR` flag.
- Tutor `realName` does not appear in any student-facing response (test enforced).
- Tutor-exclusion ↔ tutor-favorite are mutually exclusive (test enforced).

---

*End of v0.1 draft. Next step: review with PM + design; resolve §9 questions; produce hi-fi mocks in Figma.*
