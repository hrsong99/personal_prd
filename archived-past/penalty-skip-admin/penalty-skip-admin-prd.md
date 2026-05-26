# 패널티 스킵권 어드민 관리 — 구현 PRD

*작성일: 2026-05-22 · 출처: Ouroboros PM 인터뷰(`interview_20260522_081916`) + dev 인터뷰(Path B)*
*관련 문서: `pm.md` (PM seed 원본)*

---

## 1. 한 줄 목표

> grape 어드민의 학생 상세(`podo_students.php`)에서 버튼으로 여는 별도 팝업 페이지를 추가해, CS 운영자가 학생의 활성 수강권별 패널티 스킵권 한도(`GT_SUBSCRIBE_MAPP.PENALTY_WAIVER_MAX_COUNT`)를 증감 수정하고 사용 내역(`le_student_penalty_waiver_usage`)을 조회·삭제할 수 있게 하며, 모든 DB 변경은 grape PHP가 직접 수행하고 `insert_log`로 감사 기록을 남긴다.

운영자가 코드 배포나 직접 SQL 실행 없이 특정 유저에게 패널티 스킵권을 더 줄 수 있도록 한다.

---

## 2. 배경 — 패널티 스킵권의 동작 원리

"패널티 스킵권"은 코드상 **"패널티 방어권 / penalty waiver"** 로 불린다. 별도의 티켓 테이블이 없다.

| 항목 | 위치 | 설명 |
|---|---|---|
| **한도** | `GT_SUBSCRIBE_MAPP.PENALTY_WAIVER_MAX_COUNT` (`int`, default 0) | 수강권 계약 1건당 사용 가능한 최대 횟수 |
| **사용 이력** | `le_student_penalty_waiver_usage` (1 사용 = 1 행) | `UNIQUE(class_id, event_type)` — 수업 1건당 CANCEL/NOSHOW 각 1회만 |
| **잔여** | 계산값 | `PENALTY_WAIVER_MAX_COUNT − COUNT(usage rows WHERE subscribe_mapp_id = ?)` |

- 소비 흐름: 학생이 수업을 CANCEL/NOSHOW 하면 `podo-backend`의 `StudentPenaltyWaiverService.tryUseWaiver(...)`가 한도 내에서 패널티를 면제하고 `le_student_penalty_waiver_usage`에 1행을 기록한다.
- 백엔드에는 **소비(use) API만 있고 부여(grant) API는 없다** (`POST /api/v1/admin/student-penalty-waiver/use`).
- 전체 소비 기능은 GrowthBook 플래그 `tbd_260512_student_cancel_penalty_relaxation`로 게이팅된다.
- 운영 현황(2026-05-22 기준): `PENALTY_WAIVER_MAX_COUNT=1`인 수강권 3,631건, 사용 이력 422건(2026-05-12~).

`le_student_penalty_waiver_usage` 스키마:
```
id                VARCHAR(32)  PK
student_id        INT          면제 적용 학생 ID
subscribe_mapp_id VARCHAR(32)  수강권 계약 ID (GT_SUBSCRIBE_MAPP.ID)
class_id          BIGINT       면제 적용 수업 ID
event_type        VARCHAR(20)  'CANCEL' 또는 'NOSHOW'
utc_created_at    DATETIME     면제 사용 UTC 시각
UNIQUE KEY uk_penalty_waiver_class_event (class_id, event_type)
```

---

## 3. 범위

### 포함
- grape 어드민에 패널티 스킵권 조회 / 한도 수정 / 사용 내역 삭제 기능 추가.

### 제외 (Decide Later)
- 유저 앱 메시지·프론트엔드 변경 — **절대 변경하지 않는다.**
- Slack 알림 연동.
- 종료/삭제된(비활성) 수강권의 스킵권 내역 조회.
- 백엔드(`podo-backend`) 변경 — 잔여 계산 쿼리 `countBySubscribeMappId` 포함 무변경.

---

## 4. 핵심 설계 결정

| # | 결정 사항 | 선택 | 근거 |
|---|---|---|---|
| D1 | 진입 화면 | 학생 상세(`podo_students.php`)에 추가 | 학생 단위로 한 화면에서 처리 (운영 시나리오 A·B 동시 발생) |
| D2 | 화면 형태 | **별도 팝업 페이지** (버튼 → 팝업) | 학생 상세의 기존 패턴(구독 내역·패널티 이력·수업 스킵 관리가 모두 버튼→팝업) |
| D3 | 표시 범위 | 활성 수강권만 | 종료/삭제된 수강권 제외 |
| D4 | 수강권 필터 기준 | 백엔드 `isUsableSubscribeMapp` **적격 조건과 동일** (단 한도값 0 포함 표시) | 어드민에 보이는 수강권 = 실제 스킵권이 동작하는 수강권. 한도 0 수강권에 신규 부여하려면 목록에 보여야 함 |
| D5 | DB 쓰기 경로 | **grape PHP가 DB 직접 UPDATE/DELETE** | 기존 `admin_subscribe_mapp_ps.php`가 `GT_SUBSCRIBE_MAPP`을 직접 UPDATE하는 패턴과 동일. 백엔드 무변경 |
| D6 | 사용 내역 삭제 방식 | 실제 DB `DELETE` (soft delete 아님, `deleted` 컬럼 추가 안 함) | `countBySubscribeMappId`가 행 수를 세므로 행 삭제 시 잔여 자동 복구. 백엔드 쿼리 수정 불필요 |
| D7 | 삭제 가능 범위 | 사용 내역 목록의 **아무 행이나** 선택 삭제 (최근 건 제한 없음) | 운영 유연성 |
| D8 | 한도 수정 방향 | 증가·감소 모두 허용 | 부여뿐 아니라 잘못 설정된 한도 정정도 필요 |
| D9 | 한도 하한 검증 | 현재 사용 횟수보다 낮은 값은 **저장 차단** | 음수 잔여 방지 |
| D10 | 한도 상한 | 없음 | 운영자 재량 |
| D11 | 안전장치 | 확인 팝업 + `insert_log` 변경이력 | 누가/언제/무엇을 추적. Slack 알림은 불필요 |
| D12 | 사용 내역 표시 | `GT_CLASS` 조인 — 수업 일시·튜터 등 부가정보 표시 | 운영자가 어느 수업인지 식별 쉬움 |

---

## 5. 기능 명세

### 5.1 진입점 — 학생 상세 버튼
- `admin/podo_students.php`의 학생 상세 분기(`USER_ID` 지정 시)에 **"패널티 스킵권 관리"** 버튼 추가.
- 기존 `user_penalty_history.php`(패널티 이력) / `podo_skip_lesson_manage.php`(수업 스킵 관리) 버튼 옆에 배치.
- 클릭 시 `penalty_waiver_manage.php?USER_ID=<id>` 팝업창을 연다 (`window.open(...)`, 기존 팝업 버튼과 동일한 방식).

### 5.2 팝업 페이지 — 조회
- 대상 학생의 **활성 수강권 목록**을 표시 (D4 필터). 활성 수강권이 여러 개면 각각 카드/섹션으로 표시, 없으면 빈 상태 안내.
- 수강권별로 표시:
  - 수강권 식별 정보(수강권명, `GT_SUBSCRIBE_MAPP.ID`, 상태, 시작/종료일 등).
  - **한도** `PENALTY_WAIVER_MAX_COUNT` / **사용** `COUNT(usage)` / **잔여** = 한도 − 사용.
  - **사용 내역 테이블**: 각 `le_student_penalty_waiver_usage` 행 → `GT_CLASS` 조인하여 수업 일시·튜터명, `event_type`(CANCEL/NOSHOW), 사용 시각 표시.
  - 시각은 UTC 저장값이므로 grape의 `getAdminTimezoneOffset` + `CONVERT_TZ`로 어드민 타임존 변환 표시 (기존 grape 페이지 관행).

### 5.3 한도 수정 (시나리오 B)
- 수강권별 한도 입력 필드 + 저장 버튼.
- 저장 시 확인 팝업 → `process` 스크립트가 `UPDATE GT_SUBSCRIBE_MAPP SET PENALTY_WAIVER_MAX_COUNT = ? WHERE ID = ?`.
- **검증**: `신규값 >= 현재 사용 횟수` 그리고 `신규값 >= 0`. 위반 시 저장 차단 + 에러 메시지(예: "이미 N회 사용되어 한도를 N 미만으로 내릴 수 없습니다"). 상한 없음.

### 5.4 사용 내역 삭제 (시나리오 A)
- 사용 내역 테이블의 각 행에 삭제 버튼.
- 삭제 시 확인 팝업 → `process` 스크립트가 `DELETE FROM le_student_penalty_waiver_usage WHERE id = ?`.
- 삭제 후 해당 수강권의 사용/잔여 카운트가 갱신되어 학생 앱의 잔여 스킵권이 1 증가한다(기존 `countBySubscribeMappId` 기반).
- ⚠️ **운영자 안내 문구 필수**: 사용 내역 행 삭제는 *스킵권 슬롯을 되돌려줄 뿐*, 그때 면제됐던 수업의 CANCEL/NOSHOW 패널티를 다시 부과하지 않는다. 이미 처리 완료된 수업이며 이 행은 사용 장부일 뿐이다.

### 5.5 변경이력 (감사 로그)
- 모든 변경(한도 수정·사용 내역 삭제)에 대해 grape 기존 `insert_log($db, $_SESSION['user_admin_id'], $action, $detail, $result)` 호출.
- action 코드 예: `UPDATE_PENALTY_WAIVER_MAX_COUNT`, `DELETE_PENALTY_WAIVER_USAGE`.
- `$detail`에 포함: `student_id`, `subscribe_mapp_id`, (한도 수정 시) 변경 전/후 값, (삭제 시) 삭제한 usage 행 `id`·`class_id`·`event_type`.

---

## 6. 기술 설계 — grape

### 변경 파일
| 파일 | 작업 |
|---|---|
| `admin/podo_students.php` | 학생 상세 분기에 "패널티 스킵권 관리" 버튼 추가 (`window.open` 핸들러) |

### 신규 파일 (기존 `admin/subscribe_mapp/` 구조 미러링)
| 파일 | 역할 |
|---|---|
| `admin/penalty_waiver/penalty_waiver_manage.php` | 조회 팝업 페이지. `check_admin.php` + 읽기 커넥션(`db_ro_conn.php`)으로 활성 수강권/한도/사용내역 조회·렌더링 |
| `admin/penalty_waiver/process/penalty_waiver_ps.php` | 쓰기 처리 스크립트. 쓰기 커넥션(`db_conn.php`). `action`별로 한도 UPDATE / usage DELETE 수행, 검증, `insert_log` 기록 |

> 파일 경로는 컨벤션 제안값이며, 평탄 구조(`admin/penalty_waiver_manage.php` + `admin/process/penalty_waiver_ps.php`)도 무방. process 스크립트는 `admin/subscribe_mapp/process/admin_subscribe_mapp_ps.php` 패턴을 따른다.

### DB 작업
- 읽기: 활성 수강권 조회(`GT_SUBSCRIBE_MAPP` + D4 필터), 수강권별 `le_student_penalty_waiver_usage` 조회(`GT_CLASS` 조인).
- 쓰기: `UPDATE GT_SUBSCRIBE_MAPP SET PENALTY_WAIVER_MAX_COUNT` / `DELETE FROM le_student_penalty_waiver_usage`.
- **스키마 변경 없음.** 컬럼·테이블 추가 없음.

### D4 활성 수강권 필터 (백엔드 `isUsableSubscribeMapp`와 동일, 단 한도값 무관)
```
SUBSCRIBE_YN = 'Y'
AND IFNULL(DEL_YN, 'N') <> 'Y'
AND PAYMENT_ID IS NOT NULL
AND STATUS IN ('SUBSCRIBE', 'LUMP_SUM', 'EXTEND')
-- PENALTY_WAIVER_MAX_COUNT > 0 조건은 제외 (한도 0 수강권도 신규 부여 위해 표시)
```

### 권한
- 팝업 페이지·process 스크립트 모두 `check_admin.php`로 보호 (grape 기존 권한 체계). 별도 `GT_ADMIN_MENU` 행은 불필요 — 독립 메뉴가 아니라 학생 상세에서 여는 팝업이므로.

---

## 7. 엣지 케이스

| 상황 | 처리 |
|---|---|
| 학생에게 활성 수강권 0개 | 빈 상태 안내 메시지 |
| 활성 수강권 여러 개 | 각 수강권을 개별 섹션으로 표시, 각각 독립적으로 한도 수정·사용내역 관리 |
| 한도를 사용 횟수 미만으로 입력 | 저장 차단 + 에러 메시지 (D9) |
| 사용 내역 삭제 | 슬롯만 복구, 수업 패널티 재부과 안 함 (5.4 안내 문구) |
| GrowthBook 플래그 OFF 상태 | 어드민 도구는 플래그와 무관하게 동작 — 데이터(한도/이력)를 미리 세팅 가능. 플래그는 소비(`tryUseWaiver`)에만 영향 |
| 운영자 수정 vs 학생 소비 동시 발생 | grape 직접 UPDATE — 드문 레이스, 어드민 도구로서 허용 범위. 백엔드는 소비 시 `findByIdForUpdate` 락 사용 |

---

## 8. 성공 기준 / 검증 방법

검증은 수동(grape에 자동 테스트 부재):

1. 운영자가 코드 배포·직접 SQL 없이 어드민에서 특정 학생에게 패널티 스킵권을 추가 부여할 수 있다.
2. 한도 수정 후 학생 앱의 잔여 스킵권 수가 정확히 반영된다.
3. 사용 내역 1건 삭제 후 학생 앱의 잔여 스킵권이 정확히 1 증가한다 (`countBySubscribeMappId` 기반).
4. 모든 변경(한도 수정/삭제)에 대해 `insert_log`에 감사 로그 행이 남는다.
5. 현재 사용 횟수보다 낮은 한도 값 입력 시 저장이 차단된다.
6. 유저 앱 메시지·프론트엔드는 변경되지 않는다.

---

## 9. 미해결 / 추후 결정 (Decide Later)

- Slack 알림 연동.
- 종료/삭제된 수강권의 스킵권 내역 조회.
- 유저 앱 프론트엔드 변경.
- 반복 운영 수요가 크면, grape 직접 DB 쓰기 대신 `podo-backend`에 정식 grant/delete API + 검증 로직을 두는 방향으로 승격 검토.

---

## 부록: 코드 레퍼런스

| 항목 | 위치 |
|---|---|
| 백엔드 소비 로직 | `podo-backend` `applications/user/service/StudentPenaltyWaiverService.java` (`tryUseWaiver`) |
| 백엔드 잔여 카운트 | `StudentPenaltyWaiverUsageRepository.countBySubscribeMappId` |
| 백엔드 소비 어드민 API | `StudentPenaltyWaiverAdminController` — `POST /api/v1/admin/student-penalty-waiver/use` |
| DDL | `podo-backend` `src/main/resources/db/migration/student_penalty_waiver_usage_ddl.sql` |
| grape 수강권 직접 UPDATE 선례 | `admin/subscribe_mapp/process/admin_subscribe_mapp_ps.php` |
| grape 감사 로그 함수 | `inc/db_class.php` → `insert_log($db, $user, $action, $sql, $result)` |
| grape NOSHOW→소비 트리거 | `inc/student_penalty_waiver_trigger.php`, `admin/process/class_ps.php` |
