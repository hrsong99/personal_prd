# PRD 추가분

트라이얼 클래스(레벨 테스트) 결과 데이터 소스와, 기존 PDF 생성기에서 사용 중인 레벨 → 표시 이름 매핑을 다룹니다. 레벨 테스트 데이터를 소비하는 모든 하위 기능은 이 규칙을 따라야 하며, 그래야 기존 PDF 리포트와 제품 UI가 서로 어긋나지 않습니다.

## 1. 데이터 소스: 트라이얼 클래스 결과

트라이얼 클래스 결과는 **`le_level_test`** 테이블(GWATOP MySQL, Metabase 컬렉션 "GWATOP / Le Level Test")에 저장됩니다. 완료된 트라이얼 수업 1건당 1행입니다.

주요 컬럼:

| 컬럼 | 의미 |
|---|---|
| `id` | 테스트 ID |
| `created_at` | 제출 시각 |
| `student_id` | FK → `GT_USER.ID` |
| `language` | `EN` 또는 `JP` |
| `level` | 평가된 기준 레벨(1–10) — 숫자 키로 사용 |
| `level_name` | 한국어 닉네임 라벨 (예: "갓 태어난 베이비", "아장아장 베이비") |
| `student_name`, `job`, `reason` | 학생 프로필 컨텍스트 |
| `url` | 생성된 PDF 리포트의 S3 URL |

**접근 참고사항:** `le_level_test`는 현재 ClickHouse `podo_mysql` 데이터베이스에 미러되지 **않은** 상태입니다. CDC/머티리얼라이즈드 뷰 파이프라인에 추가되기 전까지는 원본 MySQL(GWATOP)에 직접 쿼리하거나 Metabase를 경유해야 합니다. 이 테이블에 의존하는 서비스는 (a) MySQL 직접 읽기 또는 (b) ClickHouse 미러에 추가 요청 중 하나를 택해야 합니다.

## 2. 레벨 → "추천 커리큘럼" 표시 이름 매핑

아카이브된 `podo-trial-pdf-generator`가 기준 표시 규칙을 정의합니다. 추천 커리큘럼 라벨을 노출하는 새 화면은 반드시 이 규칙을 그대로 재현해야 합니다.

### 2.1 영어 (EN)
소스: `d2_en_each_page.py:7–11`

규칙: `level ≤ 2 → "Start {level}"`, 그 외는 `"Lv.{level - 2}"`.

| `level` | 표시 라벨 |
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

### 2.2 일본어 (JP)
소스: `d2_jp_each_page.py:6–12`, `d2_jp_each_page_beginner.py:5`

규칙: `"Lv.{min(level, 8)}"` — 8에서 상한이 걸림.

| `level` | 표시 라벨 |
|---:|---|
| 1 | `Lv.1` |
| 2 | `Lv.2` |
| 3 | `Lv.3` |
| 4 | `Lv.4` |
| 5 | `Lv.5` |
| 6 | `Lv.6` |
| 7 | `Lv.7` |
| 8 | `Lv.8` |
| 9 | `Lv.8` (상한) |
| 10 | `Lv.8` (상한) |

⚠ 레벨 9와 10은 `Lv.8`로 접힙니다. 분석/세분화는 상한이 걸리지 않은 원본 `level` 값을 사용해야 하고, 상한은 유저 노출용 라벨에만 적용됩니다.

### 2.3 한국어 닉네임 라벨 (선택)
이미 `le_level_test.level_name` 컬럼에 저장돼 있습니다. 기저 매핑은 `functions.py:130–143` (EN), `functions.py:160–173` (JP)에 정의돼 있지만, 재계산하지 말고 저장된 컬럼 값을 그대로 사용하세요.

## 3. 홈 화면 "다음 수업 예약" 플로우 — 하드코딩된 커리큘럼 버킷

홈 화면 예약 플로우(`GET /api/v2/lecture/podo/getNextLectureList` → `bookingLesson(classId)` → `getBookingLectureInfo`)는 언어별로 **4개의** 하드코딩된 커리큘럼 등급 코드를 노출합니다. 이 코드는 트라이얼 수업(`GC.CITY = 'PODO_TRIAL'`)에 대해서만 `classCourseGrade` 값으로 반환됩니다.

진실의 소스: `podo-backend/.../LectureOnlineJpaRepository.java:181-196` (프로덕션 SQL `CASE` 표현식). 로컬라이즈된 표시 이름은 `LectureQueryServiceImpl.java:1496-1497`에서 시스템 코드 `{CLASS_TYPE}_{LANG_TYPE}_LEVEL`을 통해 조인됩니다.

### 3.1 EN — 4개 코드: `B`, `C1`, `C2`, `D`

| classCourseGrade | `CLASS_LEVEL` | `CLASS_WEEK` | KR 라벨 (`LevelUtils` 주석 기준) |
|---|---:|---:|---|
| `B`  | 3 | 1  | 초급 |
| `C1` | 4 | 1  | 중급 |
| `C2` | 5 | 10 | 중고급 |
| `D`  | 7 | 1  | 고급 |

### 3.2 JP — 4개 코드: `A`, `B`, `C`, `D` (EN과 문자 집합이 다름!)

| classCourseGrade | `CLASS_LEVEL` | `CLASS_WEEK` |
|---|---:|---:|
| `A` | 1 | 1 |
| `B` | 1 또는 2 | 4 또는 1 |
| `C` | 3 또는 4 | 1 |
| `D` | 5 또는 8 | 1 |

JP는 EN이 `B`를 쓰는 자리에 `A`를 쓰고, 여러 `(CLASS_LEVEL, CLASS_WEEK)` 튜플을 같은 등급 문자로 묶습니다.

### 3.3 `le_level_test.level` → 커리큘럼 등급 매핑

`LevelUtils.testLevelToCourseLevel`:
- EN: `courseLevel = testLevel + 2`
- JP: `courseLevel = testLevel`

위 SQL 버킷에 적용한 결과:

| `le_level_test.level` | EN courseLevel | EN 등급 | JP courseLevel | JP 등급 |
|---:|---:|---|---:|---|
| 1  | 3  | B  | 1 | A (week 1) / B (week 4) |
| 2  | 4  | C1 | 2 | B |
| 3  | 5  | C2 *(week=10 한정)* | 3 | C |
| 4  | 6  | — (버킷 없음) | 4 | C |
| 5  | 7  | D  | 5 | D |
| 6  | 8  | — | 6 | — |
| 7  | 9  | — | 7 | — |
| 8  | 10 | — | 8 | D |
| 9  | 11 | — | 9 | — |
| 10 | 12 | — | 10 | — |

⚠ 많은 테스트 레벨에는 **매칭되는 트라이얼 커리큘럼이 없습니다** — 버킷은 특정 `(CLASS_LEVEL, CLASS_WEEK)` 튜플에서만 발동합니다. 트라이얼이 아닌 수업의 경우 `classCourseGrade`는 비어 있습니다.

### 3.4 알려진 불일치

`LevelUtils.java:30-72` (`getCourseLevelAndWeek`)의 주석은 JP 등급을 `B/C1/C2/D`로 문서화하지만, 실제 프로덕션 SQL은 JP에 대해 `A/B/C/D`를 emit합니다. **SQL이 기준입니다.** 헬퍼가 수정되기 전까지는 새 코드도 SQL에 맞추세요.

## 4. 레벨+스케줄 화면 — 수업 배정 로직

결제 완료 후 유저는 레벨+스케줄 화면에 진입합니다. 시스템은 `GT_CLASS_COURSE`의 `(CLASS_LEVEL, CLASS_WEEK)` 튜플로 **시작 수업**을 하나 선택해야 하며, 이 수업이 기존 예약 플로우로 전달됩니다.

### 4.1 레벨 소스 — 우선순위

1. **`le_level_test`** — `(student_id, language)`에 해당하는 행이 있으면, `le_level_test.level`을 그대로 타깃 `GT_CLASS_COURSE.CLASS_LEVEL`로 사용. `+2` 오프셋 없음(레거시 `LevelUtils.testLevelToCourseLevel`의 EN 오프셋은 이 경로에 적용하지 않음 — 새 경로는 1:1 매핑).
2. **온보딩 자가 보고 레벨** — 플레이스홀더. 온보딩 레벨 필드는 아직 배포 전입니다. 호출부가 안정되도록 시그니처만 박아두는 훅(`getOnboardingLevel(userId) → Optional<Integer>`)을 두되, 현재는 항상 empty를 리턴하도록 두세요. 온보딩 기능 배포 시 이 슬롯이 fallback으로 자리잡습니다.
3. **기본값** — `CLASS_LEVEL = 1, CLASS_WEEK = 1` (첫 레벨의 첫 수업).

### 4.2 시작 수업 규칙

`L` = 확정된 레벨(1–10). 기본 시작 수업은 `(CLASS_LEVEL=L, CLASS_WEEK=1)` — 레벨 `L`의 첫 수업 — 이며 EN/JP 모두 동일합니다.

즉 언어별로 10개의 기준 시작 수업이 생깁니다. PDF 라벨(예: EN의 `L=1` → `Start 1`, `L=3` → `Lv.1`)은 참고용일 뿐, 백엔드는 각각 `CLASS_LEVEL=1`, `CLASS_LEVEL=3`을 그대로 사용합니다. 중요한 건 `le_level_test.level` → `CLASS_LEVEL`의 1:1 매핑입니다.

### 4.3 트라이얼 수업 스킵 규칙

유저가 트라이얼 수업을 완료했다면(= `(student_id, language)`에 대한 `le_level_test` 행이 존재), 트라이얼이 이미 특정 수업 하나를 소진한 상태입니다. 동일 수업 재노출을 피하기 위해 **같은 레벨 안에서 한 수업 뒤로** 시작합니다.

트라이얼의 `(CLASS_LEVEL, CLASS_WEEK)` 튜플을 `(L_trial, W_trial)`이라 할 때, `(L_trial, W_trial + 1)`에서 시작합니다. **단, 하나의 예외가 있음**:

#### 예외: EN C2 (레벨 5, 주차 10)

EN 트라이얼 등급 `C2`는 `(CLASS_LEVEL=5, CLASS_WEEK=10)`에 매핑됩니다. 이는 "끝물"에서 뽑은 플레이스먼트 샘플이지 정상 진도의 상단이 아니며, 학생은 1–9주차를 본 적이 없습니다. 따라서 **"다음 수업" 규칙을 오버라이드**해서 `(CLASS_LEVEL=5, CLASS_WEEK=1)` (같은 레벨의 첫 수업)에서 시작합니다.

이 외에는 알려진 예외가 없습니다. 다른 트라이얼 등급은 모두 `CLASS_WEEK=1` 또는 `CLASS_WEEK=4`에 있어 `W+1`이 자연스러운 다음 수업이 됩니다.

### 4.4 결정 의사코드

```text
resolveStartingLesson(userId, language):
    levelTest = findLevelTest(userId, language)   // le_level_test에서 조회
    if levelTest exists:
        L = levelTest.level                        // 1..10
        (L_trial, W_trial) = lookupTrialClassTuple(language, L)
        if (language == "EN" && L_trial == 5 && W_trial == 10):
            return (5, 1)                          // EN C2 예외
        if (L_trial, W_trial) exists:
            return (L_trial, W_trial + 1)          // 트라이얼 다음 수업으로 스킵
        return (L, 1)                              // 트라이얼 튜플 없음 → L의 첫 주차로

    onboardingLevel = getOnboardingLevel(userId)   // 플레이스홀더, 현재는 항상 empty
    if onboardingLevel exists:
        return (onboardingLevel, 1)

    return (1, 1)                                  // 전역 기본값
```

`lookupTrialClassTuple`은 `LectureOnlineJpaRepository.java:183-193`의 SQL 테이블을 그대로 복제합니다:

| 언어 | 테스트 레벨 | (CLASS_LEVEL, CLASS_WEEK) |
|---|---:|---|
| EN | 1 | (3, 1) |
| EN | 2 | (4, 1) |
| EN | 3 | (5, 10) ⚠ 예외 케이스 |
| EN | 5 | (7, 1) |
| JP | 1 | (1, 1) 또는 (1, 4) |
| JP | 2 | (2, 1) |
| JP | 3–4 | (3, 1) / (4, 1) |
| JP | 5, 8 | (5, 1) / (8, 1) |

위 표에 없는 레벨은 알려진 트라이얼 튜플이 없고 `(L, 1)`로 폴스루해야 합니다.

### 4.5 제약 및 검증

- `GT_CLASS_COURSE`는 `USE_YN = 'Y'`, 유저 구독에 맞는 `CLASS_TYPE`, 정수 `CLASS_LEVEL ∈ {1..10}` 조건으로 필터링. 서브 레벨 실수값(예: 4.1, 4.5)은 이 경로에서 제외해야 함.
- 확정된 `(CLASS_LEVEL, CLASS_WEEK)` 튜플이 유저의 `CLASS_TYPE`에 맞는 `GT_CLASS_COURSE` 행으로 존재하지 않으면 `(1, 1)`로 폴백.
- 확정된 튜플의 `ID`(또는 매칭되는 `GT_CLASS.ID`)를 기존 예약 플로우에 `classId`로 전달. `getBookingLectureInfo`는 변경 불필요.

## 5. 구현 가이드라인

1. **기준 숫자 키:** 항상 `le_level_test.level`(1–10)을 읽으세요. 원본 인터뷰 응답을 다시 계산하지 마세요.
2. **PDF 리포트 라벨:** §2의 언어별 규칙을 적용. 같은 슬롯에 한국어 닉네임과 `Start N`/`Lv.N` 라벨을 섞지 마세요 — UX 목적이 다릅니다.
3. **홈 화면 커리큘럼 등급 (레거시):** `getNextLectureList`가 내려주는 `classCourseGrade`를 사용. 클라이언트에서 재구성하지 마세요 — 버킷 규칙이 비직관적이고 언어별로 다릅니다(§3).
4. **새 레벨+스케줄 화면 (§4):** `le_level_test.level` → `GT_CLASS_COURSE.CLASS_LEVEL`의 1:1 직접 매핑을 사용. 레거시 EN `+2` 오프셋이나 4버킷 등급 체계로 우회하지 **마세요** — 그 둘은 별개의 관심사입니다.
5. **분석:** `le_level_test.level`(1–10)과 `classCourseGrade`를 **각각** 독립 차원으로 사용. 두 값은 1:1로 매핑되지 않습니다.
6. **온보딩 훅:** 호출부가 흔들리지 않도록 지금 플레이스홀더 함수 시그니처를 먼저 박아두세요. 온보딩 필드가 배포되면 바디만 교체하면 됩니다.
