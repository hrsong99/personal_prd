# Trial Level Test PDF in the My Podo Tab

**Status:** Draft v0.1
**Author:** podo@day1company.co.kr
**Date:** 2026-05-21
**Touch repos:** `podo-backend` (`applications/podo/leveltest`), `podo-app` (`apps/web` — `my-podo`)
**grape:** no change
**Feature flag:** None — the in-app section is self-gating (hidden when the user has no PDF). The alimtalk link change is a hard cutover — see §9.

> Surface the trial level test report PDF (체험 레벨테스트 리포트) inside the app's **My Podo** (마이 포도) tab, instead of it living only inside a one-time KakaoTalk alimtalk. Adds one backend read endpoint, one new web route that renders the PDF, a My Podo menu entry, a home-screen entry point for not-yet-purchased trial takers, and changes the alimtalk button to deep-link into that route. No database schema change.

---

## 1. Problem

When a user finishes a trial level test, a PDF report is generated (AWS Lambda → S3) and delivered **once**, as a button inside a KakaoTalk alimtalk. Today that button (`reportLink`) opens the PDF in a Google Docs viewer in a mobile browser:

```
https://docs.google.com/gview?url={encoded S3 url}&embedded=true
```

Problems with this:

- **The report is throwaway.** It lives only in one alimtalk message. There is no way to find it again later — nothing in the app shows it.
- **It opens in a browser, not the app.** It does not bring the user into the product.
- **No home for users with multiple reports.** A user can take the level test more than once, and can take it in both English and Japanese. There is no place that collects these.

We want the PDF to have a permanent home in the **My Podo** tab, and we want the alimtalk to deep-link into that home (opening the app) rather than into a browser.

## 2. Goals & Non-Goals

### Goals

1. Add a route in the app that shows the user's trial level test PDF: **`/my-podo/level-test`**.
2. Render the PDF in-app via an iframe pointing at the existing PDF viewer `https://podo-pdf.pages.dev/?url=`.
3. Add a **"체험 레슨 레벨테스트 결과"** entry at the top of the **레슨 관리** section in My Podo, so the report is discoverable without the alimtalk.
4. Handle a user who took the test in **both EN and JP**: show a top tab to switch languages. Show the PDF directly (no tab) when there is only one language.
5. Handle a user who took the test **multiple times** in one language: show the latest report.
6. Change the alimtalk `reportLink` to the **open-in-app deep link** for this route, so tapping it opens the app.
7. Give not-yet-purchased trial takers a way back to their report from the **home screen**: the no-수강권 greeting card surfaces a "레벨테스트 결과" button.

### Non-Goals

- **Not** changing how the PDF is generated. The Lambda → S3 → Redis-queue → alimtalk pipeline is untouched; we only add a new *reader* and change one link.
- **Not** showing report *history*. Only the latest report per language is shown — older reports for the ~6% of users who retook the test are not listed (see Q-3).
- **Not** building a PDF viewer. We embed the existing `podo-pdf.pages.dev` viewer in an iframe.
- **Not** changing the Kakao alimtalk templates themselves. Only the value bound to `reportLink` changes; the template button stays a web-link button (the deep link is still an `https://` URL).
- No `grape` change. (The admin "레벨테스트 리포트 재전송" tool re-enqueues a message that flows through the same backend path — it inherits the new link automatically.)
- **Not** touching the other home greeting states — `SCHEDULED_CLASS` (upcoming-lesson card) and the booking-recommendation light card are unchanged. Only the `NO_TICKET` state is restyled (see §5.6).
- No database schema change.

## 3. Current behavior

### 3.1 PDF generation & delivery (unchanged by this PRD)

```
Trial level test completed
   → AWS Lambda "podo-pdf" generates the PDF, uploads to S3
       bucket podo-pdf-report, key {studentId}/{yyyymmdd}[_jp]_report.pdf
   → Lambda enqueues a message on Redis queue "leveltest"
   → LevelTestServiceImpl.receiveMessageCron() runs every 5 min,
     reads the queue, and sends the alimtalk
   → a row is also persisted to le_level_test (incl. the S3 url)
```

### 3.2 The alimtalk link — what changes

`podo-backend` — `LevelTestServiceImpl.receiveMessageCron()`, **`LevelTestServiceImpl.java:79–83`**:

```java
Map<String, Object> extras = new HashMap<>();
extras.put("classLink", "https://podospeaking.com/wecandoit");
extras.put("reportLink", "https://docs.google.com/gview?url=" + encodedUrl + "&embedded=true");  // line 81
notificationService.makeAndSend(templateCode, Integer.parseInt(user.getId()), podoUserDto, dto, extras);
```

- `reportLink` (line 81) is the only live producer of the report link. The `sendAlimTalk(...)` method below it (`:106–126`, which sets `reportLink` again at `:117`) is **dead code** — its only caller is commented out (`:75–78`), as is its `CreateCommonSendLog` call (`:125`).
- Templates by language/level (`getTemplateCode`, `:90–104`): JP level 1 → `PD_TRIAL_ENDRPT_JP_1`, JP level >1 → `PD_TRIAL_ENDRPT_JP_2`, EN → `PD_MKT_TRIAL_ENDRPT`.

### 3.3 What already exists and is reusable

**Backend** — `LevelTestServiceImpl` already has read methods, but **no controller endpoint exposes them**:
- `getLatestLevelTestByLangOrNull(studentId, langType)` — latest `PodoLevelTestDto` for a language.
- `getLevelTests(studentId)` — all level tests for a student as `List<PodoLevelTestDto>`.
- `PodoLevelTestController` (`/api/v2/leveltest`) today exposes only `POST /` (register), `GET /check-submit`, `POST /submit`, `POST /selectLevel`. `selectLevel` already uses `@AuthenticationPrincipal AuthenticatedUserDto user` — the auth pattern for the new endpoint.

**Frontend (`podo-app`, `apps/web` — a webview-rendered Next.js app):**
- My Podo page: `apps/web/src/app/(internal)/my-podo/page.tsx` — 5 sections (`ProfileSection`, `SubscriptionSection`, `LessonManageSection`, `CustomerCenterSection`, `SettingSection`), all from `@features/my-podo-sections`.
- Sibling route precedent: `my-podo/notices` + `my-podo/notices/[boardId]` — same `(internal)/my-podo/*` pattern, with an entity at `entities/notice` and a view at `views/notice-detail`.
- Open-in-app deep-link router: `apps/web/src/app/open-in-app/[[...path]]/page.tsx` — a **generic** optional catch-all. `…/open-in-app/my-podo/level-test` reconstructs to `/my-podo/level-test` and forwards query params. `https://podo.re-speak.com/open-in-app` is already a registered deep-link prefix in `apps/native/app.config.ts` (with `stage-` / `dev-` variants).
- Top-tab component: `TabsV1` / `TabsV1List` / `TabsV1Trigger` / `TabsV1Content` from `@podo-app/design-system-temp`. Live example with URL-synced tabs: `apps/web/src/views/my-coupon/view.tsx`.
- The app has **no PDF viewer** today (AI trial reports are PNGs via `next/image`; notices render HTML). This feature introduces the iframe approach.

### 3.4 The home screen greeting card

`apps/web` — `widgets/greeting/hooks/use-greeting-status.ts` picks one greeting card state from the user's ticket/lesson state. The relevant one here is **`NO_TICKET`** — selected when `hasActiveTicket === false` (the user has no active 수강권):

- It renders today as a **dark card** (`features/home-greeting/ui/states/no-ticket-state.tsx`, on the `bg-gray-900` `GreetingLayout` base): title "{name}님, 안녕하세요!", subtitle "앗! 아직 수강하고 있는 수강권이 없네요. / 포도와 함께 꾸준한 스피킹 학습을 시작해볼까요?", and a single button "수강권 둘러보기" → `/subscribes/tickets`.
- The has-수강권 states render a **light card** (`widgets/home-greeting/ui/home-no-booking-card.tsx`) — a green illustration band over a white body with a two-button row.
- The home page (`app/(internal)/home/page.tsx`) is a Server Component that already prefetches subscription data server-side; the greeting reads from that prefetched/hydrated data.

## 4. Data model & the report-selection rule

No schema change. The report is `le_level_test.url` (DB `gwatop`):

| Column | Use |
|---|---|
| `student_id` | the app user — matches the authenticated user (see Q-2) |
| `language` | only ever `EN` or `JP` (confirmed — exactly two values) |
| `level`, `level_name` | display metadata, e.g. `2` / "아장아장 베이비" |
| `url` | the S3 PDF link, e.g. `https://podo-pdf-report.s3.ap-northeast-2.amazonaws.com/{id}/20260521_jp_report.pdf` |
| `created_at` | recency, for picking the latest |

### Prod numbers (as of 2026-05-21) — why the edge cases matter

- **29,095** students have ≥1 level test; **32,174** rows (19,592 JP / 12,582 EN).
- **Multiple tests, same language: ~6.3%** — 1,898 of 29,934 student-language pairs have ≥2 tests (a few users have 15–18).
- **Took both EN and JP: 839 students (~2.9%)** — small but real; this is the cohort that needs the language tab.
- **~8.8% of rows have a null/empty `url`** (2,822 total; still ~8.4% — 74/879 — in the last 30 days, so this is *ongoing*, not legacy). These rows are **not failed tutor reports**: they come from a separate "레벨 강제 선택" path (`POST /api/v2/leveltest/selectLevel`, shipped 2025-05-11) where the user picks a trial level directly on the home greeting without scheduling a tutor-led test. A `le_level_test` row therefore represents *either* a completed tutor level test (has `url`) *or* a self-selected level (no `url`); the selection rule below intentionally filters the self-selected ones out.

### Selection rule

> **Per language, return the most recent `le_level_test` row whose `url` is non-null and non-empty.**

This single rule covers all three edge cases at once:
- multiple tests in a language → the most recent one wins;
- the latest test has a null `url` → fall back to the most recent test that *does* have one, rather than showing a broken viewer;
- a language with no usable report at all → that language is simply absent (and if both are absent, the My Podo entry does not render).

## 5. Proposed changes

### 5.1 `podo-backend` — new read endpoint

**New endpoint** on `PodoLevelTestController`:

```
GET /api/v2/leveltest/my      (authenticated; @AuthenticationPrincipal AuthenticatedUserDto user)
```

Response — at most two entries, one per language, already filtered and deduped by the §4 rule:

```json
[
  { "language": "EN", "level": 3, "levelName": "원어민 동료있는 인턴",
    "url": "https://podo-pdf-report.s3.ap-northeast-2.amazonaws.com/.../20260521_report.pdf",
    "createdAt": "2026-05-21T04:12:47Z" },
  { "language": "JP", "level": 2, "levelName": "아장아장 베이비",
    "url": "https://podo-pdf-report.s3.ap-northeast-2.amazonaws.com/.../20260521_jp_report.pdf",
    "createdAt": "2026-05-21T08:25:44Z" }
]
```

Implementation:
- Add `getMyLevelTestReports(Integer studentId)` to the level test service. Take `getLevelTests(studentId)`, drop rows with a null/empty `url`, then for each `language` keep the row with the greatest `created_at` (equivalently the greatest `id`). Returns 0–2 entries.
- Add the matching delegating method to `LevelTestGateway` (the controller calls the gateway, mirroring the existing endpoints).
- The controller passes `user.getId()` — never a client-supplied id — so a user can only read their own reports.

### 5.2 `podo-backend` — change the alimtalk link

In `LevelTestServiceImpl.receiveMessageCron()`, replace the `reportLink` value (`:81`):

```java
// before
extras.put("reportLink", "https://docs.google.com/gview?url=" + encodedUrl + "&embedded=true");

// after
extras.put("reportLink", appBaseUrl() + "/open-in-app/my-podo/level-test?lang=" + dto.getLanguage());
```

- `appBaseUrl()` resolves per environment, matching the existing pattern in `LectureGateway`: prod → `https://podo.re-speak.com`, stage → `https://stage-podo.re-speak.com`, dev/local → `https://dev-podo.re-speak.com`.
- `?lang=` (`EN` / `JP`, straight from `dto.getLanguage()`) pre-selects the correct tab for bilingual users; the open-in-app router forwards query params.
- After this change, `encodedUrl` (`:74`) is no longer used by the live path — remove it.
- No Kakao template change: the button stays a web-link button; only the bound URL changes. (The dead `sendAlimTalk` method may be left as-is or deleted as cleanup — out of scope.)

### 5.3 `podo-app` — the in-app PDF view

**New entity** `apps/web/src/entities/level-test/` (api + model), mirroring `entities/notice`: a query that calls `GET /api/v2/leveltest/my` with the bearer token and validates the response with a zod schema.

**New route** `apps/web/src/app/(internal)/my-podo/level-test/page.tsx` — mirrors the notices page: protected session, `FullTopNavigation` title **"체험 레슨 레벨테스트 결과"**, renders the new view.

**New view** `apps/web/src/views/level-test/view.tsx`, given the 0–2 reports:
- **0 reports** — every entry point to this route (My Podo row §5.4, home card button §5.6, alimtalk link §5.2) only renders when the user has a usable report, so reaching this state requires typing the URL directly and should be vanishingly rare in practice. Show a minimal neutral empty state — e.g. "표시할 레벨테스트 리포트가 없어요" — with no CTA in v1 (there is no in-app screen to schedule a tutor-led level test).
- **1 language** — render the PDF directly, no tab.
- **2 languages** — render `TabsV1` top tabs, each tab showing that language's PDF. Tab labels are "영어" / "일본어", each with the existing flag PNG in `apps/web/public` (`assets/podo/icon_flag_en.png` / `assets/podo/icon_flag_jp.png`). Sync the selected tab to a `?lang=` URL param (so the alimtalk's `?lang=` lands on the right tab); pattern: `views/my-coupon/view.tsx`.
- The PDF itself, in every case:

  ```tsx
  <iframe
    src={`https://podo-pdf.pages.dev/?url=${encodeURIComponent(report.url)}`}
    className="w-full h-full" />
  ```

  The `?url=` value **must be URL-encoded**. `podo-pdf.pages.dev` was checked and returns no `X-Frame-Options` / `frame-ancestors` restriction, so it embeds in an iframe. The PDF is the full designed report (mascot, level name, level explanation, 총점, 영역별 진단 sections); the app only frames it under the native tab bar — it does not re-render that content natively.

### 5.4 `podo-app` — the My Podo entry (레슨 관리 section)

The report is reached from My Podo via a row labelled **"체험 레슨 레벨테스트 결과"** at the **top of the 레슨 관리 section**, linking to `/my-podo/level-test`. No new section component — the row is added to the existing `LessonManageSection`.

- **`LessonManageSection`** (`apps/web/src/features/my-podo-sections/ui/lesson-manage-section/lesson-manage-section.tsx`) gains a `hasLevelTestReport: boolean` prop. When `true`, it renders a `Link` row **first** in its inner `VStack` — above 학습 통계 / 차단 튜터 관리 — using the same row shape as the others (`HStack` + `Typography size="h3"` label + `ArrowRightIcon`), label "체험 레슨 레벨테스트 결과", `href="/my-podo/level-test"`.
- **`hasLevelTestReport` is computed on the server.** `my-podo/page.tsx` is an async Server Component (`dynamic = 'force-dynamic'`) that already `await`s data and already passes a server-computed boolean into this same component (`isExtendUser`). Add `GET /api/v2/leveltest/my` to the page's server-side fetches and pass `hasLevelTestReport` to `LessonManageSection` exactly as `isExtendUser` is passed today.
- **Self-gating, no flash.** When the user has zero usable reports the row simply is not rendered — and because the prop is server-computed, the initial HTML already either contains the row or does not (zero flash, zero layout shift). **Do not** fetch the level test data client-side and hide the row after render — that flashes (row appears, then disappears).

### 5.5 Data

No migration, no backfill. The feature reads existing `le_level_test` rows.

### 5.6 `podo-app` — home screen greeting card (`NO_TICKET` state)

Per the product decision: **the dark `NO_TICKET` card is retired — all no-수강권 users move to the light card**, and trial-report holders additionally get a "레벨테스트 결과" button on it. The trigger is "no active 수강권" (the existing `NO_TICKET` condition, `hasActiveTicket === false`) — it does not distinguish never-purchased from lapsed/expired users.

- **Re-style:** re-implement the `NO_TICKET` state (`no-ticket-state.tsx`) on the **light card layout** that `HomeNoBookingCard` already uses (green illustration band → white body → button row). Title and subtitle copy are unchanged ("…수강권이 없네요 …시작해볼까요?"). `NO_TICKET` no longer uses the dark `GreetingLayout` base; if nothing else uses that dark base, it becomes dead code and can be removed (verify first).
- **Generalize the light card:** the `HomeNoBookingCard` layout (or a layout extracted from it) must support **no course preview** and a **1- or 2-button row with caller-supplied labels and handlers**. `HomeNoBookingCard`'s own usage (the booking-recommendation card) stays unchanged.
- **Buttons** — the `NO_TICKET` card reads `GET /api/v2/leveltest/my`:
  - **has ≥1 usable report** → two buttons: "레벨테스트 결과" (ghost, left — kept short to fit the two-button row; the My Podo row uses the full "체험 레슨 레벨테스트 결과") → in-app `router.push('/my-podo/level-test')`; "수강권 둘러보기" (primary, right) → `/subscribes/tickets`.
  - **no usable report** → one full-width primary button "수강권 둘러보기" → `/subscribes/tickets` (today's behavior, just on the light card).
- **No change to `use-greeting-status.ts` or the status enum.** `NO_TICKET` stays a single status; the 1-vs-2-button split is internal to the card, driven by whether the level test query returned a report.
- **No flash:** `home/page.tsx` prefetches `GET /api/v2/leveltest/my` server-side alongside its existing prefetches, so the button count is decided from hydrated data — same server-render principle as §5.4. Do not fetch it client-side after render.
- The "레벨테스트 결과" button here is plain in-app navigation (`router.push`); the open-in-app deep link form (§5.2) is only for external entry points like the alimtalk.

> Note: this restyles the home card for **every** non-purchaser, not only trial-report holders — the no-report single-button case is also affected. Design should confirm the light single-button card before ship.

## 6. Behavior matrix

**My Podo tab & `/my-podo/level-test` route:**

| User state | My Podo 레슨 관리 row | `/my-podo/level-test` renders |
|---|---|---|
| No level test at all, or only self-selected a level (all rows have null `url`) | hidden | empty state (only if deep-linked directly) |
| 1 language with a usable PDF | shown | PDF iframe, no tab |
| Has a tutor report plus a later self-selected level (newer row's `url` is null) | shown | PDF iframe of the most recent row with a `url` (the tutor report) |
| Both EN + JP usable (~2.9%) | shown | EN/JP top tabs; `?lang=` selects the initial tab |
| Retook same language (~6.3%) | shown | only the latest usable report for that language |

**Home greeting card — `NO_TICKET` state** (no active 수강권):

| User state | Card | Buttons |
|---|---|---|
| No active 수강권, has a usable trial report | light card, no-수강권 copy | "레벨테스트 결과" → `/my-podo/level-test`  ·  "수강권 둘러보기" → `/subscribes/tickets` |
| No active 수강권, no usable trial report | light card, no-수강권 copy | "수강권 둘러보기" (full-width) → `/subscribes/tickets` |
| Has active 수강권 | unchanged — booking-recommendation / scheduled-class card | unchanged |

**Alimtalk:** the trial-end alimtalk button (`reportLink`) opens `…/open-in-app/my-podo/level-test?lang={EN|JP}` — which opens the app on that route (or, with no app installed, the open-in-app router's fallback — see Q-1).

## 7. Deep link spec

| | Value |
|---|---|
| In-app route | `/my-podo/level-test` (optional `?lang=EN` \| `?lang=JP`) |
| Deep link (prod) | `https://podo.re-speak.com/open-in-app/my-podo/level-test?lang={EN\|JP}` |
| Stage / dev | `https://stage-podo.re-speak.com/...`, `https://dev-podo.re-speak.com/...` |
| Routing code needed | none — `open-in-app/[[...path]]` is a generic catch-all and the prefix is already registered in `apps/native/app.config.ts` |

## 8. Open questions

- **Q-1 — Non-app trial recipients (the key product decision).** The old `gview` link opened the PDF in *any* mobile browser. The new deep link, on a phone **without the app installed**, sends the user to the app store (open-in-app router fallback) — i.e. to the store, *not* to their report. Trial-end report recipients are exactly the cohort least likely to already have the app. Decide one of: (a) accept it — treat the report as an app-install funnel (the alimtalk's other button, `classLink`, already pushes signup); or (b) make the open-in-app landing page, when no app is detected, fall back to the web PDF viewer (`podo-pdf.pages.dev/?url=…`) instead of the store. (b) preserves universal PDF access but is extra scope in the open-in-app router.
- **Q-2 — `student_id` identity.** This assumes `le_level_test.student_id` equals the authenticated app user's id. Level tests are taken during the trial flow; if a user took the trial under a different account/identity than the one they log into the app with, `GET /my` returns nothing for them. Confirm the trial → app-account id is the same.
- **Q-3 — Report history.** v1 shows only the latest report per language. The ~6% who retook the test cannot see older reports. Confirm that is acceptable for v1 (recommended: yes — keep it simple).
- **Q-4 — Why ~8% of rows have a null `url`.** *Answered.* They are not failed tutor reports; they are "레벨 강제 선택" rows from `POST /selectLevel` (shipped 2025-05-11), where the user picks a trial level directly on the home greeting. See §4. The selection rule already excludes them by design; no further action needed for this PRD.
- **Q-5 — Universal link from inside KakaoTalk.** The alimtalk button opens inside KakaoTalk's in-app browser; triggering the native app from another app's webview via a universal link is historically flaky on some OS versions. QA the alimtalk button on real iOS and Android devices.

## 9. Rollout

- **Ship order:**
  1. `podo-backend` — the `GET /api/v2/leveltest/my` endpoint. Purely additive; safe to ship any time.
  2. `podo-app` (`apps/web`) — the `level-test` entity, the `/my-podo/level-test` route, the `LevelTestSection` My Podo entry, and the §5.6 `NO_TICKET` home-card change. The My Podo entry and the home card are self-gating; ship after step 1 so the endpoint they read already exists.
  3. `podo-backend` — the §5.2 alimtalk `reportLink` change. Ship only *after* step 2 is live in production, so the deep link never lands on a 404.
- The `/my-podo/level-test` route is a web route inside the webview, so it goes live with the `apps/web` deploy — **no native app-store release is required** (the open-in-app prefix is already registered natively).
- **The alimtalk change is a hard cutover** (no flag): once it deploys, every new trial-end report uses the deep link. If Q-1 is decided as option (b), that fallback work should land before this cutover.
- **Risk:** low-to-moderate. The level test reader, route, and My Podo section are additive and self-gating. The broader-blast-radius change is §5.6 — it restyles the home card for *every* non-purchaser; the real product risks are Q-1 (non-app users losing direct PDF access) and design sign-off on the retired dark card.
- **QA:** verify the §6 matrices — My Podo entry hidden when no report; single-language shows no tab; bilingual shows EN/JP tabs with `?lang=` selecting the right one; multiple tests show only the latest; null-`url` latest falls back to an older PDF; the iframe renders the PDF on iOS and Android webviews; the alimtalk button opens the app on the correct tab (Q-5). Home card: `NO_TICKET` users with a report see the two-button light card and those without see the one-button light card — with **no flash** of the wrong button count; has-수강권 users' cards are unchanged.

## 10. Summary

| | Before | After |
|---|---|---|
| Where the PDF lives | one alimtalk message only | route `/my-podo/level-test` + a 레슨 관리 row in My Podo + a home-card button for non-purchasers |
| Alimtalk `reportLink` | `docs.google.com/gview?url=…` (browser) | `…/open-in-app/my-podo/level-test?lang=…` (opens the app) |
| In-app PDF rendering | none | iframe → `podo-pdf.pages.dev/?url=` viewer |
| Backend endpoint | none for reading reports | `GET /api/v2/leveltest/my` (latest usable report per language) |
| Multiple tests, same language | n/a | latest usable report shown |
| EN + JP both taken | n/a | EN/JP top tab; single language shows no tab |
| Test row with null `url` (~8%) | n/a | falls back to most recent test with a PDF; else entry hidden |
| Home `NO_TICKET` card | dark card, single "수강권 둘러보기" button | light card; trial-report holders also get a "레벨테스트 결과" button |
| Schema change | — | none |
| Repos touched | — | `podo-backend`, `podo-app` (not `grape`) |
