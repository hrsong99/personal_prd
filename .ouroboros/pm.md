# 패널티 스킵권 어드민 관리

*Created At: 2026-05-22T08:35:24.468323+00:00*

## Goal

CS/운영자가 코드 배포나 직접 SQL 없이 grape 어드민에서 특정 학생의 패널티 스킵권(패널티 방어권)을 조회·삭제·한도 수정할 수 있도록 한다.

## User Stories

1. **As a** CS/운영 담당자, **I want to** 학생 상세 페이지(podo_students.php)에서 해당 학생의 활성 수강권에 대한 패널티 스킵권 사용 내역을 조회한다, **so that** 학생의 스킵권 현황을 한눈에 파악할 수 있다.
2. **As a** CS/운영 담당자, **I want to** 학생이 실수로 사용한 스킵권의 사용 내역(le_student_penalty_waiver_usage)을 선택하여 삭제한다 (시나리오 A), **so that** 잘못 사용된 스킵권을 되돌려줄 수 있다.
3. **As a** CS/운영 담당자, **I want to** 수강권(GT_SUBSCRIBE_MAPP)의 PENALTY_WAIVER_MAX_COUNT 한도를 올리거나 내린다 (시나리오 B), **so that** 스킵권 한도가 부족한 학생에게 추가 스킵권을 부여하거나 잘못 설정된 한도를 정정할 수 있다.
4. **As a** CS/운영 담당자, **I want to** 사용 내역 삭제와 한도 수정을 학생 단위 단일 화면에서 동시에 처리한다, **so that** 두 조작을 동시에 해야 하는 케이스에서도 화면 전환 없이 한 번에 처리할 수 있다.
5. **As a** CS/운영 담당자 (또는 감사자), **I want to** 누가 언제 무엇을 변경했는지 변경이력 로그를 확인한다, **so that** 조작에 대한 감사 추적이 가능하다.

## Constraints

- 유저용 메시지 및 프론트엔드는 변경하지 않는다 — 어드민(grape)만 수정
- 진입점은 기존 podo_students.php 학생 상세 페이지에 섹션 추가 (별도 메뉴 X)
- 활성(진행중) 수강권만 표시 — 종료/삭제된 수강권은 제외
- 사용 내역 삭제는 실제 DB DELETE (soft delete 아님, deleted 컬럼 추가 안 함)
- 삭제·수정 시 확인 팝업 필수
- 변경이력은 grape 기존 insert_log 패턴으로 기록 (누가, 언제, 무엇을)
- 한도(PENALTY_WAIVER_MAX_COUNT) 수정 시 현재 사용 횟수보다 낮은 값으로 저장 차단 (음수 잔여 방지)
- 한도 상한선 없음 — 운영자 재량
- 백엔드 잔여계산 쿼리(countBySubscribeMappId)는 수정 불필요
- Slack 알림은 불필요

## Success Criteria

1. CS/운영자가 코드 배포나 직접 SQL 실행 없이 grape 어드민에서 특정 학생의 패널티 스킵권을 추가 부여할 수 있다
2. 사용 내역 삭제 후 학생 앱에서 잔여 스킵권 수가 정확하게 1 증가한다 (기존 countBySubscribeMappId 쿼리 기반)
3. 한도 수정 후 학생 앱에서 잔여 스킵권 수가 정확하게 반영된다
4. 모든 변경(삭제/수정)에 대해 insert_log에 감사 로그가 남는다
5. 현재 사용 횟수보다 낮은 한도 값 입력 시 저장이 차단된다

## Assumptions

- 한 학생의 활성 수강권은 보통 1개이다
- le_student_penalty_waiver_usage 사용 내역은 수강권(subscribe_mapp_id)별로 묶여 있다
- 기존 백엔드 잔여 계산 쿼리(countBySubscribeMappId)는 해당 수강권의 le_student_penalty_waiver_usage 행 수를 카운트하므로, 행 DELETE 시 자동으로 잔여가 복구된다
- grape 어드민에 insert_log 패턴이 이미 존재하며 동일 방식으로 활용 가능하다
- 운영자 권한 제어는 grape 기존 권한 체계를 따른다

## Decide Later

The following items were deferred or identified as premature at this stage. They should be revisited when more context is available:

- Slack 알림 연동
- 종료/삭제된 수강권의 스킵권 내역 조회
- 유저 앱 프론트엔드 변경

## Existing Codebase Context

- **grape** (`/Users/johnsong/grape`)
- **podo-app** (`/Users/johnsong/podo-app`)
- **podo-backend** (`/Users/johnsong/podo-backend`)

---
*PM ID: pm_seed_interview_20260522_081916*
*Interview ID: interview_20260522_081916*
