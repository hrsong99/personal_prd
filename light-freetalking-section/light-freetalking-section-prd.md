# Light Free-Talking Section & 프리토킹 → 브레이킹 뉴스 Rename

**Status:** Draft v0.1
**Author:** podo@day1company.co.kr
**Date:** 2026-05-21
**Touch repos:** `podo-backend` (`applications/lecture`), `podo-app` (`features/subscribes`)
**grape:** no change
**Feature flag:** None — see §10 (the new section is self-gating; the rename ships immediately)

> A small change to the language course catalog ("subscribes"). It renames one section, adds one new (initially empty) section above it, and updates the section sub-label tags. No database schema change.

---

## 1. Problem

The course catalog has a section currently labeled **"프리토킹"** (line shown in-app as `프리토킹  영어 프리토킹`). That label no longer matches what is actually in the section.

The section is built from every `BASIC` course in the `CLASS_LEVEL` band `1000.0 – 1999.9`. Today that band holds **two unrelated kinds of content**:

| What | `CLASS_LEVEL` | Lengths | Langs |
|---|---|---|---|
| **Breaking News** — monthly current-affairs courses (e.g. "Breaking News 5월 (중급)") | `1000.994 – 1000.999` | 25분 only | EN, JP |
| **Light topic conversation** — "취미와 관심사", "일상에 대해" | `1001`, `1002` | 15분 & 25분 | EN, JP |

The section is dominated by Breaking News, so "프리토킹" is misleading. There is also no dedicated, browsable home for genuinely **light, casual conversation** content — which is a distinct product the team wants to grow.

## 2. Goals & Non-Goals

### Goals

1. Rename the existing section **"프리토킹" → "브레이킹 뉴스"**.
2. Add a new section **"가벼운 프리토킹"** positioned **above** 브레이킹 뉴스.
3. The new section's course query supports **both 15분 and 25분** courses (content will mostly be 25분).
4. Give both sections descriptive sub-label tags (see §6).

### Non-Goals

- **Not** moving the existing 일상에 대해 / 취미와 관심사 courses out of 브레이킹 뉴스. They stay where they are — a knowingly accepted minor miscategorization (see Q-1).
- **Not** creating the actual 가벼운 프리토킹 course content — that is a separate content-team task (see §8). The section ships empty.
- **Not** making section names or tags admin-editable. That ("Option B") is a deliberate future scope — see §9 / Q-4.
- No change to the 최근 학습한 커리큘럼, 체험 레슨, 스탠다드, or 비즈니스 sections.
- No change to the onboarding `FREE_TALK → "프리토킹"` goal label — that is a separate onboarding feature, untouched.
- No `grape` change.

## 3. Current behavior

The catalog is assembled per language in **`podo-backend`**, `LectureQueryServiceImpl.java` (~lines 2043–2132 as of current main). Each carousel is one `addSubscribeDto(...)` call; **call order = display order**:

| # | Section | Source query | `CLASS_LEVEL` band |
|---|---|---|---|
| 1 | 최근 학습한 커리큘럼 | `getRecentLectureList` | — |
| 2 | 체험 레슨 | `getTrialLectureCourseList` | `CURRICULUM_TYPE = 'TRIAL'` |
| 3 | 스탠다드 (25분 / 15분) | `getLectureCourseList` | `< 1000` |
| 4 | **프리토킹** | `getFreeTalkingLectureCourseList` | `>= 1000 AND < 2000` |
| 5 | 비즈니스 영어 *(EN only)* | `getBusinessEnglishLectureCourseList` | `>= 2000 AND < 3000` |

- All of #3–#5 share `CURRICULUM_TYPE = 'BASIC'`; sections are separated **only by `CLASS_LEVEL` band**.
- The "프리토킹" name is a hardcoded Java string, repeated in **3 branches** (25분, 15분, default) of the section block (`LectureQueryServiceImpl.java:2092, 2102, 2112`).
- The section list is returned to the app and rendered by `language-subscribe-list-view.tsx`. A section with zero courses is dropped client-side (`if (subscribe.lesson_groups.length === 0) return null`).
- The grey sub-label tag ("영어 프리토킹" / "일본어 프리토킹") is hardcoded in **`podo-app`**, `carousel-header.tsx:29-40` — a `FREE_TALKING_BADGE_MESSAGE` map shown whenever the section name **contains the substring `"프리토킹"`**.

## 4. The `CLASS_LEVEL` band model — where the new section lives

Sections are partitioned by `CLASS_LEVEL`. Current occupancy of `CLASS_TYPE='PODO'`, `USE_YN='Y'`:

| Band | Section | Occupied range today |
|---|---|---|
| `0 – 999` | 스탠다드 (`getLectureCourseList` filters `CLASS_LEVEL < 1000`) | levels 1–20 |
| `1000 – 1999` | 프리토킹 → **브레이킹 뉴스** | `1000.994`–`1002` |
| `2000 – 2999` | 비즈니스 | `2001`–`2006` |
| **`3000 – 3999`** | **— free —** | empty |

**Decision: the new 가벼운 프리토킹 section uses the `3000 – 3999` band.**

A "500-range" was considered and rejected: the 스탠다드 query filters `CLASS_LEVEL < 1000` as an open bound, so a new `BASIC` course at level 500 would surface **inside the 스탠다드 section**, not its own. `3000–3999` is the first fully free band and follows the existing one-band-per-section convention.

## 5. Proposed changes

### 5.1 `podo-backend`

**`LectureCourseJpaRepository.java`** — add one method, a structural copy of `getFreeTalkingLectureCourseList`:

```java
List<LectureCourseInterface> getLightFreeTalkingLectureCourseList(
        Integer studentId, String curriculumType, String langType, Integer lessonTime);
```

Its native query is identical to `getFreeTalkingLectureCourseList` except the level band is `CLASS_LEVEL >= 3000.0 AND CLASS_LEVEL < 4000.0` — changed in **both** the main `WHERE` and the inner `LEFT JOIN` lesson-count subquery. It keeps the `lessonTime` parameter, so it supports 15분 and 25분 exactly like the existing query.

**`LectureQueryServiceImpl.java`**

1. **Rename:** the 3 `"프리토킹"` string literals → `"브레이킹 뉴스"`.
2. **New section block:** insert a `가벼운 프리토킹` block **immediately before** the 브레이킹 뉴스 block (so it renders above it). It mirrors the existing block's 3-branch lesson-time / purchase logic:

   | User state | `lessonTime` | `isPurchased` arg |
   |---|---|---|
   | `isBasicPurchased` or `isBusinessPurchased` | `25` | `true` |
   | else if `isBasicPurchased15` | `15` | `true` |
   | else | `25` | `false` |

   Each branch calls `addSubscribeDto(..., "가벼운 프리토킹", lessonTime, "BASIC", getLightFreeTalkingLectureCourseList(studentId, "BASIC", langType, lessonTime), null, isPurchased, acceptLangType)`.

> Recommended: define the two section names as named constants and reuse them on both ends of the badge coupling (see §9 / Q-2).

### 5.2 `podo-app`

**`carousel-header.tsx`** — the tag must no longer be chosen by the `"프리토킹"` substring (it would now miss "브레이킹 뉴스" and wrongly fire on "가벼운 프리토킹"). Replace `FREE_TALKING_BADGE_MESSAGE` + the `name.includes('프리토킹')` check with an explicit section-name → tag map:

```ts
const SECTION_BADGE: Record<string, Partial<Record<LangType, string>>> = {
  '브레이킹 뉴스':   { EN: '영어로 최신 뉴스에 대해서 대화하기', JP: '일본어로 최신 뉴스에 대해서 대화하기' },
  '가벼운 프리토킹': { EN: '영어로 가볍게 수다떨기',          JP: '일본어로 가볍게 수다떨기' },
}
```

`getGroupNameBadge` looks the section name up in `SECTION_BADGE` and returns the `langType` entry, or `null`. No other `podo-app` change — the section name and tag are pure display strings; nothing keys an identifier or deeplink off them.

### 5.3 Data

**No schema migration.** The new section reuses the existing `GT_CLASS_COURSE` table; it only needs course rows created in the `3000–3999` band (a content task — §8).

## 6. Section & tag spec

| Section | Korean name | Sub-label tag (EN) | Sub-label tag (JP) |
|---|---|---|---|
| Renamed | **브레이킹 뉴스** | 영어로 최신 뉴스에 대해서 대화하기 | 일본어로 최신 뉴스에 대해서 대화하기 |
| New | **가벼운 프리토킹** | 영어로 가볍게 수다떨기 | 일본어로 가볍게 수다떨기 |

The tag is shown beside the section title (the EN/JP variants differ only by 영어/일본어). The 비즈니스 section has no tag and is unchanged (Q-3).

## 7. Behavior matrix

Catalog order in the changed region, by user state. "(hidden)" = section returned but dropped client-side because it has zero courses.

| User state | … 스탠다드 | **가벼운 프리토킹** | **브레이킹 뉴스** | 비즈니스 |
|---|---|---|---|---|
| 25분 `BASIC` / `BUSINESS` — **at launch** | shown | (hidden — no content yet) | Breaking News + 1001/1002 @25분 | shown (EN) |
| 25분 `BASIC` / `BUSINESS` — **after content added** | shown | light courses @25분 | Breaking News + 1001/1002 @25분 | shown (EN) |
| 15분-only `BASIC` | shown | light courses @15분 *(once content exists)* | 1001/1002 @15분 only — Breaking News has no 15분 courses (Q-5) | — |
| Not purchased | shown (locked) | as above, cards locked | as above, cards locked | shown (locked) |

Cards render locked (lock icon) when `isPurchased = false`; the section itself is still shown. Section **visibility** depends only on whether it has courses.

## 8. Content task (separate from code)

For 가벼운 프리토킹 to appear, the content team creates courses in `GT_CLASS_COURSE` at `CLASS_LEVEL` `3000–3999`, `CURRICULUM_TYPE='BASIC'`, `CLASS_TYPE='PODO'`, for EN and JP, with a course row (`CLASS_WEEK=0`) plus its lesson rows (`CLASS_WEEK>0`). Mostly 25분 (`LESSON_TIME`), 15분 optional. This can be done before or after the code ships — the code change is independent and safe to deploy with the section empty.

## 9. Open questions

- **Q-1 — 1001/1002 long-term home.** 취미와 관심사 / 일상에 대해 stay in 브레이킹 뉴스 for now (accepted). Later, do we re-level them into the `3000`-band so they join 가벼운 프리토킹? That would be a pure data move (no code) once the new section has content. Decide at that point.
- **Q-2 — Backend↔frontend name coupling.** The `SECTION_BADGE` keys must exactly match the backend section-name strings. Acceptable for this change; flag whether to harden later (shared constant, or a stable section key in the API response) — this is also the natural seam for the future admin-editable "Option B".
- **Q-3 — Business tag.** 비즈니스 has no sub-label today and this PRD adds none. Confirm that's intended.
- **Q-4 — Admin-editable tags (Option B), out of scope.** Section names/tags are hardcoded in code; there is no "section" entity in any DB or in `grape` admin. Making tags editable would require a new section-config table, an API field, a frontend change, and a new `grape` admin page — a separate mini-project. Deferred; revisit if tags need to change frequently.
- **Q-5 — 15분 Breaking News.** Breaking News courses are 25분-only, so 15분-only users see 브레이킹 뉴스 populated only by the 1001/1002 light courses. Acceptable, or should 15분 users see something different? (Low priority — 15분 is a small cohort.)

## 10. Rollout

- **No feature flag.** The rename + tag change is display-only and ships immediately on deploy. The new 가벼운 프리토킹 section is **self-gating**: it is auto-hidden until courses exist in the `3000`-band, so deploying code before content is safe and produces no visible half-state.
- **Ship order:** `podo-backend` (rename + new query + new section block) and `podo-app` (badge map) should deploy together so the tag logic and section names stay in sync. Content entry can happen any time after.
- **Risk:** low. No schema change, no migration, no data backfill. Worst case if the badge map and backend names drift: a section shows no tag (cosmetic).
- **QA:** verify §7 matrix — section order (가벼운 프리토킹 above 브레이킹 뉴스), correct tags per EN/JP, 브레이킹 뉴스 still lists Breaking News + 1001/1002, and 가벼운 프리토킹 stays hidden while empty then appears once a `3000`-band course is added.

## 11. Summary

| | Before | After |
|---|---|---|
| Section name | 프리토킹 | 브레이킹 뉴스 |
| Section sub-label | 영어/일본어 프리토킹 | 영어/일본어로 최신 뉴스에 대해서 대화하기 |
| New section | — | 가벼운 프리토킹 (above 브레이킹 뉴스), tag "영어/일본어로 가볍게 수다떨기" |
| New section content | — | starts empty; courses added in `CLASS_LEVEL 3000–3999` |
| `CLASS_LEVEL` bands | 스탠다드 `<1000`, 프리토킹 `1000s`, 비즈니스 `2000s` | + 가벼운 프리토킹 `3000s` |
| Schema change | — | none |
| Repos touched | — | `podo-backend`, `podo-app` (not `grape`) |
