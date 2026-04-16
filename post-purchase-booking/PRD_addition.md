# PRD Addition

Additions to the original PRD covering the trial-class results data source and the level → display-name mapping used by the existing PDF generator. Any downstream feature consuming level-test data should follow these rules so that product UIs stay consistent with the legacy PDF reports.

## 1. Data Source: Trial Class Results

Trial-class results live in **`le_level_test`** (GWATOP MySQL, Metabase collection "GWATOP / Le Level Test"). One row per completed trial class.

Key columns:

| Column | Meaning |
|---|---|
| `id` | Test ID |
| `created_at` | Submission timestamp |
| `student_id` | FK → `GT_USER.ID` |
| `language` | `EN` or `JP` |
| `level` | Canonical evaluated level (1–10) — use this as the numeric key |
| `level_name` | Korean nickname label (e.g. "갓 태어난 베이비", "아장아장 베이비") |
| `student_name`, `job`, `reason` | Student profile context |
| `url` | S3 URL to the generated PDF report |

**Access note:** `le_level_test` is **not** currently mirrored into the ClickHouse `podo_mysql` database. Until it is added to the CDC/materialized-view pipeline, queries must run against the source MySQL (GWATOP) or go through Metabase. Any service depending on this table should either (a) read MySQL directly, or (b) request that it be added to the ClickHouse mirror.

## 2. Level → Displayed "Recommended Curriculum" Mapping

The archived `podo-trial-pdf-generator` defines the canonical display rules. Any new surface that shows a recommended curriculum label MUST reproduce these rules exactly.

### 2.1 English
Source: `d2_en_each_page.py:7–11`

Rule: `level ≤ 2 → "Start {level}"`, otherwise `"Lv.{level - 2}"`.

| `level` | Displayed label |
|---:|---|
| 1 | `Start 1` |
| 2 | `Start 2` |
| 3 | `Lv.1` |
| 4 | `Lv.2` |
| 5 | `Lv.3` |
| 6 | `Lv.4` |
| 7 | `Lv.5` |
| 8 | `Lv.6` |
| 9 | `Lv.7` |
| 10 | `Lv.8` |

### 2.2 Japanese
Source: `d2_jp_each_page.py:6–12`, `d2_jp_each_page_beginner.py:5`

Rule: `"Lv.{min(level, 8)}"` — capped at 8.

| `level` | Displayed label |
|---:|---|
| 1 | `Lv.1` |
| 2 | `Lv.2` |
| 3 | `Lv.3` |
| 4 | `Lv.4` |
| 5 | `Lv.5` |
| 6 | `Lv.6` |
| 7 | `Lv.7` |
| 8 | `Lv.8` |
| 9 | `Lv.8` (capped) |
| 10 | `Lv.8` (capped) |

⚠ Levels 9 and 10 collapse to `Lv.8`. Analytics/segmentation should still use the raw `level` value; only the user-facing label is capped.

### 2.3 Korean Nickname Label (optional)
Already stored in `le_level_test.level_name`. Underlying mapping is in `functions.py:130–143` (EN) and `functions.py:160–173` (JP). Prefer the stored column over recomputing.

## 3. Home-Screen "Book Next Lesson" Flow — Hardcoded Curriculum Buckets

The home-screen booking flow (`GET /api/v2/lecture/podo/getNextLectureList` → `bookingLesson(classId)` → `getBookingLectureInfo`) exposes **four** hardcoded curriculum-grade codes per language. These are the `classCourseGrade` values returned only for trial classes (`GC.CITY = 'PODO_TRIAL'`).

Source of truth: `podo-backend/.../LectureOnlineJpaRepository.java:181-196` (production SQL `CASE` expression). Localized display names are joined in via system code `{CLASS_TYPE}_{LANG_TYPE}_LEVEL` at `LectureQueryServiceImpl.java:1496-1497`.

### 3.1 EN — 4 codes: `B`, `C1`, `C2`, `D`

| classCourseGrade | `CLASS_LEVEL` | `CLASS_WEEK` | KR label (from `LevelUtils` doc) |
|---|---:|---:|---|
| `B`  | 3 | 1  | 초급 |
| `C1` | 4 | 1  | 중급 |
| `C2` | 5 | 10 | 중고급 |
| `D`  | 7 | 1  | 고급 |

### 3.2 JP — 4 codes: `A`, `B`, `C`, `D` (different letter set from EN!)

| classCourseGrade | `CLASS_LEVEL` | `CLASS_WEEK` |
|---|---:|---:|
| `A` | 1 | 1 |
| `B` | 1 or 2 | 4 or 1 |
| `C` | 3 or 4 | 1 |
| `D` | 5 or 8 | 1 |

JP uses the letter `A` where EN uses `B`, and collapses multiple `(CLASS_LEVEL, CLASS_WEEK)` tuples into the same grade letter.

### 3.3 `le_level_test.level` → curriculum-grade mapping

`LevelUtils.testLevelToCourseLevel`:
- EN: `courseLevel = testLevel + 2`
- JP: `courseLevel = testLevel`

Applied to the SQL buckets above:

| `le_level_test.level` | EN courseLevel | EN grade | JP courseLevel | JP grade |
|---:|---:|---|---:|---|
| 1  | 3  | B  | 1 | A (week 1) / B (week 4) |
| 2  | 4  | C1 | 2 | B |
| 3  | 5  | C2 *(only if week=10)* | 3 | C |
| 4  | 6  | — (no bucket) | 4 | C |
| 5  | 7  | D  | 5 | D |
| 6  | 8  | — | 6 | — |
| 7  | 9  | — | 7 | — |
| 8  | 10 | — | 8 | D |
| 9  | 11 | — | 9 | — |
| 10 | 12 | — | 10 | — |

⚠ Many test-levels have **no matching trial curriculum** — the buckets fire only on specific `(CLASS_LEVEL, CLASS_WEEK)` tuples. For non-trial classes, `classCourseGrade` is empty.

### 3.4 Known discrepancy

`LevelUtils.java:30-72` (`getCourseLevelAndWeek`) documents JP grades as `B/C1/C2/D`, but the production SQL emits `A/B/C/D` for JP. **The SQL is authoritative.** New code should align with the SQL until the helper is reconciled.

## 4. Level + Schedule Screen — Lesson Assignment Logic

Post-purchase, the user lands on a level + schedule screen. The system must pick a **starting lesson** (a `(CLASS_LEVEL, CLASS_WEEK)` tuple from `GT_CLASS_COURSE`) that the user is then booked into via the existing booking flow.

### 4.1 Level Source — Priority Order

1. **`le_level_test`** — if a row exists for `(student_id, language)`, use `le_level_test.level` directly as the target `GT_CLASS_COURSE.CLASS_LEVEL`. No `+2` offset (the legacy `LevelUtils.testLevelToCourseLevel` EN offset does not apply here; the new path maps 1:1).
2. **Onboarding self-reported level** — placeholder. The onboarding level field is not yet deployed. Leave a clearly marked hook (e.g. `getOnboardingLevel(userId) → Optional<Integer>`) that currently always returns empty. When the onboarding feature ships, this slot takes over as the fallback.
3. **Default** — `CLASS_LEVEL = 1, CLASS_WEEK = 1` (first lesson of the first level).

### 4.2 Starting Lesson Rule

Let `L` = resolved level (1–10). The default starting lesson is `(CLASS_LEVEL=L, CLASS_WEEK=1)` — the first lesson of level `L` — for **both** EN and JP.

This gives 10 canonical starting lessons per language. The PDF-label nomenclature is informational only; e.g. for EN, `L=1` is labelled `Start 1` and `L=3` is labelled `Lv.1`, but the backend still uses `CLASS_LEVEL=1` and `CLASS_LEVEL=3` respectively — the 1:1 mapping from `le_level_test.level` to `CLASS_LEVEL` is what matters.

### 4.3 Trial-Class Skip-Ahead Rule

If the user completed a trial class (i.e. an `le_level_test` row exists for `(student_id, language)`), the trial already consumed one specific lesson. To avoid re-serving it, start one lesson later **within the same level**:

Let `(L_trial, W_trial)` = the `(CLASS_LEVEL, CLASS_WEEK)` tuple of the trial class. Start at `(L_trial, W_trial + 1)`, **with one exception**:

#### Edge case: EN C2 (level 5, week 10)

EN trial grade `C2` maps to `(CLASS_LEVEL=5, CLASS_WEEK=10)`. This is a late-level placement probe, not the top of a progression — the student has not seen weeks 1–9. Therefore **override the "next" rule**: start at `(CLASS_LEVEL=5, CLASS_WEEK=1)` (first lesson of the same level).

This is the only known exception; all other trial grades map to `CLASS_WEEK=1` or `CLASS_WEEK=4`, where `W+1` is the natural next lesson.

### 4.4 Resolution Pseudocode

```text
resolveStartingLesson(userId, language):
    levelTest = findLevelTest(userId, language)   // from le_level_test
    if levelTest exists:
        L = levelTest.level                        // 1..10
        (L_trial, W_trial) = lookupTrialClassTuple(language, L)
        if (language == "EN" && L_trial == 5 && W_trial == 10):
            return (5, 1)                          // EN C2 edge case
        if (L_trial, W_trial) exists:
            return (L_trial, W_trial + 1)          // skip past the trial
        return (L, 1)                              // no trial tuple; default to first week of L

    onboardingLevel = getOnboardingLevel(userId)   // placeholder, returns empty today
    if onboardingLevel exists:
        return (onboardingLevel, 1)

    return (1, 1)                                  // global default
```

`lookupTrialClassTuple` mirrors the SQL table in `LectureOnlineJpaRepository.java:183-193`:

| Language | Test level | (CLASS_LEVEL, CLASS_WEEK) |
|---|---:|---|
| EN | 1 | (3, 1) |
| EN | 2 | (4, 1) |
| EN | 3 | (5, 10) ⚠ edge case |
| EN | 5 | (7, 1) |
| JP | 1 | (1, 1) or (1, 4) |
| JP | 2 | (2, 1) |
| JP | 3–4 | (3, 1) / (4, 1) |
| JP | 5, 8 | (5, 1) / (8, 1) |

Levels not listed above have no known trial-tuple and should fall through to `(L, 1)`.

### 4.5 Constraints & Validation

- Filter `GT_CLASS_COURSE` by `USE_YN = 'Y'`, `CLASS_TYPE` matching the user's subscription, and integer `CLASS_LEVEL ∈ {1..10}`. Sub-level floats (e.g. 4.1, 4.5) must be excluded from this path.
- If the resolved `(CLASS_LEVEL, CLASS_WEEK)` tuple doesn't exist in `GT_CLASS_COURSE` for the user's `CLASS_TYPE`, fall back to `(1, 1)`.
- Hand the resolved tuple's `ID` (or the corresponding `GT_CLASS.ID`) into the existing booking flow as `classId` — no changes to `getBookingLectureInfo` required.

## 5. Implementation Guidelines

1. **Canonical numeric key:** always read `le_level_test.level` (1–10). Do not recompute from raw interview answers.
2. **PDF-report label:** apply the §2 language-specific rule. Do not mix the Korean nickname and the `Start N` / `Lv.N` labels in the same slot.
3. **Home-screen curriculum grade (legacy):** use `classCourseGrade` from `getNextLectureList`. Do not reconstruct it on the client — the bucket rules are non-obvious and differ per language (§3).
4. **New level+schedule screen (§4):** use the direct 1:1 mapping from `le_level_test.level` to `GT_CLASS_COURSE.CLASS_LEVEL`. Do **not** pipe through the legacy `+2` EN offset or the 4-bucket grade system — those are separate concerns.
5. **Analytics:** bucket by raw `le_level_test.level` (1–10) **and** by `classCourseGrade` separately. They do not map 1:1.
6. **Onboarding hook:** land the placeholder function signature now so the caller site is stable. Swap the body when the onboarding field ships.
