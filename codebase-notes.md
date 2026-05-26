# Codebase Notes

Accumulated learnings about the **podo-app**, **podo-backend**, and **grape**
codebases — confusing aspects, gotchas, naming conventions, and strategies that
work for navigating them.

The `/search-repos` skill appends here automatically when a search surfaces
something non-obvious. Feel free to add entries by hand too.

**How to add an entry:** put it under the relevant repo section, newest first.
Keep each entry to one fact with a short **bold lead-in**. Skip routine search
results — only log things that would save time or confusion next time.

## General / cross-repo

- **Trial level test PDFs live in `le_level_test`** (DB `gwatop`): one row per test taken, with `student_id`, `language` (only ever `EN` or `JP`), `level`, `level_name`, `url` (an S3 link to the PDF), `created_at`. A user can have multiple rows per language and rows in both languages.
- **`le_level_test` has two row types — the ~8% with no `url` are NOT failed PDFs.** They come from the "레벨 강제 선택" (force-select level) feature: `POST /api/v2/leveltest/selectLevel` → `PodoLevelTestRepository.createToSelectLevel` does a partial `INSERT (student_id, student_name, language, level)` only — no PDF is generated, so no `url`, and `job`/`reason`/`study_method`/`listening`/`fluency`/`pronunciation`/`level_name` are all NULL. The full AI-test path (`registerLevelTest`) populates every field. To split the two: no-url ⇔ select-level. Feature shipped 2025-05-11 (`feat: level select`), which is exactly when the no-url share jumps from 0% to ~10-30%/month. Triggered from the home-greeting "recommend regular lesson" state and the external level-select dialog (`apps/web`).

## podo-app (frontend)

- **"학습 통계" vs "수업 리포트" is an either/or split by EXTEND subscription type — not a feature flag.** `hasExtendInActiveSubscription` (`entities/subscribes/libs/index.ts`) is true when a user has any active (`사용중/홀딩중/종료예정/대기중`) `subscribeType === 'EXTEND'` 수강권. EXTEND users see `class-report`; everyone else sees `learning-stats`. The My Podo tab link is gated (`lesson-manage-section.tsx`: `showLearningStats = !isExtendUser`) AND the route pages self-gate (`learning-stats/page.tsx` + `.../history` call `notFound()` for EXTEND users; `class-report/page.tsx` does the inverse).
- **The tutor website is `apps/tutor-web` — a self-contained Next.js app with its own Hono API + direct DB access.** It has `src/server` (Hono RPC mounted at `/api/v1`) and queries the `gwatop` MySQL directly via drizzle-orm (`src/server/db`, schemas in `server/db/schema/*` mirroring the legacy `GT_*` tables). It does **not** call podo-backend at all. Three apps in `apps/`: `web` (student), `native`, `tutor-web`.
- **Tutor login joins `GT_USER` + `GT_TUTOR` on EMAIL.** `AuthService.loginByEmail` (`apps/tutor-web/src/server/modules/auth/service.ts`) requires both a `GT_USER` row (credentials, `USER_PW = SHA1(password)`) and a `GT_TUTOR` row sharing the same email — no tutor row means no login even with valid credentials. JWTs are stored in Redis (access + optional refresh), set as cookies. There is no signup UI; `(before-login)` route group contains only `login`.
- **The home greeting card is a state machine.** `widgets/greeting/hooks/use-greeting-status.ts` picks one state from ticket/lesson data: `NO_TICKET` (no active 수강권), `SCHEDULED_CLASS` (upcoming lesson), `RECOMMEND_BOOKING_TRIAL_CLASS` / `RECOMMEND_BOOKING_REGULAR_CLASS`. `NO_TICKET` renders a **dark** card (`features/home-greeting/ui/states/no-ticket-state.tsx`, `bg-gray-900` `GreetingLayout` base); the booking-recommendation states render a **light** card (`widgets/home-greeting/ui/home-no-booking-card.tsx`). Dark vs light are separate components, not a style prop.
- **My Podo "notices" (공지사항) is a CMS board, not `GT_NOTICE`.** It is fetched from `/api/v1/board/getList` (`entities/notice/api/api.ts`); the `board_id` is a hex string. Notice detail renders its `contents` as HTML via `dangerouslySetInnerHTML`. Notices are broadcast/shared content — there is no per-user notice.
- **`open-in-app/[[...path]]` is a generic deep-link catch-all.** `apps/web/src/app/open-in-app/[[...path]]/page.tsx` reconstructs any `/open-in-app/<path>` to `/<path>` and forwards query params; the prefixes (`podo.re-speak.com/open-in-app` + stage/dev) are registered in `apps/native/app.config.ts`. A new in-app deep link needs no per-feature routing code.
- **No PDF viewer in the app.** AI trial reports are PNGs rendered via `next/image`; notices render HTML. To show a PDF, embed the `https://podo-pdf.pages.dev/?url=` viewer in an iframe (it sends no `X-Frame-Options`, so it embeds fine).

## podo-backend (backend)

- **"패널티 스킵권" is called "패널티 방어권 / penalty waiver" in code.** The quota is NOT a ticket table — it's a single int column `GT_SUBSCRIBE_MAPP.PENALTY_WAIVER_MAX_COUNT` (per 수강권 계약). Each use logs one row in `le_student_penalty_waiver_usage` (UNIQUE on `class_id, event_type`); remaining = MAX_COUNT − COUNT(usage rows for that `subscribe_mapp_id`). There is **no grant API** — the only admin endpoint `POST /api/v1/admin/student-penalty-waiver/use` *consumes* a waiver. To give a user more you must `UPDATE` the column directly. Whole feature is gated by GrowthBook flag `tbd_260512_student_cancel_penalty_relaxation`. `StudentPenaltyWaiverService.tryUseWaiver` is called from `PodoScheduleServiceImplV2.cancel(...)` (CANCEL) and from grape's `inc/student_penalty_waiver_trigger.php` → backend (NOSHOW).
- **Level test module: `applications/podo/leveltest/`.** `LevelTestServiceImpl` has read methods (`getLatestLevelTestByLangOrNull`, `getLevelTests`) but `PodoLevelTestController` (`/api/v2/leveltest`) exposes no "get my reports" GET endpoint. PDF flow: an AWS Lambda generates the PDF → S3 bucket `podo-pdf-report` → enqueues on Redis queue `leveltest` → a 5-min cron `LevelTestServiceImpl.receiveMessageCron()` sends the alimtalk.
- **`LevelTestServiceImpl.sendAlimTalk(...)` is dead code** — its only caller and its `CreateCommonSendLog` call are both commented out. The live alimtalk path is `receiveMessageCron()` (sets `reportLink` directly in an `extras` map).
- **Environment base URLs are not centralized.** A `local/dev → dev-podo.re-speak.com`, `stage → stage-podo`, default → `podo.re-speak.com` switch is copy-pasted across gateways (e.g. `LectureGateway`).

## grape

- **Admin tutor creation seeds `GT_USER` with `SHA1('1234')`.** `admin/process/teachers_v1_ps.php` inserts `GT_TUTOR` first, AES-encrypts sensitive fields (age/bank), then inserts a `GT_USER` with default password `1234` (or updates an existing one matched by phone/email). Tutors never pick their own password today.
- **Admin pages register via `GT_ADMIN_MENU` rows.** New admin pages add a row to `GT_ADMIN_MENU` (see `admin/sql/*_menu.sql` for the INSERT shape: MENU_NAME, MENU_URL, PRIOR_MENU_ID, ORDER_LEVEL, AUTH_IDS). The menu CRUD lives in `admin/system/menu/`. S3 upload helpers: `inc/upload_*_for_s3.php`.
- **Level test report resending is a manual admin process.** `admin/leveltest/resend_report.php` uploads an XLSX of responses; `admin/leveltest/send_leveltest.php` proxies it to an AWS Lambda URL that generates the PDF. grape itself has no level-test alimtalk template — that lives in podo-backend / the Kakao template console.
