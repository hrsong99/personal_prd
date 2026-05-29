# Designated Tutor (지정튜터) Feature — PRD & Wireframes

**Status:** Draft v0.2
**Author:** podo@day1company.co.kr
**Working repo:** `personal_prd`
**Touch repos:** `podo-app` (web/native), `podo-backend`, `grape` (admin)

> The HTML version (`designated-tutor-feature-prd.html` / `designated-tutor-feature-prd-ko.html`) is the source of truth for wireframes. This markdown mirrors its structure and behavior notes.

---

## 1. Goal

Let students favorite specific PODO tutors and designate them for their subscription lessons via a paid **튜터 지정권 enabler**, alongside the existing random-matching flow. The ticket does *not* cover the lesson itself — the lesson is drawn from the student's active subscription.

Today the product matches students to any available tutor on a chosen time slot (`ScheduleTimeBlock` aggregated by `cnt` per time). Students can only exclude tutors via `le_tutor_exclusion` — there is no way to actively pick or favorite a tutor, and no public tutor profile.

This PRD introduces the inverse: discovery (profile + search), preference (favorites + private memo), commerce (튜터 지정권 — an **enabler** that designates the tutor for a subscription lesson, not a lesson replacement), a tutor-aware booking flow, and a new **튜터** tab in GNB as a parallel entry to the lesson-first flow.

---

## 2. What's new

- **Tutor profile** — public profile with bio, audio intro, hashtags, reviews, view-only schedule, private memo, and 차단 toggle
- **튜터 지정권 (enabler)** — paid SKU layered on top of an active subscription; designates a tutor for a subscription lesson (does not add an extra lesson). Purchased / free-seed variants in v1 (compensation variant deferred); auto-use earliest-expiring first
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
│ ←       튜터 선택        🎫 3개          │
│         5/13(수) 12:00                   │
├────────────────────────────────────────┤
│ [평점 높은 순 ⌄]                  [필터] │
├────────────────────────────────────────┤
│ ┌──────────────────────────────────┐   │
│ │ ⬤      Keiko                  ♥ │   │
│ │ avatar  ★ 4.9 (312)               │   │
│ │ 🔊      함께한 레슨 4회            │   │
│ │ [한국어 가능] #차분함 #문법강조 +2 │   │
│ │                          [더보기 →]│   │
│ └──────────────────────────────────┘   │
│ ┌──────────────────────────────────┐   │
│ │ ⬤      Yoko  [POPULAR]        ♥ │   │
│ │ avatar  ★ 4.9 (312)               │   │
│ │ 🔊      함께한 레슨 4회            │   │
│ │  #차분함 #문법강조 +2    [더보기 →]│   │
│ └──────────────────────────────────┘   │
│ ┌──────────────────────────────────┐   │
│ │ ⬤      Nanami                 ♡ │   │
│ │ 🔊      ★ 4.9 (312)               │   │
│ │         함께한 레슨 4회            │   │
│ │ [한국어 가능] #차분함 #문법강조 +2 │   │
│ └──────────────────────────────────┘   │
└────────────────────────────────────────┘
```

- Card layout: large round avatar (left, with overlapping 🔊 audio icon at bottom-right of avatar), favorited heart (♥ filled red / ♡ outline) at top-right of card.
- Name row: tutor name + optional `POPULAR` badge (pink pill).
- `★ rating (count)` line, then `함께한 레슨 N회` line.
- Bottom chip row: a black `한국어 가능` pill (shown only when Korean-capable) followed by hashtag chips (`+N` overflow), with `더보기 →` pill on the right opening the profile.
- ⚠️ **Changed in 최종:** the old `N번 함께한 튜터` blue caption and the `레슨 N회 · 재수강 N%` stats row were removed; Korean-availability moved from inline text into a standalone black pill; per-card stat is now `함께한 레슨 N회`.
- Favorited (♥) cards pinned to top.
- POPULAR / NEW badges (see §5) render as small chips next to the name when applicable.
- 휴식 중 (`classPause=true`) tutors hidden.
- The "내 메모" private memo (§3.6) is surfaced inline on this card as a small italic line above the hashtags when set.

> 📐 **Figma:** [`24371:42169`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-42169) — 튜터 선택 — 찜한 튜터 상단

**Card tap → confirm dialog** (over the picker, same `wf-dialog` as §3.1 / §3.3, plus a green-outlined ticket-usage info banner):

```
┌────────────────────────────────────────┐
│ 레슨 일정 확인                          │
│                                         │
│  레슨명     1. 단수 명사와 가족 구성원…  │
│  레슨 일정  5월 28일(수) 09:30~09:55     │
│  튜터       Jenny                        │
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ 📁1  튜터 지정권 1개가 사용돼요    ││
│ └─────────────────────────────────────┘│
│                                         │
│   [ 취소 ]            [ 예약하기 ]      │
└────────────────────────────────────────┘
```

- 튜터 row shows the chosen tutor name; **변경 ›** is intentionally absent (cancel + re-enter to swap).
- Green-outlined ticket-usage banner makes the ticket consumption explicit.

> 📐 **Figma:** [`24371:37231`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37231) — 카드 탭 → 예약 확인 (튜터 선택 위)

**Sort sheet** — bottom sheet, single-select.

```
┌────────────────────────────────────────┐
│        ▬▬                              │
│ 정렬 기준                              │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │ ✓  평점 높은 순                    │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ ○  리뷰 많은 순                    │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ ○  함께한 횟수 많은 순             │ │
│ └────────────────────────────────────┘ │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │              적용                   │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- Single-select rows with circle-check; default `평점 높은 순`. `함께한 횟수` is per-current-user. No `신규 튜터` sort.

> 📐 **Figma:** [`24371:37271`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37271) — 정렬 시트

**Filter sheet** — bottom sheet; `초기화` link top-right resets to defaults.

```
┌────────────────────────────────────────┐
│        ▬▬                              │
│ 필터                          초기화    │
│                                        │
│ 한국어 가능 튜터만 보기         [ ON ●]│
│                                        │
│ [모든 튜터] [함께한 적 있는 튜터만]    │
│              [ 찜한 튜터만 ✓ ]         │
│                                        │
│ ┌────────────────────────────────────┐ │
│ │              적용                   │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- `한국어 가능 튜터만 보기` toggle.
- Scope chips (single-select, default `모든 튜터`): `모든 튜터` / `함께한 적 있는 튜터만` / `찜한 튜터만` — selected chip gets a green outline + check.
- **No 국적 / 성별 filters** — see §5 Policies.

> 📐 **Figma:** [`24371:37286`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37286) — 필터 시트

**0-pass state.** Header pass badge turns red (`0개`). Tapping a tutor card opens:

```
┌────────────────────────────────────────┐
│        튜터 지정권이 필요해요            │
│                                          │
│   특정 튜터를 예약하려면 튜터 지정권이    │
│   필요해요.                              │
│                                          │
│     [ 취소 ]         [ 지정권 구매 ]      │
└────────────────────────────────────────┘
```

- **취소** dismisses and returns to the picker. Random matching is reached via the lesson-first flow (§3.1), not offered as a side-door here.
- **지정권 구매** → ticket purchase page (§3.5).

> 📐 **Figma:** [`24371:37283`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37283) — 티켓 0장 상태에서 카드 탭 (지정권 구매 dialog)

---

### 3.1 — Booking screen `/booking?classId=…` — MODIFIED

Existing slot grid plus a tiny **♥** marker on cells where one or more **favorited** tutors have availability at that slot. Legend on the section header (`♥ 찜한 튜터 ● 예약 마감`).

```
┌────────────────────────────────────────┐
│ ←                                       │
│                                         │
│ 레슨 일정을 선택해주세요.                │
│  · 레슨 시작 1시간 전까지 언제든지 변경  │
│  · 레슨은 25분간 진행돼요.               │
│                                         │
│  오늘  내일  목   금   토   일          │
│   27   [28]  29   30    1    2          │
│                                         │
│ 예약 가능 시간   ♥ 찜한 튜터 ● 예약 마감│
│                                         │
│ 오전                                    │
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │06:00 │ │06:30♥│ │07:00 │              │
│ └──────┘ └──────┘ └──────┘              │
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │07:30 │ │08:00 │ │08:30♥│              │
│ └──────┘ └──────┘ └──────┘              │
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │09:00 │ │09:30♥│ │10:00 │ ← 10:00 마감 │
│ └──────┘ └─[선택]┘ └─grey─┘              │
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │10:30 │ │11:00♥│ │11:30 │              │
│ └─grey─┘ └──────┘ └──────┘              │
│                                         │
│ ┌────────────────────────────────────┐  │
│ │      선택한 날짜로 예약             │  │
│ └────────────────────────────────────┘  │
└────────────────────────────────────────┘
```

- Day strip uses today/tomorrow labels plus weekday + day-of-number; selected date gets a green outline pill.
- Cells: white = available, grey-fill = `예약 마감`, small heart in top-right corner when ≥1 favorited tutor has availability, selected cell gets green outline + soft fill.
- 25-min lessons throughout (`레슨은 25분간 진행돼요` caption).
- Sticky CTA `선택한 날짜로 예약`; tapping opens the confirm dialog below.

> 📐 **Figma:** [`24371:37113`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37113) — 예약 화면 / 레슨 일정-찜한 튜터 가능

Slot tap shows the confirm dialog with the new **튜터** row:

```
┌────────────────────────────────────────┐
│ 레슨 일정 확인                          │
│                                         │
│  레슨명     1. 단수 명사와 가족 구성원…  │
│  레슨 일정  5월 28일(수) 09:30~09:55     │
│  튜터       랜덤 배정      튜터 선택 ›  │
│                                         │
│   [ 취소 ]            [ 예약하기 ]      │
└────────────────────────────────────────┘
```

- Default `튜터 | 랜덤 배정` keeps the existing flow; tapping **튜터 선택 ›** opens the picker (§3.2).
- After a tutor is chosen, the row becomes `튜터 | Jenny` with no change affordance (cancel + re-enter to swap).
- 예약하기 is the primary (green); 취소 is outlined secondary.

> 📐 **Figma:** [`24371:37211`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37211) — 예약 화면 / 레슨 일정 확인 팝업

---

### 3.3 — Tutor profile `/tutors/[tutorId]`

```
┌────────────────────────────────────────┐
│ ←        튜터 프로필              ♥    │
│                                         │
│       ┌──────────────────────┐         │
│       │       avatar         │         │
│       │       (large)        │         │
│       └──────────────────────┘         │
│                                         │
│ Jenny                                   │
│ 레슨 1,240회 · 함께한 레슨 4회 · 찜 35명 │
│ 안녕하세요! 저는 5년 동안 한국 학생들을 │
│ 가르쳤고, 발음 교정이 특기예요…  더보기 │
│ ┌────────────────────────────────────┐ │
│ │ ▶  ▮▮▮▮ ▬▬▬▬▬▬▬▬▬▬▬▬    0:18      │ │ ← audio
│ └────────────────────────────────────┘ │
│ #발음교정 #친절함 #비즈니스영어 #왕초보환영│
│ #사진촬영 #여행 #애니메이션             │
│                                         │
│ 수업 후기  ★ 4.9 (312)      전체 보기 → │
│ 친절하고 상냥한 태도 (201) ▰▰▰▰▰▰▰▰   │
│ 자연스러운 대화 속도 (190) ▰▰▰▰▰▰▰    │
│ 꼼꼼한 문법 교정    (182) ▰▰▰▰▰▰▰     │
│ 활기차고 재미있는 수업(178) ▰▰▰▰▰▰     │
│ 정확한 발음 교정    (169) ▰▰▰▰▰▰     │
│ ┌────────────────────────────────────┐ │
│ │ 내 리뷰  ★★★★★   2026-04-12      │ │
│ │ 정말 친절한 튜터예요. 발음 교정이… │ │
│ └────────────────────────────────────┘ │
│                                         │
│ 내 메모                                 │
│ ┌────────────────────────────────────┐ │
│ │ 튜터에 대한 개인 메모를 작성하세요 │ │ ← inline-editable
│ └────────────────────────────────────┘ │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │ 이 튜터를 차단할까요?      [차단]  │ │ ← 차단 bar
│ └────────────────────────────────────┘ │
│                                         │
│ ┌────────┐ ┌─────────────────────────┐ │
│ │ 스케줄 │ │   이 튜터로 예약하기     │ │ ← sticky row
│ └────────┘ └─────────────────────────┘ │
└────────────────────────────────────────┘
```

Body order (profile-head is fixed at top):

1. **Profile head** — avatar (square-rounded large green hero), name (`Jenny`), stats line `레슨 1,240회 · 함께한 레슨 4회 · 찜 35명`. Header has `←` and ♥ (top-right) when favorited. **No country flag / no language pill** — see §5 Policies.
2. **소개** — bio (`Tutor.tutorIntro`) shown directly under the stats line (no `소개` header), `…더보기` truncation.
3. **Audio bio** — player card with ▶ button, waveform, duration (no `목소리 들어보기` header now — just the player). Hidden entirely while moderation is pending or unrecorded.
4. **Hashtags** — single combined chip block (the old `특장점` / `관심사` split headers were removed).
5. **수업 후기** — renamed from `리뷰`. Shows `★ 4.9 (312)` + `전체 보기 →`, then an **aggregated positive-feedback-chip bar list** (top chips by count, e.g. `친절하고 상냥한 태도 (201)` with a horizontal bar), then one review card (user's own review if exists, else top-helpful recent).
6. **내 메모** — private per-favorite memo. Inline-editable card (no edit button), `cursor: text`, faint caret indicator. Autosaves on blur (debounced sync while typing). Surfaced again in the picker (§3.2) and favorites list (§3.6). **Authored only here** — never auto-prompted at favoriting or in the NPS opt-in flow.
7. **차단 bar** — full-width grey bar with two states:
   - **Unblocked**: `이 튜터를 차단할까요?` + pink `차단` pill. Tap → confirm dialog (reuses tutor-exclusion). If currently favorited, prompt `찜 해제하고 차단할까요?` first (mirror of §3.6's `차단 해제하고 찜할까요?`).
   - **Blocked**: `이 튜터를 차단중입니다.` + navy `해제` pill. Header ♥ removed. Sticky CTA replaced with a `차단된 튜터` status pill (booking disabled).
8. **Sticky footer — `[스케줄]` + `이 튜터로 예약하기`**. The `이번 주 가능 시간 보기` entry moved from a top outlined button into a small **스케줄** button in the sticky footer (opens the view-only schedule sheet). The primary CTA state depends on entry point:
   - From the picker (§3.2): lesson + slot already chosen → confirm dialog with this tutor pre-filled, no 변경 affordance.
   - From the 튜터 탭 (§3.7): no lesson/slot yet → routes through §3.7.3 booking page.
   - From a past-lesson card avatar tap (§3.4): booking-enabled — routes through §3.7.3 booking page (strongest "rebook this tutor" moment).
   - From my-podo favorites: view-only (no booking CTA).
   - For non-subscribers / expired-sub users: CTA shows a subscription upsell prompt instead of routing to booking.

> ⚠️ **Changed in 최종:** profile redesigned — stats line now `레슨 N회 · 함께한 레슨 N회 · 찜 N명` (added 찜 count); language pill + one-line tagline removed; `특장점`/`관심사` merged into one hashtag block; `목소리 들어보기` header dropped; `리뷰` renamed to `수업 후기` with an aggregated feedback-chip bar list; top `이번 주 가능 시간 보기` button replaced by a `스케줄` button in the sticky footer.

> 📐 **Figma:** [`24371:39127`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-39127) — 프로필 (기본)

**이번 주 가능 시간 sheet (view-only)** — slide-up over the profile.

```
┌────────────────────────────────────────┐
│        ▬▬                              │
│ Jenny 튜터 예약 가능 시간               │
│                                         │
│  오늘  내일  목   금   토   일          │
│   20   [21]  22   23   24   25          │
│                                         │
│ 예약 가능 시간             ● 예약 마감  │
│                                         │
│ 오전                                    │
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │06:30 │ │07:00 │ │07:30 │              │
│ └──────┘ └──────┘ └──────┘              │
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │ 8:00 │ │ 8:30 │ │ 9:00 │              │
│ └─grey─┘ └──────┘ └──────┘              │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │               닫기                  │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- Day strip + slot grid — visually mirrors §3.1, but **no booking CTA**, only `닫기`.
- Reinforces: "조회만 가능해요. 예약은 레슨 리스트에서 시작해주세요."
- Does NOT start a booking — that flow is owned by §3.1/§3.2/§3.7.

> 📐 **Figma:** [`24371:37849`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37849) — "이번 주 가능 시간 보기" → 조회 전용 시트

**리뷰 전체 보기 `/tutors/[tutorId]/reviews`**

```
┌────────────────────────────────────────┐
│ ←       Jenny의 리뷰 (312)              │
│                                         │
│            ★  4.9 /5.0                  │
│ ★ 5 ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰ 82%             │
│ ★ 4 ▰▰▰  13%                            │
│ ★ 3 ▰    3%                             │
│ ★ 2 ·    1%                             │
│ ★ 1 ·    1%                             │
│                                         │
│ [추천순] [최신순]               [필터 ⌄]│
│                                         │
│ ┌────────────────────────────────────┐ │
│ │ ★★★★★  김** · 2026-04-12     👍 │ │
│ │ 발음 교정이 정말 꼼꼼해요. 모르는… │ │ 112│
│ │ [자연스러운 대화 속도][꼼꼼한 문법 교정][+2]│
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ ★★★★★  이** · 2026-04-12     👍 │ │
│ │ … 처음 레슨이었는데 부담 없이…     │ │ 35 │
│ │ [정확한 발음 교정][꼼꼼한 문법 교정][+6]│
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- Rating summary at top (avg + per-star histogram with %).
- Sort segmented control: `추천순` (default) / `최신순`; right-side `필터 ⌄` opens a star-filter sheet.
- Review cards: stars, masked nickname, date, body, the reviewer's selected **positive-feedback chips** (green-outline, `+N` overflow), and a 👍 thumbs-up icon + bare count on the right.
- ⚠️ **Changed in 최종:** the `전체` sort tab was removed (now `추천순` / `최신순` only); each card now surfaces the reviewer's feedback chips, and the helpfulness affordance changed from a `N명에게 도움됨` pill to a 👍 icon + count.
- Source: §3.3 `수업 후기 (312) 전체 보기 →` link.

> 📐 **Figma:** [`24371:37677`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37677) — 리뷰 전체 보기

**Sticky CTA → 예약 확인 dialog (over profile)** — identical confirm dialog used in §3.1 / §3.2 (with ticket-usage banner when a designated ticket is being spent).

```
┌────────────────────────────────────────┐
│ 레슨 일정 확인                          │
│                                         │
│  레슨명     1. 단수 명사와 가족 구성원…  │
│  레슨 일정  5월 28일(수) 09:30~09:55     │
│  튜터       Jenny                        │
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ 📁1  튜터 지정권 1개가 사용돼요    ││
│ └─────────────────────────────────────┘│
│                                         │
│   [ 취소 ]            [ 예약하기 ]      │
└────────────────────────────────────────┘
```

> 📐 **Figma:** [`24371:38696`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-38696) — CTA 탭 → 예약 확인 (프로필 위)

**랜덤 매칭 예약 완료** — confirmation screen after the lesson-first flow without a designated tutor.

```
┌────────────────────────────────────────┐
│                                         │
│           [PODO mascot illustration]    │
│                                         │
│         레슨이 예약됐어요!              │
│   교재로 미리 예습하면 편하게 대화할     │
│           수 있어요                      │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │   5월 13일(수) 12:00   [D-DAY]     │ │
│ │           영어 Level 1              │ │
│ └────────────────────────────────────┘ │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │               예습하기              │ │
│ └────────────────────────────────────┘ │
│                홈으로                   │
└────────────────────────────────────────┘
```

> ⚠️ **Not re-rendered in 최종.** The Final section only carries the 지정튜터 예약 완료 variant; this random-match completion frame still points to the pre-최종 draft node.

> 📐 **Figma:** [`24214:10559`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24214-10559) — 랜덤 매칭 예약 완료 (pre-최종)

**지정튜터 예약 완료** — confirmation after a designated booking. Adds tutor name to the lesson card and surfaces the ticket-usage banner.

```
┌────────────────────────────────────────┐
│                                         │
│           [PODO mascot illustration]    │
│                                         │
│         레슨이 예약됐어요!              │
│   교재로 미리 예습하면 편하게 대화할     │
│           수 있어요                      │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │   5월 13일(수) 12:00   [D-DAY]     │ │
│ │     영어 Level 1 │ 튜터 Jenny       │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 📁1  튜터 지정권 1개가 사용됐어요  │ │
│ └────────────────────────────────────┘ │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │               예습하기              │ │
│ └────────────────────────────────────┘ │
│                홈으로                   │
└────────────────────────────────────────┘
```

- Lesson card adds `튜터 Jenny` divider.
- Green-outlined ticket-usage banner identical to the confirm dialog's banner.

> 📐 **Figma:** [`24371:37189`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37189) — 지정튜터 예약 완료

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

Today: `RegularLessonCard` leads with the course thumbnail. After: minimal addition — tutor name + rating row inside the card, and a `튜터 프로필` button alongside the existing `AI 리포트 및 다시보기`.

```
┌────────────────────────────────────────┐
│ 예약된 레슨                              │
│                                         │
│      [PODO mascot · empty state]        │
│       현재 예약된 레슨이 없어요.        │
│       레슨을 보러갈까요?                │
│       ┌──────────────────┐              │
│       │  레슨 보러 가기   │              │
│       └──────────────────┘              │
│                                         │
│ 지난 레슨                                │
│ ○ 취소된 레슨 숨김                       │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │ [thumb] Start1                      │ │
│ │         1. 단수 명사와 가족 …       │ │
│ │         2월 11일 14:00              │ │
│ │         📁 Mark   ★★★★★            │ │ ← tutor row + rating
│ │ [ 튜터 프로필 ] [ AI 리포트 및 다시보기]│
│ └────────────────────────────────────┘ │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │ [thumb] Start1                      │ │
│ │         1. 단수 명사와 가족 …       │ │
│ │         2월 11일 14:00              │ │
│ │         📁 Mark   ★★★★★            │ │
│ │ [ 튜터 프로필 ] [ AI 리포트 및 다시보기]│
│ └────────────────────────────────────┘ │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │ [thumb] Start1                      │ │
│ │         1. 단수 명사와 가족 …       │ │
│ │         2월 11일 14:00              │ │
│ │         Sarah                        │ │ ← no rating yet
│ │ [ 리뷰 남기기 ] [ AI 리포트 및 다시보기]│
│ └────────────────────────────────────┘ │
│                                         │
│ [GNB: 홈 · 레슨 · 예약 · AI 학습 · 마이포도]│
└────────────────────────────────────────┘
```

- Card thumbnail leads (existing layout preserved); tutor row added below the date with mini-avatar/name + star rating.
- Rated card → `[튜터 프로필]` button. Unrated card → `[리뷰 남기기]` button (replaces 튜터 프로필).
- Tutor name / 튜터 프로필 button → `/tutors/[tutorId]` deeplink with **booking CTA enabled** — strongest "rebook this tutor" moment.
- Cancelled / no-show cards keep the cancelled style (don't lead with tutor — feels like blame).
- `ReservedLessonsSection` (upcoming) uses the same pattern, with the rating row replaced by the existing countdown chip.
- If tutor `canUse=false` (quit), profile deeplink shows a `더 이상 활동하지 않아요` view (booking disabled). Favorited quit-tutors stay in the favorites list with the same grayed pill — never silently removed.

> 📐 **Figma:** [`24371:37855`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37855) — 변경 후 (최소 추가) — tutor-led card variant

---

### 3.5 — 튜터 지정권 purchase `/tutors/purchase-ticket`

> 🏷️ **Terminology (renamed in 최종).** The paid SKU is now called **튜터 지정권** in-app (counter unit **개**), replacing the earlier **지정튜터 티켓** (units 매/장). `티켓 구매` → `지정권 구매`. This PRD standardizes on **튜터 지정권 / 개**. A few Figma frames still show the old copy and are flagged for design copy-cleanup: the §3.7 confirm-dialog banner (`24371:37251`, still "지정튜터 티켓 1매가 사용돼요" — the §3.2/§3.3 dialogs were updated, this one lags), the §3.5 payment fine-print (`24371:38112`, body still "지정튜터 티켓은…"), and the §3.6 ticket list section header (`보유 티켓`) and its `보상 지정권 지급 · 1장` row (still `장`). Backend entity name `DesignatedTutorTicket` is code and unchanged.

```
┌────────────────────────────────────────┐
│ ←        튜터 지정권 구매              │
│                                         │
│ ─🇺🇸 영어 ────────  🇯🇵 일본어 ─────    │ ← language tabs
│                                         │
│ ┌────────────────────────────────────┐ │
│ │ 내가 원하는 튜터와 레슨 받을 수    │ │
│ │ 있어요.                             │ │
│ │ ✓ 1:1 레슨권과 함께 사용            │ │
│ │ ✓ 구매 후 90일 이내 사용            │ │
│ └────────────────────────────────────┘ │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │ 1회권              -42%  ~~₩7,000~~ │ │
│ │                          ₩4,000     │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 5회권          -15% ~~₩20,000~~ ₩3,400/회│
│ │                          ₩17,000    │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 10회권 [BEST]  -28% ~~₩40,300~~ ₩2,900/회│ ← selected
│ │                          ₩29,000    │ │   (green outline)
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 20회권         -40% ~~₩80,000~~ ₩2,400/회│
│ │                          ₩48,000    │ │
│ └────────────────────────────────────┘ │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │       10회권 결제하기 (₩29,000)     │ │
│ └────────────────────────────────────┘ │
│                약관 보기                │
└────────────────────────────────────────┘
```

- Language tabs (영어 / 일본어) gate which packs render. Single SKU per language; default to user's primary learning language.
- Info box (green) reiterates: 1:1 레슨권과 함께 사용 · 구매 후 90일 이내 사용.
- Pack cards each show: 회권 (with optional `BEST` badge on 10회권), 할인율, 정가 strikethrough, 회당 단가, 출시가. Selected card → green border + soft fill. CTA label echoes the selected pack ("N회권 결제하기 (₩…)").
- ⚠️ **Changed in 최종:** the per-pack usage taglines (`부담없이 한 번` / `한 달 입문용` / `두 달 학습용` / `장기 학습용`) were removed — cards now lead with the 회권 count only.
- ⚠️ **Pricing divergence note**: Figma shows ₩4,000 / ₩17,000 / ₩29,000 / ₩48,000 (10회 = ₩2,900/회). PRD pricing table below targets ₩3,900 / ₩14,900 / ₩25,000 / ₩39,900 (10회 = ₩2,500/회). Reconcile with Finance before launch — wireframe currently matches the latest Figma frame.

> 📐 **Figma:** [`24371:38213`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-38213) — 레슨권 구매_한 번에 결제만 있는 경우

**결제 페이지** — opened from `결제하기` CTA when the user has no default payment method (or chooses to switch).

```
┌────────────────────────────────────────┐
│ ←              결제                      │
│                                         │
│ 상품 정보                                │
│ ┌────────────────────────────────────┐ │
│ │ 튜터 지정권 구매 (영어)          │ │
│ │ 2026.05.21 - 2026.07.21            │ │
│ │ 구매 횟수             10개          │ │
│ │ 사용 기간             3개월         │ │
│ └────────────────────────────────────┘ │
│                                         │
│ 결제수단                                 │
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │신용카드│ │카카오페이│ │네이버페이│      │
│ └──────┘ └──────┘ └──────┘              │
│                                         │
│ 결제 금액                                │
│ ┌────────────────────────────────────┐ │
│ │ 상품 금액              50,000원     │ │
│ │ 할인 금액             -20,000원     │ │
│ │ 총 결제 금액           30,000원     │ │
│ └────────────────────────────────────┘ │
│                                         │
│ 이용약관 동의                            │
│ ○ 본 상품의 서비스 이용약관에 동의합니다.│
│                                         │
│ 상품 안내                                │
│ · 튜터 지정권은 레슨을 제공하는…       │
│ · 지정권은 활성 구독이 있어야 사용할…    │
│ · 영어 일본어 별도이며, 보유 중인…       │
│ · 동일 상품을 중복으로 구매하여…         │
│ 유효기간                                 │
│ · 유효기간은 결제일로부터 90일입니다.…   │
│ · 등록된 결제수단에서 수강 약정기간…     │
│ · 기간약정 상품이며 중도 환불 시 위약금…│
│                                         │
│ ┌────────────────────────────────────┐ │
│ │       30,000원 결제하기             │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- 결제수단 row: 3-tile picker (신용카드 / 카카오페이 / 네이버페이). When no saved method, all three tiles are inactive until tapped.
- 결제 금액 breakdown surfaces 상품 / 할인 / 총 결제 금액 lines.
- Long-form 상품 안내 + 유효기간 footer with the §5 policies inline (subscription requirement, language separation, 90d expiry, 중도 환불 위약금).
- CTA label echoes total amount.

> 📐 **Figma:** [`24371:38112`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-38112) — 한 번에 결제_결제수단이 없는 경우

**레슨권 구매 완료** — terminal success screen.

```
┌────────────────────────────────────────┐
│                                         │
│                                         │
│              ┌─────────┐                │
│              │ 🎫🎫    │                │
│              │(blue tickets)            │
│              └─────────┘                │
│                                         │
│         구매가 완료되었어요!            │
│      영어 튜터 지정권 3개 구매 완료    │
│                                         │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │                확인                  │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- Confirms purchase; CTA returns to `/my-podo/designated-tickets` (§3.6.2).
- ⚠️ **Changed in 최종:** the green ✓ checkmark was replaced by a blue ticket illustration, and the subtitle now reads `{언어} 튜터 지정권 {N}개 구매 완료` (language + count aware) instead of `튜터 지정권 구매 (영어)`.

> 📐 **Figma:** [`24371:42914`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-42914) — 레슨권 구매 완료


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
- `튜터 지정권` (NEW)
- `차단한 튜터` (existing tutor-exclusion — finalized screen in §3.6.3)

```
┌────────────────────────────────────────┐
│                마이포도                  │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │ ⬤ 이치호                            │ │
│ │   chiholee@kakao.com           ›   │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 우주 최저가 원어민 레슨 포도         │ │
│ │ 500원 체험레슨!              [500]  │ │
│ └────────────────────────────────────┘ │
│ 레슨권 및 결제                           │
│  마이 포도 플랜       영어 라이트 6개월 ›│
│  마이 쿠폰                       3개 › │
│  결제수단                  카카오페이 › │
│  튜터 지정권 [NEW]          1개 보유 › │ ← NEW
│ 튜터 관리                                │
│  찜한 튜터 관리 [NEW]                ›  │ ← NEW
│  차단 튜터 관리                       ›  │
│ 문의                                     │
│  고객센터                            ›  │
│ 설정                                     │
│  공지사항                            ›  │
│  알림 설정                           ›  │
│  버전확인                                │
│  로그아웃                                │
│                                         │
│ [GNB: 홈 · 레슨 · 예약 · AI 학습 · 마이포도]│
└────────────────────────────────────────┘
```

- Two new rows: `튜터 지정권 [NEW]` under 레슨권 및 결제 (shows current held count), `찜한 튜터 관리 [NEW]` under 튜터 관리.
- `차단 튜터 관리` (existing) stays untouched.

> 📐 **Figma:** [`24371:36767`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-36767) — 마이페이지 (entry rows)

#### 3.6.1 — `/my-podo/tutor-favorites`

```
┌────────────────────────────────────────┐
│ ←        찜한 튜터 (12명)                │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │ ⬤  Jenny [영어]                ♥  │ │
│ │     ★ 4.9 (312) │ 4번 함께한 튜터  │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ ⬤  Mark [일본어] [한국어 가능]  ♥ │ │
│ │     ★ 4.7 (88) │ 4번 함께한 튜터   │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ ⬤  Anna [영어]                 ♥  │ │
│ │     ★ 4.2 (15) │ 0번 함께한 튜터   │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ ⬤  Lisa [영어]                 ♥  │ │
│ │     ★ 4.9 (312) │ 4번 함께한 튜터  │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ ⬤  June [영어]                 ♥  │ │
│ │     ★ 4.9 (312) │ 4번 함께한 튜터  │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- Header: `찜한 튜터 (N명)`.
- Compact card rows: avatar, name, language pill, optional `한국어 가능` pill, filled red heart on right.
- Subline: `★ rating (count) │ N번 함께한 튜터`. Never-met tutors show `0번 함께한 튜터` (e.g. Anna).
- No cap on favorites.
- Tap card → tutor profile (view-only — no booking CTA from favorites).
- Favoriting a blocked tutor → confirm `차단 해제하고 찜할까요?` first (mutual exclusion).
- **내 메모** (private per-favorite memo, ≤100 chars) is **authored only on the tutor profile** (§3.3) — not surfaced inline on this list in the current frame; surfaces in the picker (§3.2) and on the profile itself.

> 📐 **Figma:** [`24371:37031`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37031) — 찜한 튜터 (신규)

#### 3.6.2 — `/my-podo/designated-tickets`

```
┌────────────────────────────────────────┐
│ ←            튜터 지정권                 │
│                                         │
│ 사용 가능한 튜터 지정권                  │
│ ┌────────────────────────────────────┐ │
│ │ 7개 보유                  ⏱ D-29   │ │ ← banner
│ │ 가장 빠른 만료 2026-06-12 (29일 후) │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │           + 지정권 더 구매            │ │
│ └────────────────────────────────────┘ │
│                                         │
│ 보유 티켓                                │
│ ┌────────────────────────────────────┐ │
│ │ 지정권 구매 · 5개          [5/3 구매] │ │
│ │ 2026-08-10 만료 (90일)              │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 무료 지정권 지급 · 1개     [5/13 지급]│ │
│ │ 2026-06-12 만료 (30일)              │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 보상 지정권 지급 · 1장   [5/16 지급]│ │ ← compensation row
│ │ 2026-06-15 만료 (30일)              │ │   present in Figma
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │              전체보기                │ │
│ └────────────────────────────────────┘ │
│                                         │
│ 사용 내역                                │
│ ┌────────────────────────────────────┐ │
│ │ 5/12 Jenny와 비즈니스 영어  [-1 사용]│
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 5/10 Mark와 프리토킹       [-1 사용]│
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- **Banner**: total held + earliest expiry (D-N countdown chip when within 30 days).
- `+ 지정권 더 구매` → §3.5.
- Held-pass rows: `지정권 구매` / `무료 지정권 지급` / `보상 지정권 지급` — each with a grant-date pill, expiry date + remaining days. (Section header is still labelled `보유 티켓` in Figma — see Terminology note.)
- **사용 내역**: log of redeemed passes with tutor + lesson context.
- Auto-use order: earliest-expiring first.
- ⚠️ **Compensation passes**: Figma frame includes a `보상 지정권 지급` row, but PRD §4.3 / §5 defer compensation passes out of v1. Either hide that row in v1 or revisit the deferral — flag for PM. (Note Figma counts this row in `장` while others use `개` — copy-cleanup TODO.)

> 📐 **Figma:** [`24371:41728`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-41728) — 튜터 지정권 (신규)

**찜 메모 (내 메모)** — private per-favorite memo (≤100 chars). Authored inline on the tutor profile (§3.3), no edit button, autosaves on blur (debounced sync while typing). Surfaced on the picker (§3.2) so users remember *why* they favorited. Never visible to the tutor or other students. Cleared when the favorite is removed.

#### 3.6.3 — `/my-podo/blocked-tutors` (차단 튜터 관리) — NEW

The existing `차단한 튜터` row now has a finalized management screen (maps to the existing `le_tutor_exclusion`).

```
┌────────────────────────────────────────┐
│ ←          차단 튜터 관리                │
│                                         │
│ 차단된 튜터  5/5                         │
│ ┌────────────────────────────────────┐ │
│ │ Emily [일본어]                      │ │
│ │ 2026. 02. 15에 만남          [해제] │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ Scott [영어]                  (grey)│ │
│ │ 2026. 02. 15에 만남          [해제] │ │
│ │ 활동 종료된 튜터                     │ │ ← red label
│ └────────────────────────────────────┘ │
│                                         │
│ 최근 만난 튜터                           │
│ ┌────────────────────────────────────┐ │
│ │ Olivia [영어]                       │ │
│ │ 1. 영어 문법 정복: 기초에서 고급까지 │ │
│ │ 2026. 02. 05에 만남          [차단] │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- **차단된 튜터 N/N** section — blocked tutors with a navy `해제` (unblock) pill. Each row shows the language pill + last-met date.
- Quit tutors render greyed with a red `활동 종료된 튜터` label but stay in the list (still unblockable) — mirrors the favorites-list treatment for inactive tutors.
- **최근 만난 튜터** section — recently-met tutors not yet blocked, each with a pink `차단` pill + the last lesson title; tapping `차단` adds a `le_tutor_exclusion` entry (and clears any favorite, per mutual-exclusion).
- Unblock (`해제`) / block (`차단`) reuse the existing tutor-exclusion add/remove with the mutual-exclusion clears described in §3.3 / §3.6.

> 📐 **Figma:** [`24380:42971`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24380-42971) — 차단 튜터 관리 (비활성화 튜터 포함)

---

### 3.7 — 튜터 탭 (tutor-first entry) — NEW

```
튜터 탭 (GNB) → 튜터 리스트 → 튜터 프로필 → 예약 페이지 (다음 레슨 + 추천 시간 자동 채움) → confirm
```

Parallel primary entry alongside §3.0's lesson-first flow. Same confirm dialog terminates both paths. Existing lesson-first flow stays unchanged (no migration).

#### 3.7.1 — Tutor tab landing

```
┌────────────────────────────────────────┐
│ ─🇺🇸 영어 ──────────  🇯🇵 일본어 ──────  │ ← language tabs
│                                         │
│ [평점 높은 순 ⌄]                  [필터] │
│ ┌────────────────────────────────────┐ │
│ │ ⬤      Keiko                  ♥  │ │
│ │ avatar  ★ 4.9 (312)               │ │
│ │ 🔊      함께한 레슨 4회            │ │
│ │ [한국어 가능] #차분함 #문법강조 +2 │ │
│ │                          [더보기 →]│ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ ⬤      Yoko  [POPULAR]        ♥  │ │
│ │ avatar  ★ 4.9 (312) · 함께한 레슨 4회│ │
│ │  #차분함 #문법강조 +2    [더보기 →]│ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ ⬤      Nanami                 ♡  │ │
│ │  ★ 4.9 (312) · 함께한 레슨 4회     │ │
│ └────────────────────────────────────┘ │
│                                         │
│ [GNB: 홈 · 레슨 · 튜터 · 예약 · AI 학습 · 마이포도]│
└────────────────────────────────────────┘
```

- Language switcher tab on top: `영어` / `일본어` (defaults to user's primary learning language; only that language's tutors shown).
- Sort/filter pills (`평점 높은 순 ⌄` + `필터`) — same sheets as §3.2.
- Tutor cards use the **same updated card shape as §3.2** (Name [+POPULAR], `★ rating (count)`, `함께한 레슨 N회`, black `한국어 가능` pill + hashtags, `더보기 →`). Tapping the card body opens the profile.
- Bottom GNB present with **튜터** active (this is a top-level tab, unlike the slot-scoped picker which has the `← 튜터 선택 / date / 🎫` header instead).

> ✅ **Canonical frame now exists.** Previously flagged as missing — the 최종 section's `24371:37511` ("튜터 선택 — 찜한 튜터 상단", with language tabs + bottom GNB) is the tutor-tab landing. It shares the card component with the §3.2 slot-scoped picker (`24371:42169`); the two differ only in chrome.

> 📐 **Figma:** [`24371:37511`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37511) — 튜터 탭 landing (찜한 튜터 상단)

#### 3.7.2 — Tutor profile (from tutor tab)

**Identical to §3.3.** Same 소개 / 메모 / 리뷰 / hashtag / audio bio data. Only difference is CTA destination:
- §3.3 CTA → confirm dialog (lesson + slot already chosen from picker)
- §3.7 CTA → booking page (lesson + slot not yet chosen)

The 차단 bar is present here too.

#### 3.7.3 — Booking page `/tutors/[tutorId]/book`

Reached from `이 튜터로 예약하기` on the §3.7 profile. Lesson + time picker on its own page.

**Default state (추천 시간 grid)**

```
┌────────────────────────────────────────┐
│ ←                            🎫 3개     │
│                                         │
│ 레슨 선택                                │
│ 다음 레슨이 자동 선택됐어요              │
│ ┌────────────────────────────────────┐ │
│ │ [thumb] Level 1                     │ │
│ │         1. 기초 영어의 첫걸음:      │ │
│ │         일상 표현부터 시작하기   ⌄ │ │ ← tap → §3.7.4
│ └────────────────────────────────────┘ │
│                                         │
│ 추천 시간                                │
│ 레슨 일정을 선택해 주세요.               │
│ ┌──────────────┐ ┌──────────────┐      │
│ │ 오늘 10:00 ✓ │ │ 오늘 10:30   │      │
│ └──────────────┘ └──────────────┘      │
│ ┌──────────────┐ ┌──────────────┐      │
│ │ 오늘 11:00   │ │ 4월 21일 21:30│     │
│ └──────────────┘ └──────────────┘      │
│ ┌──────────────┐ ┌──────────────┐      │
│ │ 4월 22일 21:00│ │ 4월 22일 21:30│    │
│ └──────────────┘ └──────────────┘      │
│ ┌────────────────────────────────────┐ │
│ │            다른 시간 보기            │ │
│ └────────────────────────────────────┘ │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │              예약 확정               │ │ ← sticky
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- **레슨 선택** card — auto-filled with student's next unfinished lesson in their active course (caption: `다음 레슨이 자동 선택됐어요`). Tapping the card opens the lesson-picker slide-up (§3.7.4).
- **추천 시간** — 6 buttons showing this tutor's soonest open 25-min slots over ~7 days, **filtered to slots where the auto-selected lesson is actually bookable** (respects existing `LectureCommandService` course/level constraints). Caption: `레슨 일정을 선택해 주세요.` Selected slot gets green outline + soft fill.
- `다른 시간 보기` outlined button → full schedule sheet.
- **예약 확정** sticky CTA — disabled until a time is chosen.
- ⚠️ **Changed in 최종:** a `🎫 N장` ticket badge was added to the top-right header (was absent in the draft).

> 📐 **Figma:** [`24371:36887`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-36887) — 예약 페이지 / 추천 시간 grid (default)

**선택된 레슨 일정 state** — after picking a slot via the schedule sheet, the 추천 시간 grid is replaced by a primary-soft card with the chosen time + `날짜 변경` button.

```
┌────────────────────────────────────────┐
│ ←                            🎫 3개     │
│ 레슨 선택                                │
│ 다음 레슨이 자동 선택됐어요              │
│ ┌────────────────────────────────────┐ │
│ │ [thumb] Level 1 · 1. 기초 영어의…  ⌄│
│ └────────────────────────────────────┘ │
│                                         │
│ 선택된 레슨 일정                         │
│ ┌────────────────────────────────────┐ │
│ │           4월 21일 06:30            │ │ ← primary-soft
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │              날짜 변경               │ │ ← outlined
│ └────────────────────────────────────┘ │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │              예약 확정               │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

> 📐 **Figma:** [`24371:36929`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-36929) — 예약 페이지 / 선택된 레슨 일정 state (🎫 N장 header added)

**Full schedule sheet** — slide-up over the booking page, reached via `다른 시간 보기`.

```
┌────────────────────────────────────────┐
│        ▬▬                              │
│ 레슨 일정을 선택해주세요.                │
│                                         │
│  오늘   내일   목                       │
│ [ 20 ]  21    22                        │
│                                         │
│ 예약 가능 시간             ● 예약 마감  │
│                                         │
│ 오전                                    │
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │10:00 │ │10:30 │ │11:00 │              │
│ └──────┘ └──────┘ └──────┘              │
│ ┌──────┐                                │
│ │11:30 │                                │
│ └─grey─┘                                │
│ 오후                                    │
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │12:00 │ │12:30 │ │13:00 │              │
│ └─grey─┘ └─grey─┘ └─grey─┘              │
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │13:30 │ │14:00 │ │14:30 │              │
│ └─grey─┘ └─grey─┘ └─grey─┘              │
│ ┌──────┐ ┌──────┐ ┌──────┐              │
│ │15:00 │ │15:30 │ │16:00 │              │
│ └─grey─┘ └──────┘ └──────┘              │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │              확인                    │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- Date strip (오늘 / 내일 / 요일 + day-of-month), selected date gets green outline.
- 오전 / 오후 groups with 3-col slot grid. White = available, grey = `예약 마감`.
- `확인` primary button — closes the sheet and updates the booking page to the 선택된 레슨 일정 state above.
- ⚠️ **Not re-rendered in 최종.** The Final section has no populated full-schedule-sheet frame (the `24371:41605` slot is an empty placeholder); link still points to the pre-최종 draft. Visually it mirrors the §3.3 view-only schedule sheet (`24371:37849`) plus a `확인` CTA.

> 📐 **Figma:** [`24214:10406`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24214-10406) — 다른 시간 보기 sheet (full schedule, pre-최종)

**예약 확정 → confirm dialog** — same `wf-dialog` used by §3.1/§3.2/§3.3. Tutor is locked (no 변경) since the user entered through the tutor profile.

```
┌────────────────────────────────────────┐
│ 레슨 일정 확인                          │
│                                         │
│  레슨명     1. 단수 명사와 가족 구성원…  │
│  레슨 일정  5월 28일(수) 09:30~09:55     │
│  튜터       Jenny                        │
│                                         │
│ ┌─────────────────────────────────────┐│
│ │ 📁-1  튜터 지정권 1개가 사용돼요   ││
│ └─────────────────────────────────────┘│
│                                         │
│   [ 취소 ]            [ 예약하기 ]      │
└────────────────────────────────────────┘
```

- Identical to the §3.2 / §3.3 confirm dialog; ticket-usage banner shows `-1` to underline consumption.

> 📐 **Figma:** [`24371:37251`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-37251) — 예약 확정 → 레슨 일정 확인 (over 예약 페이지)

#### 3.7.4 — Lesson picker (nested slide-up on booking page)

Tap the 레슨 선택 card → slide-up over the booking page. Two states share the same sheet component.

**State A — Lessons within current course**

```
┌────────────────────────────────────────┐
│        ▬▬                              │
│ ←  Level 1                              │
│                                         │
│ ┌────────────────────────────────────┐ │
│ │ 1. 명사를 활용하여 묻고 답하는…   [완료]│
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 2. 기초 영어의 첫걸음: 일상 표현…  ✓│ │ ← current
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 3. 가족과 직업을 묻고 답하기        │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ 4. 일상에서 자주 쓰는 동사 익히기   │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- Header has `←` arrow + course title (e.g., `Level 1`); tapping `←` opens State B.
- Current lesson selected with green ✓.
- Completed lessons marked with a `완료` pill (no strikethrough — the pill alone is enough).

> 📐 **Figma:** [`24371:36965`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-36965) — 현재 코스의 레슨 리스트 (lesson picker State A)

**State B — Courses list**

```
┌────────────────────────────────────────┐
│        ▬▬                              │
│ ┌────────────────────────────────────┐ │
│ │ [thumb] Start 1                     │ │
│ │         2. 기초 영어의 첫걸음:      │ │
│ │         일상 표현부터 시작하기      │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ [thumb] Start 2                     │ │
│ │         1. 기초 영어의 첫걸음: …    │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ [thumb] Level 1                  ✓ │ │ ← active course
│ │         1. 기초 영어의 첫걸음: …    │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ [thumb] Level 2                     │ │
│ │         1. 기초 영어의 첫걸음: …    │ │
│ └────────────────────────────────────┘ │
│ ┌────────────────────────────────────┐ │
│ │ [thumb] Level 3                     │ │
│ │         1. 기초 영어의 첫걸음: …    │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

- Opened by tapping the `←` arrow in State A.
- Lists all available courses with colored thumbnails (Start 1 / Start 2 / Level 1 / Level 2 / Level 3 …); each row shows the next-unfinished lesson preview as a subline.
- The active course gets a green ✓.
- Picking a course → returns to State A scoped to that course.

> 📐 **Figma:** [`24371:36961`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-36961) — 코스 리스트 (lesson picker State B)

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

#### 3.8.1 — Step 1 baseline (shared across flows)

All three flows start from the same star-picker. The selected star count determines the branch (1–2 negative / 3 neutral / 4–5 positive).

**Baseline — no rating yet** (`다음` disabled until any star is tapped)

```
┌────────────────────────────────────────┐
│                                         │
│       이번 레슨, 어떠셨나요?             │
│  솔직한 평가는 더 좋은 레슨을            │
│         만드는 데 큰 힘이 돼요.          │
│                                         │
│   ┌────────────────────────────────┐    │
│   │ (A)  Alice                     │    │
│   │      4월 26일 11:00            │    │
│   └────────────────────────────────┘    │
│                                         │
│        ☆   ☆   ☆   ☆   ☆               │
│                                         │
│   ┌────────────────────────────────┐    │
│   │             다음                │    │ ← disabled grey
│   └────────────────────────────────┘    │
│         평가하지 않고 나가기             │
└────────────────────────────────────────┘
```

> 📐 **Figma:** [`24371:38327`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-38327) — NPS_별점선택_초기 (Step 1, 최종 단일 프레임)

**Tapped state** — stars fill green (filled-bordered icon) up to the tapped count; `다음` activates.

```
┌────────────────────────────────────────┐
│       이번 레슨, 어떠셨나요?             │
│  솔직한 평가는 더 좋은 레슨을 …         │
│                                         │
│   (A)  Alice  ·  4월 26일 11:00         │
│                                         │
│        ★   ★   ☆   ☆   ☆               │ ← 2★ → negative
│                                         │
│   ┌────────────────────────────────┐    │
│   │             다음                │    │ ← enabled
│   └────────────────────────────────┘    │
│         평가하지 않고 나가기             │
└────────────────────────────────────────┘
```

- Branch routing: tap `다음` after 1–2★ → §3.8.3 negative · 3★ → §3.8.2 neutral · 4–5★ → §3.8.4 positive.
- `평가하지 않고 나가기` exits without writing NPS or showing any opt-in.
- ⚠️ **Consolidated in 최종:** the Final section ships a single Step 1 frame (`24371:38327`, shown with an example rating) rather than separate baseline / tapped frames; both states above map to it.

> 📐 **Figma:** [`24371:38327`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-38327) — NPS_별점선택 (Step 1, 최종 단일 프레임)

#### 3.8.2 — Neutral flow (3★)

Star + chips submission uses the **negative flow shape** (`아쉬웠던 점을 알려주세요.` chip set + free text — see §3.8.3 Step 2). Completion screen omits **both** the 찜 and 차단 opt-in rows.

- ⚠️ **No dedicated Figma frame for the neutral completion.** Reuse the negative completion layout (§3.8.3 Step 3) with the opt-in row removed; only `피드백 제출 완료` + thank-you copy + `확인` remain. Flag for design to ship a dedicated frame before build.

#### 3.8.3 — Negative flow (1–2★)

> ⚠️ **Not re-rendered in 최종.** The Final section only re-rendered the positive flow (Step 1 + positive chips + 찜 opt-in completion). The negative-flow frames below still point to pre-최종 draft nodes — they map to the **existing** `tutor-exclusion` 차단 opt-in, which is unchanged, so this is expected. Confirm with design if the negative chips/completion need a 최종 refresh.

**Step 2 — Negative feedback chips** — `아쉬웠던 점을 알려주세요.` Multi-select chip set; selected chips get green outline. Free-text input appears (always — used for `그 외 다른 의견` and overflow). `제출하기` enables once at least one chip is picked (text optional).

**Empty state** (no chips picked, `제출하기` disabled)

```
┌────────────────────────────────────────┐
│       아쉬웠던 점을 알려주세요.          │
│  해당하는 내용을 모두 선택해주세요.      │
│  더 나은 수업을 위해 반영됩니다!         │
│                                         │
│ [과도한 한국어 사용] [이해하기 어려운 발음]│
│ [레슨 시간 미준수]   [부정확한 레슨 내용] │
│ [튜터 측 소음 발생]  [불성실한 수업 태도] │
│ [부족한 피드백과 교정] [재미없는 레슨 주제]│
│            [그 외 다른 의견]              │
│                                         │
│   ┌────────────────────────────────┐    │
│   │           제출하기              │    │ ← disabled grey
│   └────────────────────────────────┘    │
│         평가하지 않고 나가기             │
└────────────────────────────────────────┘
```

> 📐 **Figma:** [`24214:10123`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24214-10123) — Step 2 — 부정 피드백 chips (empty)

**Chips selected (no free text yet)** — selected chips render with green outline; free-text box appears below; `제출하기` still disabled until either an extra chip is added or text is entered (per Figma — flagged for design to confirm enable-rule).

```
┌────────────────────────────────────────┐
│       아쉬웠던 점을 알려주세요.          │
│  해당하는 내용을 모두 선택해주세요. …    │
│                                         │
│ [과도한 한국어 사용] [이해하기 어려운 발음✓]│
│ [레슨 시간 미준수]   [부정확한 레슨 내용] │
│ [튜터 측 소음 발생 ✓] [불성실한 수업 태도]│
│ [부족한 피드백과 교정] [재미없는 레슨 주제]│
│            [그 외 다른 의견 ✓]            │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 다른 의견을 작성해주세요.            │ │ ← empty
│ │                                       │ │
│ └─────────────────────────────────────┘ │
│                                         │
│   ┌────────────────────────────────┐    │
│   │           제출하기              │    │ ← still disabled
│   └────────────────────────────────┘    │
│         평가하지 않고 나가기             │
└────────────────────────────────────────┘
```

> 📐 **Figma:** [`24214:10145`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24214-10145) — Step 2 — 부정 피드백 chips (selected, no text)

**Chips + free text filled** — `제출하기` activates (green).

```
┌────────────────────────────────────────┐
│       아쉬웠던 점을 알려주세요.          │
│                                         │
│ [과도한 한국어 사용] [이해하기 어려운 발음✓]│
│ [레슨 시간 미준수]   [부정확한 레슨 내용] │
│ [튜터 측 소음 발생 ✓] [불성실한 수업 태도]│
│ [부족한 피드백과 교정] [재미없는 레슨 주제]│
│            [그 외 다른 의견 ✓]            │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 수업 내용이 제 수준보다 너무         │ │
│ │ 어려워서 따라가기가 힘들었습니다.    │ │
│ │ 모르는 부분이 있어도 수업이 빠르게…  │ │
│ └─────────────────────────────────────┘ │
│                                         │
│   ┌────────────────────────────────┐    │
│   │           제출하기              │    │ ← enabled (green)
│   └────────────────────────────────┘    │
│         평가하지 않고 나가기             │
└────────────────────────────────────────┘
```

> 📐 **Figma:** [`24214:10168`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24214-10168) — Step 2 — 부정 피드백 chips (selected + free text → 제출하기 enabled)

**Step 3 — Completion + 차단 opt-in (existing)**

**Opt-in unchecked** (default — explicit opt-in)

```
┌────────────────────────────────────────┐
│                                         │
│            피드백 제출 완료              │
│        솔직한 피드백 감사해요!          │
│   개선하여 더 좋은 수업으로 보답할게요.  │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ ○  이번 튜터와 다시 레슨하지 않을래요.│ │ ← existing
│ └─────────────────────────────────────┘ │
│                                         │
│   ┌────────────────────────────────┐    │
│   │              확인                │    │ ← enabled
│   └────────────────────────────────┘    │
└────────────────────────────────────────┘
```

> 📐 **Figma:** [`24214:10191`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24214-10191) — Step 3 negative completion (opt-in unchecked)

**Opt-in checked** — green check fill on circle.

```
┌────────────────────────────────────────┐
│            피드백 제출 완료              │
│        솔직한 피드백 감사해요!          │
│   개선하여 더 좋은 수업으로 보답할게요.  │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ ✓  이번 튜터와 다시 레슨하지 않을래요.│ │ ← CHECKED
│ └─────────────────────────────────────┘ │
│                                         │
│   ┌────────────────────────────────┐    │
│   │              확인                │    │
│   └────────────────────────────────┘    │
└────────────────────────────────────────┘
```

- Tapping the row toggles the check; the opt-in fires only on `확인` tap (not on toggle).
- Maps to existing `tutor-exclusion` add. Hidden if already blocked. If currently favorited, prompts `찜 해제하고 차단할까요?`.

> 📐 **Figma:** [`24214:10202`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24214-10202) — NPS_아쉬운점제출완료 (negative completion, opt-in checked)

#### 3.8.4 — Positive flow (4–5★)

**Step 2 — Positive feedback chips** — `어떤 점이 특히 좋았나요?` Multi-select chips + optional free text. Same chip-state pattern as the negative flow (empty → selected → selected + text).

**Empty state**

```
┌────────────────────────────────────────┐
│       어떤 점이 특히 좋았나요?           │
│  해당하는 내용을 모두 선택해주세요.      │
│      따뜻한 피드백이 전달돼요.           │
│                                         │
│ [자연스러운 대화 속도]  [꼼꼼한 문법 교정] │
│ [정확한 발음 교정]   [새로운 표현 학습]   │
│ [활기차고 재미있는 수업] [친절하고 상냥한 태도]│
│            [그 외 다른 의견]              │
│                                         │
│   ┌────────────────────────────────┐    │
│   │           제출하기              │    │ ← disabled grey
│   └────────────────────────────────┘    │
│         평가하지 않고 나가기             │
└────────────────────────────────────────┘
```

> 📐 **Figma:** [`24371:36625`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-36625) — Step 2 — 긍정 피드백 chips (empty)

**Chips selected + free text input visible**

```
┌────────────────────────────────────────┐
│       어떤 점이 특히 좋았나요?           │
│                                         │
│ [자연스러운 대화 속도 ✓] [꼼꼼한 문법 교정 ✓]│
│ [정확한 발음 교정]   [새로운 표현 학습]   │
│ [활기차고 재미있는 수업] [친절하고 상냥한 태도]│
│            [그 외 다른 의견 ✓]            │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ 다른 의견을 작성해주세요.            │ │
│ └─────────────────────────────────────┘ │
│                                         │
│   ┌────────────────────────────────┐    │
│   │           제출하기              │    │
│   └────────────────────────────────┘    │
│         평가하지 않고 나가기             │
└────────────────────────────────────────┘
```

- Free-text box appears when `그 외 다른 의견` is picked (mirrors negative flow). `제출하기` enables once text is entered (or per-design rule — confirm with design).

> 📐 **Figma:** [`24371:36645`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-36645) — Step 2 — 긍정 피드백 chips (selected + free-text field)

**Step 3 — Completion + 찜 opt-in (NEW)**

```
┌────────────────────────────────────────┐
│                                         │
│            피드백 제출 완료              │
│        소중한 의견 감사해요!            │
│      튜터에게 전달되어 큰 힘이 돼요.     │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ ✓  이 튜터를 찜한 튜터에 추가할게요. │ │ ← NEW, CHECKED
│ └─────────────────────────────────────┘ │
│                                         │
│   ┌────────────────────────────────┐    │
│   │              확인                │    │ ← enabled (green)
│   └────────────────────────────────┘    │
└────────────────────────────────────────┘
```

- The 찜 opt-in row uses the same visual pattern as the existing 차단 opt-in (rounded container, circle indicator that fills green on check).
- Figma shows the opt-in **pre-checked**; this contradicts §3.8 behavior note ("Pre-checked false; explicit opt-in"). Confirm intended default with design — wireframe currently matches the Figma frame state.
- Hidden when already favorited (or already blocked — favorites and blocks are mutually exclusive, §3.6).
- Memo is **not** captured on this screen — memo is profile-only (§3.3).

> 📐 **Figma:** [`24371:36756`](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24371-36756) — Step 3 — 제출 완료 + 찜 옵트인 (NEW, positive)

#### 3.8.5 — Behavior notes (§3.8)

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
5. **Subscription co-existence** — when both exist, picker defaults to 튜터 지정권 only when a tutor is explicitly chosen; otherwise subscription stays default so users don't burn a ticket on random matching. **Multi-sub users**: redemption language is inferred from the tutor — no explicit pick.
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
