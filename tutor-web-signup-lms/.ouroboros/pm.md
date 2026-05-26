# Tutor Web Signup + Training LMS + Onboarding Gate

*Created At: 2026-05-26T05:48:27.954524+00:00*

## Goal

tutor-web에 자체 회원가입, 필수 교육(Training LMS), 온보딩 활성화 게이트를 추가하여 신규 튜터가 가입→교육 완료→온보딩→어드민 검수 파이프라인을 거친 후에만 학생에게 노출되도록 한다.

## User Stories

1. **As a** 신규 튜터, **I want to** 이메일+비밀번호+언어(영어/일본어)로 자체 회원가입, **so that** 별도 인증·승인 절차 없이 즉시 교육을 시작할 수 있다.
2. **As a** 신규 튜터, **I want to** 필수 교육 코스의 텍스트·영상 아이템을 순차적으로 완료, **so that** 온보딩 버튼이 활성화되어 온보딩 절차를 진행할 수 있다.
3. **As a** 신규 튜터, **I want to** 보충 교육 코스를 자유 순서로 학습, **so that** 추가 지식을 습득하되 온보딩 진행에 방해받지 않는다.
4. **As a** 신규 튜터, **I want to** /training 페이지에서 진도 현황(hero 카드)과 코스 목록을 한눈에 확인, **so that** 남은 교육량과 온보딩까지의 경로를 직관적으로 파악할 수 있다.
5. **As a** 신규 튜터, **I want to** 필수 교육 완료 후 온보딩 버튼을 클릭하여 외부 온보딩 폼으로 이동, **so that** 온보딩 절차를 시작하여 최종적으로 학생 대면 가능 상태에 도달한다.
6. **As a** 기존 튜터 (grandfather), **I want to** 교육 잠금 없이 바로 온보딩 버튼이 활성화된 상태로 /training에 접근, **so that** 기존 활동에 지장 없이 보충 교육을 선택적으로 학습할 수 있다.
7. **As a** grape 어드민, **I want to** 코스 편집 화면에서 코스/섹션/아이템을 생성·수정·비활성화·삭제·순서변경, **so that** 교육 콘텐츠를 자유롭게 관리하여 운영 요구에 대응한다.
8. **As a** grape 어드민, **I want to** podo_teachers_v1.php에서 '검수 대기' 필터로 교육 완료 튜터를 조회하고 CLASS_AVAILABLE=1로 승인, **so that** 교육을 마친 튜터만 선별하여 학생에게 노출시킨다.
9. **As a** grape 어드민, **I want to** 튜터별 '교육 진도' 팝업에서 코스/아이템 완료 현황을 읽기 전용으로 확인, **so that** 개별 튜터의 교육 진행 상태를 파악하여 검수 판단을 내린다.

## Constraints

- podo-backend 변경 최소화 — Phase 0 감사에서 CLASS_AVAILABLE 필터 누락이 발견되면 작은 SELECT 필터 추가 수준만 허용; 규모가 크면 별도 PRD로 분리
- 비밀번호 해싱은 기존 SHA1 방식 유지 (레거시 호환)
- 이메일 인증 메일 발송 없음 — 형식(regex) 검증만, trim + toLowerCase 정규화 저장
- 비밀번호 재설정 흐름 v1 미제공 — 로그인 화면에 '관리자 문의' 안내만 표시; grape 어드민이 SHA1로 직접 재설정
- 비밀번호 최소 8자, 복잡도 규칙 미강제 (클라이언트 가이드만 표시)
- 영상·아이콘 S3 공개 버킷 — URL 영구 공개, presigned URL 없음 (v1 후속 강화)
- iOS 네이티브 풀스크린 비활성 (시스템 플레이어 seekbar 제어 불가, D14)
- 영상 재생 속도 1x 고정 — 컨트롤바·키보드 단축키 속도 옵션 제거
- TUTOR_TYPE은 기존 한글 문자열 '영어' / '일본어' 그대로 사용 (레거시 호환)
- 검증은 수동 (17개 시나리오)
- GT_USER↔GT_TUTOR 간 FK 추가하지 않음 — EMAIL이 사실상 연결 키 (기존 AuthService.loginByEmail 패턴 유지)
- 온보딩 버튼 클릭 시 DB 플립 없음 — 외부 URL 이동만 수행
- 화면 목업 12개 + 디자인 옵션 3종 중 변형 3(온보딩 V3 타일) 채택 확정

## Success Criteria

1. 신규 튜터가 이메일+비밀번호+언어로 가입 시 GT_USER + GT_TUTOR 셸 행이 단일 DB 트랜잭션으로 동시 생성되며, CLASS_AVAILABLE=0이고 이메일 중복 시 차단됨
2. 가입 직후 /training 페이지로 리다이렉트되며, 해당 언어의 필수·보충 코스가 올바르게 표시됨
3. 필수 코스 내 아이템이 section.order_no → item.order_no 기준 전역 선형 잠금으로 동작함 (이전 아이템 완료 시 다음 해제, 코스 간 독립)
4. 텍스트 아이템은 '다음' 버튼 클릭 시 완료, 영상 아이템은 timeline 기준 95% 도달 시 완료로 기록됨
5. 영상 seek 가드: 목표 위치가 watched_sec + 1초 이하면 허용, 초과 시 watched_sec으로 스냅백
6. 완료된 아이템은 seek 자유 (D8)
7. IS_TRAINING_DONE 래치가 3곳(진도 기록, 가입 직후, /training 진입)에서 idempotent하게 평가되어 조건 충족 시 'Y'로 1회 플립됨
8. 필수 아이템이 0개인 경우 가입 직후 래치 체크에서 즉시 IS_TRAINING_DONE='Y' 래치됨 (빈 공집합 방어)
9. 온보딩 버튼 활성화 게이트: (IS_TRAINING_DONE='Y') OR (IS_TRAINING_GRANDFATHERED='Y')
10. 온보딩 URL이 튜터 언어별로 TB_SYS_CODE_DETAIL에서 분기 로드되고, ?email={이메일} 쿼리 파라미터가 append됨
11. 해당 언어의 ONBOARDING_URL 미설정 시 버튼 숨김 + '어드민에 설정 요청' 안내 표시
12. 검수 대기 필터: CLASS_AVAILABLE=0 AND (IS_TRAINING_DONE='Y' OR IS_TRAINING_GRANDFATHERED='Y') 조건으로 grape 어드민에서 조회 가능
13. 출시 시 GT_TUTOR의 모든 기존 행에 IS_TRAINING_GRANDFATHERED='Y' 1회 백필, 이후 신규 가입자는 기본값 'N'
14. IS_TRAINING_DONE 래치 덕분에 이미 교육 완료한 튜터는 어드민의 콘텐츠 변경(추가·삭제·순서변경)에 영향받지 않음
15. heartbeat API (PATCH /items/:itemId/progress)는 watched_sec만 업데이트하고 래치 체크 미실행; 완료 API (POST /items/:itemId/complete)에서만 래치 체크 실행
16. grape 어드민 코스 편집에서 is_mandatory 토글 시 경고 다이얼로그 표시, 삭제 시 ON DELETE CASCADE로 자식·진도 행 동시 삭제
17. Phase 0 감사 완료: 학생향 튜터 조회 경로의 CLASS_AVAILABLE 필터 적용 여부, GT_TUTOR DDL↔drizzle 스키마 일치, TUTOR_TYPE 값 분포, GT_USER EMAIL collation 확인

## Assumptions

- GT_TUTOR의 기존 컬럼들은 teachers_v1_ps.php 패턴처럼 빈 문자열 INSERT로 NOT NULL 제약을 충족할 수 있다 (Phase 0에서 DDL 검증 예정)
- CLASS_AVAILABLE=0인 셸 행 튜터는 기존 podo-backend 학생 노출 쿼리에서 필터링될 것이다 (Phase 0 코드 감사로 검증 예정, 누락 시 소규모 패치 허용)
- 기존 GT_TUTOR의 TUTOR_TYPE 값은 '영어' / '일본어' 한글 문자열로 통일되어 있다 (Phase 0에서 SELECT DISTINCT로 검증 예정)
- GT_USER의 EMAIL 컬럼에 lowercase 정규화를 적용해도 기존 데이터와 충돌하지 않는다 (Phase 0에서 collation 검증 예정)
- GT_USER와 GT_TUTOR는 같은 DB(gwatop) 내에 있으므로 단일 트랜잭션으로 원자적 INSERT가 가능하다
- grape admin의 inc/upload_presigned_for_s3.php 업로드 유틸리티가 공개 ACL로 객체를 저장하므로 별도 버킷 설정 변경 없이 재사용 가능하다
- 외부 온보딩 폼은 ?email= 쿼리 파라미터를 받아 prefill할 수 있다
- 어드민이 is_mandatory 토글, use_yn 변경, 순서 변경 등을 신중하게 운영한다 (경고 다이얼로그 + PRD 가이드라인으로 안전망 제공)

## Decide Later

The following items were deferred or identified as premature at this stage. They should be revisited when more context is available:

- CLASS_AVAILABLE=0으로 생성되는 셸 행이 기존 podo-backend의 학생 노출/예약 로직에서 자연스럽게 필터링되는 건 확인된 사실인가요, 아니면 가정인가요? — Phase 0 감사로 전환되었으나, 감사 결과에 따라 podo-backend 패치 범위가 결정됨
- 영상 변조 방지 (서버 판정 / heartbeat 기반 누적 시청 시간 검증)
- 이메일 인증 (인증 메일 발송)
- 비밀번호 재설정 (리셋 링크·임시 PW 이메일 발송)
- S3 presigned URL / CloudFront signed URL 기반 교육 영상 접근 통제
- S3 고아 객체 정리
- grape 어드민에서 튜터 교육 진도 수정 기능 (v1은 읽기 전용)
- DDL 검증 자동화
- 검수 대기 필터 정확 조건의 운영 최적화 (v1 조건은 확정됨, 후속에서 튜닝)
- IS_TRAINING_GRANDFATHERED 영구성 정책 재검토

## Existing Codebase Context

- **grape** (`/Users/johnsong/grape`)
- **podo-app** (`/Users/johnsong/podo-app`)
- **podo-backend** (`/Users/johnsong/podo-backend`)

---
*PM ID: pm_seed_interview_20260526_042907*
*Interview ID: interview_20260526_042907*
