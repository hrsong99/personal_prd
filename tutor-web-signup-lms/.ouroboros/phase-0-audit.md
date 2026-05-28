# Phase 0 Audit — tutor-web-signup-lms

*실행일: 2026-05-26 · 환경: production replica (podo-mysql-prod-metabase MCP)*

## 1.1 podo-backend 학생향 튜터 조회의 `CLASS_AVAILABLE=1` 필터 적용 여부

**결과: 패치 불필요 (risk LOW).**

`/Users/johnsong/podo-backend` 내 GT_TUTOR 사용처:

| 경로 | 라인 | 용도 | CLASS_AVAILABLE 필터 | 조치 |
|---|---|---|---|---|
| `applications/user/domain/Tutor.java` | 26 | JPA 엔티티 정의 (`@Table`) | — | — |
| `applications/user/repository/TutorRepository.java` | 35 | `getTutorInfo(tutorId)` — `SELECT FROM GT_TUTOR WHERE GT.ID = :tutorId` | ❌ 없음 | **불필요** — Lemonade(레코딩) 도메인용 단건 조회, 이미 매칭된 튜터 정보 표시. 학생 검색 경로 아님 |
| `applications/lecture/repository/LectureRepository.java` | 28, 418, 419 | `LEFT JOIN GT_TUTOR` 으로 튜터 이름·이메일 표시 | ❌ 없음 | **불필요** — 이미 GT_CLASS와 연결된 튜터의 표시용 정보 |
| `applications/lecture/repository/LectureOnlineJpaRepository.java` | 200, 1096, 1191, 1327 | 같은 패턴, 매칭된 튜터 표시 | ❌ 없음 | **불필요** — 표시 목적 |
| `applications/podo/schedule/repository/ScheduleTimeBlockRepository.java` | 33, 68 | `NOT EXISTS GT_TUTOR ALLOW_LESSON_ONE_HOUR_BEFORE='N'` 으로 1시간 전 예약 차단 | — | **불필요** — `le_schedule_time_block` 자체가 사전 할당 게이트 |

**결론**: 학생향 튜터 가시성은 `le_schedule_time_block`(어드민이 사전 할당한 예약 슬롯)을 통해 노출되며 GT_TUTOR 직접 SELECT는 *이미 매칭된 튜터*의 표시용입니다. 셸 튜터(CLASS_AVAILABLE=0, 가입 직후)는 어드민이 검수 + `le_schedule_time_block` 행 생성 전까지 학생에게 자연스럽게 비공개입니다. **Track C (podo-backend 패치)는 불필요**.

## 1.2 GT_TUTOR 실 DDL ↔ drizzle 스키마 일치 검증

실 DDL 발췌 (필수 필드):

| 컬럼 | 실 DDL | drizzle (apps/tutor-web/src/server/db/schema/tutor.ts) | 일치 |
|---|---|---|---|
| `ID` | int NOT NULL auto_increment | int autoincrement notNull | ✅ |
| `NAME` | varchar(70) NOT NULL | varchar(50) notNull | ⚠️ width mismatch (영향 없음 — INSERT 빈 문자열) |
| `REAL_NAME` | varchar(128) NULL | varchar(50) | ⚠️ width mismatch (영향 없음) |
| `EMAIL` | varchar(200) UNIQUE collation=utf8mb3_bin | varchar(200) | ✅ (collation은 drizzle 표현 불가) |
| `SEX` | int NOT NULL | int notNull | ✅ |
| `PHONE` | varchar(20) NOT NULL | varchar(20) notNull | ✅ |
| `HOPE_CITY` | varchar(100) NOT NULL | varchar(100) notNull | ✅ |
| `LEV_TEACHER` | varchar(50) NOT NULL | varchar(50) notNull | ✅ |
| `CREATE_DATE` | datetime NOT NULL | datetime notNull | ✅ |
| `CLASS_AVAILABLE` | int NOT NULL | int notNull | ✅ |
| `CLASS_SUBTITLE` | varchar(100) NOT NULL | varchar(100) notNull | ✅ |
| `CLASS_PRICE` | int NOT NULL DEFAULT 0 | int default 0 notNull | ✅ |
| `CLASS_LEVEL` | varchar(20) NOT NULL | varchar(20) notNull | ✅ |
| `TEACHER_CAREER` | varchar(3000) NOT NULL | varchar(3000) notNull | ✅ |
| `CLASS_INTRO` | text NOT NULL | text notNull | ✅ |
| `TUTOR_TYPE` | varchar(20) NULL | varchar(20) | ✅ (drizzle은 nullable 기본) |
| `CUSTOM_WEIGHT` | decimal(4,2) NOT NULL DEFAULT '5.00' | **누락** | ⚠️ — 신규 코드 영향 없음 (DEFAULT 적용) |
| `ALLOW_LESSON_ONE_HOUR_BEFORE` | **char(5) NOT NULL DEFAULT 'Y'** | char(1) default 'N' | ⚠️ width + default 불일치 — 본 작업 무관 |
| `PODO_LESSON_TOOL` | varchar(50) NULL DEFAULT 'LEMONBOARD' | **누락** | ⚠️ — DEFAULT 적용 |

**결론**: 신규 가입 셸 INSERT가 명시적으로 채우는 NOT NULL 컬럼은 모두 일치. drizzle에서 누락된 `CUSTOM_WEIGHT`·`PODO_LESSON_TOOL`은 DB DEFAULT가 적용되어 INSERT 가능. 본 작업에서 drizzle 스키마 보강은 선택적 (향후 PRD에서 정리 권장).

## 1.3 `TUTOR_TYPE` 값 분포

```
SELECT TUTOR_TYPE, COUNT(*) FROM GT_TUTOR GROUP BY TUTOR_TYPE
```

| TUTOR_TYPE | rows |
|---|---|
| `'일본어'` | 1,576 |
| `'영어'` | 830 |
| **`'중국어'`** | **44** |

**중요 발견**: 프로덕션에 `'중국어'` 튜터 44명 존재. Seed가 ENUM('영어','일본어')로 제한하면 호환성 충돌 발생.

**대응 결정**:
- 신규 4 테이블의 `tutor_type` 컬럼은 **VARCHAR(20)** 사용 (ENUM 사용 금지) → 미래 확장 + 기존 '중국어' 호환
- 가입 폼 드롭다운은 **'영어' / '일본어' 2개만** 노출 (Chinese 신규 가입은 본 작업 범위 외)
- 기존 '중국어' 튜터는 grandfather 백필로 `IS_TRAINING_GRANDFATHERED='Y'` 자동 설정됨 → 잠금 영향 없음, 온보딩 즉시 활성. 단 본인 언어 코스가 0개라 `/training`에서 빈 hero + 빈 그리드 + 즉시 활성 온보딩 V3 타일을 봄. UX 이슈는 미미 (44명 + grandfather).

## 1.4 `GT_USER.EMAIL` collation과 lowercase 정규화 호환성

```
SHOW FULL COLUMNS FROM GT_USER LIKE 'EMAIL';
-- Collation: utf8mb3_bin (case-SENSITIVE)
SELECT COUNT(*) FROM GT_USER WHERE EMAIL <> LOWER(EMAIL); -- 92
```

`GT_TUTOR.EMAIL`도 동일하게 `utf8mb3_bin` UNIQUE.

**중요 발견**: collation이 case-sensitive이므로 `'Alice@x'`와 `'alice@x'`가 DB 차원에서 서로 다른 값으로 취급됨. 92건 mixed-case 행이 존재.

**대응 결정**:
- 신규 signup은 입력을 `trim() + toLowerCase()`로 정규화 후 저장
- 중복 검사는 단순 `WHERE EMAIL = ?` 대신 **`WHERE LOWER(EMAIL) = LOWER(?)`** 로 case-insensitive 비교 → 'Alice@x' 기존 유저를 'alice@x'로 hijack 가입 방지
- 마이그레이션 SQL로 기존 mixed-case 행을 일괄 lowercase 변환하지 **않음** (기존 사용자의 정확 case 로그인 경로를 깨지 않기 위함 — 92명만 영향)

## 종료 게이트

- [x] §1.1 podo-backend 학생향 GT_TUTOR 노출 경로 — 패치 불필요 (Track C SKIP)
- [x] §1.2 GT_TUTOR DDL ↔ drizzle 검토 — 셸 INSERT 호환, drizzle 보강은 선택
- [x] §1.3 `'중국어'` 발견 — 신규 테이블 tutor_type을 ENUM 대신 VARCHAR(20)으로, 신규 가입은 영어/일본어만 허용
- [x] §1.4 EMAIL utf8mb3_bin + 92 mixed-case 행 — 신규 signup 정규화 + case-insensitive 중복 검사로 안전
