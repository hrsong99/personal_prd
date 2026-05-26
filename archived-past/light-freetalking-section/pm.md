# Course Catalog Section Rename & New Light Free Talking Section

*Created At: 2026-05-21T09:05:52.759178+00:00*
*Updated: 2026-05-21 — dev-interview decisions folded in (see "Implementation Decisions")*

## Goal

Fix the misleading '프리토킹' section label (dominated by Breaking News courses) by renaming it to '브레이킹 뉴스', and create a new '가벼운 프리토킹' section as a dedicated home for light, casual conversation content the team wants to grow.

## User Stories

1. **As a** Language learner browsing the course catalog, **I want to** See a section labeled '브레이킹 뉴스' that accurately reflects its Breaking News course content, **so that** The section name matches the content, reducing confusion when choosing courses.
2. **As a** Language learner interested in casual conversation practice, **I want to** Find a dedicated '가벼운 프리토킹' section with light free-talking courses once content is available, **so that** Easy discovery of casual conversation courses in a clearly labeled section.
3. **As a** Content team, **I want to** Add new light free-talking courses to the 3000–3999 CLASS_LEVEL band and have them automatically appear in the new section, **so that** New content surfaces in the catalog without requiring code changes or feature flags.
4. **As a** Language learner, **I want to** See descriptive sub-label tags on each section (e.g., '가볍게 수다떨기', '최신 뉴스 대화하기'), **so that** Quickly understand what kind of courses each section offers before browsing.
5. **As a** 15-min and 25-min subscription holders, **I want to** Access courses in 가벼운 프리토킹 matching their purchased lesson duration, **so that** Both duration tiers are supported using existing platform branching logic.

## Constraints

- Small, low-risk change — no DB schema migration required
- No feature flag needed; new section auto-hides via existing app logic when its course list is empty
- Section names and sub-label tags stay hardcoded — admin-editable section names are deferred
- Touches only podo-backend and podo-app repositories
- No new CURRICULUM_TYPE, duration-filter UI, or scheduling logic changes
- New CLASS_LEVEL band 3000–3999 reuses the established 'one level band per catalog section' pattern in GT_CLASS_COURSE
- No content migration — existing light courses (취미와 관심사, 일상에 대해) remain in 브레이킹 뉴스 at their current CLASS_LEVEL (1001/1002)
- Verification is manual QA against the behavior matrix — no new automated tests (dev-interview decision)
- The backend↔frontend section-name string coupling is accepted; both repos define the section names as named string constants holding identical values (dev-interview decision)

## Success Criteria

1. Course catalog displays '가벼운 프리토킹' section positioned above '브레이킹 뉴스'
2. Both sections display correct descriptive sub-label tags (with 영어/일본어 language variants)
3. The renamed '브레이킹 뉴스' section continues to work identically to the former '프리토킹' section (all existing courses, durations, and user flows intact)
4. 가벼운 프리토킹 section is auto-hidden when no courses exist in the 3000-band
5. 가벼운 프리토킹 section appears automatically once courses are added to the 3000–3999 CLASS_LEVEL band
6. 15-min and 25-min lesson durations are supported in the new section via copied branching logic

## Implementation Decisions (dev interview, 2026-05-21)

The dev interview (run in fallback mode — the Ouroboros MCP question generator was unavailable) confirmed the goal restatement and resolved two implementation-level questions:

- **Verification — manual QA only.** "Done" is verified by hand against the behavior matrix: section order (가벼운 프리토킹 above 브레이킹 뉴스), tags per 영어/일본어, the renamed 브레이킹 뉴스 section behaving identically to the former 프리토킹 section, and 가벼운 프리토킹 hidden while empty then visible once 3000-band content exists. No new automated tests are added; any existing test that breaks from the rename is updated.
- **Backend↔frontend name coupling — accepted.** The frontend tag map is keyed by the exact backend section-name string. Both repos define the section names ("브레이킹 뉴스", "가벼운 프리토킹") as named string constants holding identical values, so the cross-repo coupling is explicit and greppable. No section key/id is added to the API response — that hardening is deferred (it is the natural seam for the future admin-editable "Option B").

The PM interview earlier locked: the new section uses the 3000–3999 CLASS_LEVEL band; it ships empty; the two existing light courses stay permanently in 브레이킹 뉴스 (accepted known limitation); sub-label tags use shortened wording.

## Assumptions

- The existing 'one CLASS_LEVEL band per catalog section' pattern will continue to be the mechanism for section-to-course mapping
- GT_CLASS_COURSE LESSON_TIME column and the existing 3-branch duration logic (25-min BASIC/BUSINESS, 15-min for 15-min-only, 25-min default) are sufficient for the new section — no platform changes needed
- The app's existing empty-section hiding logic (language-subscribe-list-view.tsx: `if (subscribe.lesson_groups.length === 0) return null`) works correctly for the new section with zero code changes
- The backend query method getFreeTalkingLectureCourseList can be copied/adapted for the 3000-band without structural changes
- 브레이킹 뉴스 containing two non-Breaking-News courses (취미와 관심사, 일상에 대해) is an accepted permanent known limitation — the residual labeling imperfection is consciously accepted as not worth a data migration
- The new section can ship before content is ready because auto-hide ensures invisible empty sections

## Decide Later

The following items remain open and should be revisited before launch:

- **Exact tag wording** — shortened phrasing is decided; final text to be confirmed with content/design (current candidates: 가벼운 프리토킹 → '영어/일본어로 가볍게 수다떨기', 브레이킹 뉴스 → '영어/일본어로 최신 뉴스 대화하기')
- **Business section tag** — the 비즈니스 section has no sub-label and this scope adds none; confirm that is intended
- **15-min Breaking News** — Breaking News courses are 25-min only, so 15-min-only users see 브레이킹 뉴스 populated only by the two light courses; confirm acceptable (low priority)
- **Admin-editable section names and tags ("Option B")** — currently hardcoded; deferred future scope
- **Migration of existing light courses (취미와 관심사, 일상에 대해)** from 브레이킹 뉴스 to 가벼운 프리토킹 — explicitly declined; accepted as a permanent known limitation, listed here only for traceability

## Existing Codebase Context

- **grape** (`/Users/johnsong/grape`)
- **podo-app** (`/Users/johnsong/podo-app`)
- **podo-backend** (`/Users/johnsong/podo-backend`)

---
*PM ID: pm_seed_interview_20260521_082555*
*Interview ID: interview_20260521_082555*
