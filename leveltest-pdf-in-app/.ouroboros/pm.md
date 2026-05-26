# Trial Level Test Report in My Podo

*Created At: 2026-05-26T02:04:08.401511+00:00*

## Goal

Move the trial level test PDF (체험 레벨테스트 리포트) from a one-time KakaoTalk alimtalk button to a permanent home inside the app's My Podo tab, so users can access their report anytime.

## User Stories

1. **As a** Trial level test taker (single language), **I want to** Navigate to My Podo → 레슨 관리 and tap '체험 레슨 레벨테스트 결과' to view my PDF report, **so that** I can access my level test result anytime without relying on a one-time alimtalk message.
2. **As a** Bilingual trial test taker (~3% of test takers), **I want to** View both EN and JP reports via top tabs on the level test page with ?lang= URL sync, **so that** I can switch between my reports for each language I tested.
3. **As a** Repeat trial test taker (~6% of test takers), **I want to** See my latest report per language automatically, **so that** I always see my most recent and relevant result without confusion from outdated reports.
4. **As a** Trial test taker receiving alimtalk, **I want to** Tap the reportLink button in KakaoTalk and be deep-linked into the app's level test page, **so that** I land directly on my report inside the app instead of an external Google Docs viewer.
5. **As a** Non-app user receiving alimtalk, **I want to** Tap the reportLink deep link and be directed to the App/Play Store, **so that** I'm funneled to install the app where my report will be permanently available.
6. **As a** No-수강권 user with trial report, **I want to** See a '레벨테스트 결과' ghost button alongside '수강권 둘러보기' on the home screen greeting card, **so that** I have a shortcut to my report from the home screen and am also prompted to purchase.
7. **As a** No-수강권 user without trial report, **I want to** See the unified light greeting card with a single '수강권 둘러보기' CTA, **so that** I get a clean, consistent home screen experience directing me to purchase.

## Constraints

- No DB schema change, no migration — query existing le_level_test table only
- No feature flag — self-gating in app (row only appears if user has report data); alimtalk link is a hard cutover
- Selection rule: per language, latest le_level_test row with non-null url (excludes 레벨 강제 선택 rows)
- Server-rendered gating — no client-side flash for My Podo row visibility or home card button split
- Touch repos limited to podo-backend and podo-app (apps/web only) — no grape change, no native app change
- No web fallback for non-app users — deep link → App/Play Store (install funnel), matching classLink posture
- No native release required — route lives in apps/web (webview-served Next.js); open-in-app prefix already registered in apps/native
- Alimtalk template link cutover ships only after apps/web deploy is verified live (deployment ordering constraint)
- Dark vs. light home card retirement is purely visual — same CTA content, no conversion path lost
- Design sign-off required on the light single-button card variant before ship (PRD §5.6)

## Success Criteria

1. All trial test takers can find their report anytime in My Podo → 레슨 관리 section
2. Bilingual users (~3%) see both EN and JP reports via language tabs
3. Repeat testers (~6%) see only the latest report per language
4. Alimtalk reportLink button deep-links into the app and opens the correct language tab
5. Home screen greeting card renders 1-button (no report) vs. 2-button (has report) split without flash
6. Non-app alimtalk recipients are directed to App/Play Store (install funnel)
7. No regression for no-수강권 users — '수강권 둘러보기' CTA preserved on unified light card

## Assumptions

- le_level_test.student_id maps to the authenticated app user id (Q-2, to be verified during implementation)
- v1 ships without report history — only latest per language (Q-3, confirmed by silence)
- The open-in-app prefix is already registered in apps/native/app.config.ts for prod/stage/dev, so no native release is in the critical path
- Dark and light NO_TICKET greeting cards carry identical title, subtitle, and CTA ('수강권 둘러보기' → /subscribes/tickets) — difference is purely visual styling
- The home card hasActiveTicket === false condition is homogeneous across never-purchasers, lapsed subscribers, and expired trial users
- API endpoint GET /api/v2/leveltest/my returns 0-2 entries (one per language max)
- PDF rendering uses existing podo-pdf.pages.dev viewer in an iframe — no new PDF infrastructure needed
- KakaoTalk in-app browser correctly handles universal links to the open-in-app router (to be QA'd per Q-5)

## Decide Later

The following items were deferred or identified as premature at this stage. They should be revisited when more context is available:

- Q-2: Confirm le_level_test.student_id matches the authenticated app user id (verification task for implementation)
- Q-5: QA the alimtalk button on real iOS/Android — KakaoTalk in-app browser universal link reliability (QA checklist item)
- Report history — v1 shows only the latest report per language, no historical view
- Web fallback PDF viewer for non-app users tapping alimtalk deep link
- No additional soak period or staged rollout between app release and alimtalk template change (not needed due to web-deploy gating)

## Design References

Finalized Figma designs (file: `-PODO- App Update`, `K2pX4mYjQ7mMnnKbXxox3B`):

| # | Surface | User stories | Figma node |
|---|---|---|---|
| 1 | Home screen — `NO_TICKET` light greeting card with **two-button row** ("레벨테스트 결과" ghost + "수강권 둘러보기" primary) | US #6, US #7 | [node 24184-1554](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24184-1554) |
| 2 | My Podo tab — "체험 레슨 레벨테스트 결과" row at top of **레슨 및 튜터 관리** section | US #1, US #3 | [node 24222-37831](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24222-37831) |
| 3 | `/my-podo/level-test` — single-language report view (no tab, PDF body) | US #1, US #3 | [node 24222-38340](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24222-38340) |
| 4 | `/my-podo/level-test` — bilingual report view (🇺🇸 영어 / 🇯🇵 일본어 top tabs) | US #2 | [node 24222-38255](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24222-38255) |

Notes from the designs:
- Design #2 confirms the row label is "체험 레슨 레벨테스트 결과" and it sits **above** 학습 통계 / 차단 튜터 관리 within the (renamed) "레슨 및 튜터 관리" section.
- Design #3 / #4 confirm the report body itself stays inside the embedded PDF — the app only frames it under `FullTopNavigation` ("체험 레슨 레벨테스트 결과") and, when bilingual, a `TabsV1` row with flag emoji + label.
- Design #1 confirms the two-button row order: ghost "레벨테스트 결과" on the left, primary "수강권 둘러보기" on the right.

## Components

### Backend (`podo-backend`)

**New**
- `PodoLevelTestController` — add `GET /api/v2/leveltest/my` handler using `@AuthenticationPrincipal AuthenticatedUserDto user` (auth pattern from existing `selectLevel`).
- `LevelTestServiceImpl.getMyLevelTestReports(Integer studentId)` — implements §4 selection rule (drop null/empty `url`, keep latest `created_at` per `language`).
- `LevelTestGateway` — delegating method that the controller calls (mirrors existing endpoints).

**Modify**
- `LevelTestServiceImpl.receiveMessageCron()` at `LevelTestServiceImpl.java:81` — replace `reportLink` value from `docs.google.com/gview?url=…` to `appBaseUrl() + "/open-in-app/my-podo/level-test?lang=" + dto.getLanguage()`. Remove the now-unused `encodedUrl` at `:74`.
- Add per-env `appBaseUrl()` resolver mirroring the pattern in `LectureGateway` (prod / stage / dev hosts).

**Unchanged**
- Kakao templates `PD_TRIAL_ENDRPT_JP_1`, `PD_TRIAL_ENDRPT_JP_2`, `PD_MKT_TRIAL_ENDRPT` — only the bound `reportLink` value changes; the template stays a web-link button.
- Dead `sendAlimTalk(...)` at `LevelTestServiceImpl.java:106–126` — leave as-is (out of scope cleanup).

### Frontend (`podo-app`, `apps/web`)

**New**
- `apps/web/src/entities/level-test/` — entity (api + zod model), mirror of `apps/web/src/entities/notice/`. Calls `GET /api/v2/leveltest/my` with bearer token.
- `apps/web/src/app/(internal)/my-podo/level-test/page.tsx` — route. Protected session, `FullTopNavigation` title "체험 레슨 레벨테스트 결과", renders the new view. Mirrors `apps/web/src/app/(internal)/my-podo/notices/page.tsx`.
- `apps/web/src/views/level-test/view.tsx` — view; handles 0 / 1-language (no tab) / 2-language (`TabsV1` with `?lang=` URL sync) cases. Embeds PDF via `<iframe src="https://podo-pdf.pages.dev/?url={encodeURIComponent(report.url)}" />`. See [Figma #3](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24222-38340) and [Figma #4](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24222-38255).

**Modify**
- `apps/web/src/features/my-podo-sections/ui/lesson-manage-section/lesson-manage-section.tsx` — add `hasLevelTestReport: boolean` prop. When `true`, render a `Link` row **first** in the inner `VStack` (above 학습 통계 / 차단 튜터 관리): `HStack` + `Typography size="h3"` "체험 레슨 레벨테스트 결과" + `ArrowRightIcon`, `href="/my-podo/level-test"`. See [Figma #2](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24222-37831).
- `apps/web/src/app/(internal)/my-podo/page.tsx` — server-side fetch `GET /api/v2/leveltest/my` (same pattern as existing `isExtendUser`), pass `hasLevelTestReport` to `LessonManageSection`. No client fetch (no flash).
- `apps/web/src/features/home-greeting/ui/states/no-ticket-state.tsx` — re-implement on the light card layout. Title/subtitle copy unchanged. Reads `GET /api/v2/leveltest/my` from hydrated server data: has-report → two-button row ("레벨테스트 결과" ghost → `router.push('/my-podo/level-test')`, "수강권 둘러보기" primary → `/subscribes/tickets`); no-report → single full-width "수강권 둘러보기". See [Figma #1](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24184-1554).
- `apps/web/src/widgets/home-greeting/ui/home-no-booking-card.tsx` — generalize layout (or extract a shared layout) to support **no course preview** and a **1- or 2-button row with caller-supplied labels and handlers**. Existing booking-recommendation usage unchanged.
- `apps/web/src/app/(internal)/home/page.tsx` — add `GET /api/v2/leveltest/my` to server-side prefetches so the `NO_TICKET` card's button count is decided from hydrated data.
- `apps/web/src/widgets/greeting/hooks/use-greeting-status.ts` — **no change**. `NO_TICKET` stays a single status; the 1-vs-2-button split is internal to the card.

**Reuse**
- `TabsV1` / `TabsV1List` / `TabsV1Trigger` / `TabsV1Content` from `@podo-app/design-system-temp`. URL-synced-tab reference: `apps/web/src/views/my-coupon/view.tsx`.
- `FullTopNavigation`, `Typography`, `HStack`, `VStack`, `ArrowRightIcon`.
- Flag assets: `apps/web/public/assets/podo/icon_flag_en.png`, `apps/web/public/assets/podo/icon_flag_jp.png`.
- `apps/web/src/app/open-in-app/[[...path]]/page.tsx` — generic catch-all; `/open-in-app/my-podo/level-test?lang=…` already resolves correctly. No router code needed.
- PDF viewer: `https://podo-pdf.pages.dev/?url=` (verified: no `X-Frame-Options` / `frame-ancestors`, embeds in iframe).

**Verify-then-delete (cleanup)**
- `GreetingLayout` (dark `bg-gray-900` base) — if `NO_TICKET` was the only consumer, remove after the light-card migration. Grep before deleting.

### Native (`podo-app`, `apps/native`)

**Unchanged** — `apps/native/app.config.ts` already registers the open-in-app deep-link prefixes (`podo.re-speak.com` / `stage-podo.re-speak.com` / `dev-podo.re-speak.com`). No native release required for this PRD.

## Existing Codebase Context

- **grape** (`/Users/johnsong/grape`) — not touched in this PRD
- **podo-app** (`/Users/johnsong/podo-app`)
- **podo-backend** (`/Users/johnsong/podo-backend`)

---
*PM ID: pm_seed_interview_20260526_012532*
*Interview ID: interview_20260526_012532*
