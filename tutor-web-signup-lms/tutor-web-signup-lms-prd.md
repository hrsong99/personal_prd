# 튜터 웹사이트 — 자체 회원가입 + 교육(LMS) + 온보딩 — 구현 PRD

*작성일: 2026-05-22 · 출처: `/search-repos` 코드 조사 + 사용자 결정사항*

---

## 1. 한 줄 목표

> 튜터 웹사이트(`podo-app`의 `apps/tutor-web`)에 ① 로그인 페이지에서 이메일·비밀번호만으로 튜터가 직접 계정을 만드는 자체 회원가입, ② grape 어드민에서 편집하는 간단한 교육 시스템(LMS) — 코스 > 섹션 > 텍스트·영상, 필수/보충 구분, 필수 코스는 영상 완주 시까지 다음 섹션 잠금, ③ 필수 교육 완료 시 노출되는 온보딩 링크 버튼을 추가한다.

신규 튜터가 어드민의 수작업 계정 생성을 기다리지 않고 스스로 가입하고, 필수 교육을 마친 뒤 온보딩으로 넘어가는 흐름을 만든다.

---

## 2. 배경 — 현재 구조

### 2.1 튜터 웹사이트의 위치
- 튜터 웹사이트는 `podo-app` 레포의 `apps/tutor-web` — **자체 Hono API + DB 직접 접근을 가진 독립 Next.js 15 앱**이다.
- `src/server`에 Hono RPC가 `/api/v1`로 마운트되어 있고, `gwatop` MySQL을 drizzle-orm으로 직접 조회한다 (`src/server/db`, 스키마는 `server/db/schema/*`가 레거시 `GT_*` 테이블을 미러링).
- **podo-backend는 전혀 거치지 않는다.** 이 기능의 백엔드 변경은 모두 `apps/tutor-web/src/server` 안에서 이뤄진다.

### 2.2 현재 로그인 동작
- `AuthService.loginByEmail` (`apps/tutor-web/src/server/modules/auth/service.ts`)은 `GT_USER` ⋈ `GT_TUTOR`를 **EMAIL로 조인**하고 `GT_USER.USER_PW = SHA1(password)`를 확인한다.
- 즉 튜터가 로그인하려면 **자격증명용 `GT_USER` 행과 튜터 프로필용 `GT_TUTOR` 행이 같은 이메일로 둘 다 존재**해야 한다.
- 현재 회원가입 UI는 없다. `(before-login)` 라우트 그룹에는 `login`만 있다.
- 토큰: JWT를 Redis에 저장(access + 선택적 refresh), 쿠키로 발급.

### 2.3 현재 어드민 튜터 생성
- grape `admin/process/teachers_v1_ps.php`: `GT_TUTOR` INSERT → 민감정보(나이/계좌) AES 암호화 → `GT_USER`를 `USER_PW = SHA1('1234')` 기본 비밀번호로 INSERT.
- 즉 튜터는 지금까지 **자기 비밀번호를 직접 정한 적이 없다.**

### 2.4 LMS / 교육 기능
- 현재 튜터 웹사이트에 교육·LMS 기능은 **전혀 없다.**
- 가장 가까운 참고 패턴: 공지(`GT_BOARD`, HTML 렌더), grape `admin/cms/content_*.php`(콘텐츠 CMS). 둘 다 *템플릿*으로만 참고하며, LMS는 독자 데이터 모델과 진도 추적이 필요하다.
- 튜터 웹사이트에는 **영상 플레이어가 없다** — 신규로 추가해야 한다.

---

## 3. 범위

### 포함
- 튜터 웹사이트 자체 회원가입(이메일+비밀번호).
- 튜터 웹사이트에 **교육(Training)** 신규 탭 — 사이드 네비게이션(데스크톱/태블릿)과 하단 네비게이션(모바일) 양쪽에 추가.
- grape 어드민의 LMS 코스 편집 화면.
- 필수 교육 완료 시 온보딩 버튼.
- 온보딩 링크의 grape 설정.

### 제외 (Decide Later)
- 이메일 인증 / 가입 승인 절차 — **하지 않는다** (사용자 결정).
- SHA1 → 강한 해시 마이그레이션 — **하지 않는다** (SHA1 유지, 사용자 결정).
- 비밀번호 재설정 / 찾기 흐름.
- 보충(supplementary) 코스의 잠금·게이팅 — 보충 코스는 자유 열람.
- 영상 시청의 변조 방지(서버측 시청 구간 누적 추적) — 앞으로 건너뛰기 차단은 v1 포함, devtools 등 의도적 우회 방지는 제외. §9 참고.
- podo-backend 변경 — 무변경.

---

## 4. 핵심 설계 결정

| # | 결정 사항 | 선택 | 근거 |
|---|---|---|---|
| D1 | 회원가입 방식 | **공개 자체 가입(Option A)** — 이메일+비밀번호, 인증·승인 없음 | 신규 튜터가 어드민 대기 없이 즉시 가입 |
| D2 | 가입 시 생성 행 | `GT_USER` + **최소 `GT_TUTOR` 셸 행** 동시 생성 | 로그인이 두 행을 모두 요구(§2.2). 셸 없으면 가입해도 로그인 불가 |
| D3 | 이메일 중복 | **차단** — 이미 `GT_USER`에 있는 이메일이면 가입 거부 | 학생/튜터 계정 병합 회피, 단순함 |
| D4 | 셸 튜터의 수업 가능 여부 | `CLASS_AVAILABLE = 0` — **어드민이 검수 후 열기 전까지 예약 불가** | 미검증 튜터가 학생에게 노출/예약되지 않게 |
| D5 | 비밀번호 해시 | `SHA1` 유지 | 플랫폼 전체가 SHA1. 호환 위해 동일 적용 |
| D6 | 영상 호스팅 | **S3** | 정확한 진도 추적 가능(HTML5 `<video>`의 `currentTime`). grape `inc/upload_*_for_s3.php` 재사용 |
| D7 | 잠금 적용 범위 | **필수(mandatory) 코스만** | 보충 코스는 자유 열람 |
| D8 | 완료 후 재시청 | 허용 — 완료 항목은 계속 열람 가능, 진도는 단조(되돌아가지 않음) | |
| D9 | 텍스트 항목 완료 처리 | **"다음(Next)" 버튼** 클릭 시 완료 | 스크롤 검증보다 단순·명확 |
| D10 | 영상 항목 완료 처리 | 시청 위치가 영상 길이의 **≥95%** 도달 시 완료 | 끝까지 본 것으로 간주 |
| D11 | 온보딩 버튼 노출 위치 | **교육 페이지에만** (당분간 홈 등 제외) | |
| D12 | 온보딩 링크 설정처 | grape 기존 공통코드 `TB_SYS_CODE_DETAIL` 1행 (그룹 `TUTOR_TRAINING`, 코드 `ONBOARDING_URL`) | 신규 어드민 UI 0 — 기존 `admin/system/code/` 화면으로 편집 |
| D13 | LMS 신규 탭 위치 | Home/Lessons/Calendar와 동등한 최상위 탭 `/training` | 사용자 결정 |
| D14 | 영상 앞으로 건너뛰기 | **차단** — 인라인 플레이어(커스텀 또는 라이브러리)로 미시청 지점 seek 차단, 되감기는 허용 | 필수 코스 영상 완주 강제. 네이티브 `controls`는 seekbar만 숨길 수 없어 커스텀 플레이어 필요 |

---

## 5. 기능 명세

### 5.1 자체 회원가입

**화면 흐름**
1. 로그인 페이지에 "계정 만들기" 링크 추가 → `/signup` 이동.
2. 회원가입 페이지: 이메일, 비밀번호(+비밀번호 확인) 입력. 이름·전화 등은 받지 않는다.
3. 제출 → 서버:
   - `GT_USER`에 동일 이메일 존재 시 → **거부**, "이미 사용 중인 이메일입니다" 메시지 (D3).
   - 트랜잭션으로 `GT_USER`와 `GT_TUTOR` 셸 행을 INSERT.
   - 자동 로그인(토큰 발급) → `/`(홈)로 이동.

**`GT_USER` INSERT** — 필수 채움: `EMAIL`, `USER_PW = SHA1(password)`, `NAME = ''`, `CLASS_TYPE = 'PODO'`, `MEMO = '튜터'`. 나머지(`CREATE_DATE`, `CREDIT` 등)는 컬럼 기본값.

**`GT_TUTOR` 셸 INSERT** — NOT NULL이며 기본값 없는 컬럼을 플레이스홀더로 채운다 (`teachers_v1_ps.php`가 빈 문자열로 INSERT하는 것이 이미 검증됨):

| 컬럼 | 셸 값 |
|---|---|
| `EMAIL` | 가입 이메일 (로그인 조인 키) |
| `NAME`, `PHONE` | `''` |
| `SEX` | `0` |
| `HOPE_CITY`, `LEV_TEACHER`, `CLASS_SUBTITLE`, `CLASS_LEVEL`, `TEACHER_CAREER`, `CLASS_INTRO` | `''` |
| `CREATE_DATE` | 현재 시각 (`SYSDATE()`) |
| `CLASS_AVAILABLE` | `0` — 검수 전 예약 불가 (D4) |
| `CLASS_TYPE` | `'PODO'` — 공지 필터가 `classType='PODO'` 기준 |
| `TUTOR_TYPE` | `NULL` — 어드민이 영어/일본어 지정 |

> ⚠️ 이메일만으로 가입하므로 `NAME`이 빈 값이다. 네비게이션·프로필에 빈 이름이 보일 수 있다 — 어드민이 검수 시 프로필을 채워야 한다.

**미들웨어 변경**: `withAuthentication`(`src/shared/config/middlewares/withAuthentication.ts`)은 현재 `isLoginPage = segments.startsWith('login')` 기준으로 로그인 페이지만 비로그인 공개 경로로 본다. `/signup`도 공개 경로에 포함해야 한다 (토큰 없을 때 `/login`으로 리다이렉트되지 않도록).

### 5.2 교육(LMS) — 튜터 화면

**신규 탭**: 사이드 네비게이션(`side-navigation.tsx`)과 하단 네비게이션 양쪽에 **교육(Training)** 항목 추가, `/training` 라우트.

**코스 목록 화면** (`/training`)
- 필수 코스와 보충 코스를 구분 표시.
- 코스별 진도(완료 항목 수 / 전체) 표시.
- 필수 교육 전체 완료 시 **온보딩 버튼** 노출 (§5.4).

**코스 상세 / 학습 화면** (`/training/[courseId]`)
- 섹션 > 항목(텍스트 | 영상) 구조로 렌더.
- 항목 진행:
  - **텍스트 항목**: 본문 표시 + 하단 "다음" 버튼. 클릭 시 완료 기록 (D9).
  - **영상 항목**: 인라인 영상 플레이어(커스텀 또는 Plyr/react-player 같은 라이브러리 기반). **앞으로 건너뛰기 차단** — 아직 보지 않은 지점으로의 seek는 마지막 시청 위치로 스냅백하고 되감기는 허용 (D14). 시청 중 주기적으로 진도 핑 전송, 시청 위치가 길이의 ≥95% 도달 시 완료 기록 (D10). 모바일에서도 **인라인 유지** — iOS는 네이티브 풀스크린 진입 시 시스템 플레이어로 넘어가 seekbar를 제어할 수 없으므로 네이티브 풀스크린은 비활성화한다.
- **잠금 (필수 코스만, D7)**:
  - 항목은 섹션 순서 → 항목 순서로 전역 정렬된다.
  - 현재 항목이 완료되어야 다음 항목이 열린다. 미완료 항목 이후의 항목·섹션은 잠금(비활성) 표시.
  - 보충 코스는 잠금 없음 — 모든 항목 자유 열람.
- **재시청 (D8)**: 완료된 항목은 잠금이 풀린 채로 계속 열람 가능. 진도는 단조 — 한번 완료되면 되돌아가지 않는다.

### 5.3 교육(LMS) — grape 어드민

- grape에 LMS 코스 편집 화면 추가. `admin/cms/content_*.php` 패턴을 참고.
- 기능: 코스 생성/수정/삭제, 코스 내 섹션·항목(텍스트/영상) 편집, 순서 지정, **필수/보충 토글**(`is_mandatory`), 코스 노출 여부(`use_yn`).
- **영상 업로드**: `inc/upload_presigned_for_s3.php`(프리사인드 — 대용량 파일에 적합) → S3 → 반환된 S3 URL을 `GT_TUTOR_TRAINING_ITEM.video_url`에 저장.
- 신규 어드민 페이지는 `GT_ADMIN_MENU`에 행 1개 INSERT로 메뉴 등록 (§2.3 컨벤션).

### 5.4 온보딩 버튼

- 완료 판정 `getMandatoryTrainingStatus(tutorId)`: `is_mandatory='Y'` AND `use_yn='Y'`인 모든 코스의 모든 항목에 해당 튜터의 완료 진도 행이 존재하면 "완료".
- 교육 페이지에서 완료 상태일 때만 온보딩 버튼 노출 (미완료 시 숨김/비활성, D11).
- 버튼 클릭 → `TB_SYS_CODE_DETAIL`에 설정된 온보딩 URL로 이동 (D12).

---

## 6. 기술 설계

### 6.1 DB 변경 (`gwatop` MySQL — grape·tutor-web 공유)

**회원가입**: 신규 테이블 없음. §5.1의 `GT_USER` / `GT_TUTOR` 셸 INSERT만.

**LMS — 신규 테이블 4개:**

```
GT_TUTOR_TRAINING_COURSE
  id            PK
  title         코스명
  is_mandatory  'Y' | 'N'  (필수 / 보충)
  order_no      정렬 순서
  use_yn        'Y' | 'N'  (노출 여부)
  created_at

GT_TUTOR_TRAINING_SECTION
  id            PK
  course_id     FK → GT_TUTOR_TRAINING_COURSE
  title         섹션명
  order_no      코스 내 정렬 순서

GT_TUTOR_TRAINING_ITEM
  id                  PK
  section_id          FK → GT_TUTOR_TRAINING_SECTION
  type                'TEXT' | 'VIDEO'
  order_no            섹션 내 정렬 순서
  text_body           TEXT  (type=TEXT일 때 본문)
  video_url           type=VIDEO일 때 S3 URL
  video_duration_sec  영상 길이(초) — 95% 판정용, 최초 확인 시 채움

GT_TUTOR_TRAINING_PROGRESS
  id            PK
  tutor_id      GT_TUTOR.ID
  item_id       FK → GT_TUTOR_TRAINING_ITEM
  completed_at  완료 시각 (NULL = 미완료, 한번 설정되면 유지)
  watched_sec   영상 마지막 시청 위치(초) — 이어보기용
  UNIQUE(tutor_id, item_id)
```

**온보딩 링크**: 기존 `TB_SYS_CODE_DETAIL`에 행 1개 (그룹 `TUTOR_TRAINING`, 코드 `ONBOARDING_URL`, 값 = URL). 스키마 변경 없음. grape `admin/system/code/` 화면으로 편집.

> 대안: 신규 1행 전용 설정 테이블. 단 공통코드 재사용이 어드민 UI 추가 비용 0이라 D12로 채택.

### 6.2 tutor-web 변경 파일 (`apps/tutor-web`)

**회원가입**
| 파일 | 작업 |
|---|---|
| `src/app/[locale]/(before-login)/signup/page.tsx` | 신규 — 회원가입 페이지 |
| `src/features/auth/ui/signup-form/` | 신규 — 가입 폼 (`login-form.tsx` 미러) |
| `src/features/auth/api/signup-action.ts` | 신규 — 서버 액션 |
| `src/server/modules/auth/controller/signup/` | 신규 — `POST /api/v1/auth/signup` |
| `src/server/modules/auth/service.ts` | 신규 `signUp()` — 이메일 중복 검사, `GT_USER`+`GT_TUTOR` 셸 트랜잭션 INSERT, 토큰 발급 |
| `src/server/modules/auth/dto/` | 신규 가입 요청/응답 스키마 |
| `src/app/[locale]/(before-login)/login/page.tsx` | "계정 만들기" 링크 추가 |
| `src/shared/config/middlewares/withAuthentication.ts` | `/signup`을 공개 경로로 허용 |

**LMS**
| 파일 | 작업 |
|---|---|
| `src/server/db/schema/trainingCourse.ts` 등 | 신규 — 4개 테이블 drizzle 스키마 |
| `src/server/modules/training/` | 신규 모듈 — 코스 목록, 코스 상세, 진도 기록, 완료 상태 조회 |
| `src/server/routers/v1.ts` | `training` 컨트롤러 라우트 등록 |
| `src/app/[locale]/(after-login)/(with-layout)/training/` | 신규 — 코스 목록·상세 라우트 |
| `src/widgets/navigation/side-navigation/side-navigation.tsx` | "교육" 탭 추가 |
| 하단 네비게이션 위젯 | "교육" 탭 추가 |
| 영상 플레이어 컴포넌트 | 신규 — 인라인 플레이어(커스텀 또는 Plyr/react-player). 앞으로 seek 차단(되감기 허용), 네이티브 풀스크린 비활성, `timeupdate`마다 진도 핑 |

**진도 기록 흐름**
- 영상: 플레이어가 `timeupdate` 이벤트에서 주기적으로 `POST /api/v1/training/progress` 호출(item_id, currentTime, duration). 서버가 `watched_sec` 갱신, `currentTime/duration ≥ 0.95`면 `completed_at` 기록.
- 텍스트: "다음" 버튼 → `POST /api/v1/training/progress`가 즉시 `completed_at` 기록.

### 6.3 grape 변경 파일

| 파일 | 작업 |
|---|---|
| `admin/tutor_training/` (신규 디렉터리) | 코스 목록 / 코스 편집(섹션·항목 중첩) 페이지 — `admin/cms/content_*.php` 패턴 |
| `admin/tutor_training/process/` (신규) | 코스·섹션·항목 CRUD 처리 스크립트 |
| `GT_ADMIN_MENU` | 신규 어드민 메뉴 행 INSERT (SQL) |
| 영상 업로드 | 기존 `inc/upload_presigned_for_s3.php` 재사용 |
| 온보딩 URL | 기존 `admin/system/code/` 화면 — 신규 파일 없음, 공통코드 행만 추가 |

### 6.4 권한·라우트 보호
- tutor-web: `/signup`은 공개, `/training`은 `(after-login)` 그룹 — 기존 `withAuthentication`·`verifyAccessToken`이 그대로 보호.
- grape: LMS 어드민 페이지는 `check_admin.php`로 보호 (grape 기존 권한 체계).

---

## 7. 엣지 케이스

| 상황 | 처리 |
|---|---|
| 가입 시 이메일이 이미 `GT_USER`에 존재 (학생 등) | 가입 차단, "이미 사용 중인 이메일" (D3) |
| 가입 직후 `NAME` 빈 값 | 어드민이 검수 시 프로필 채움. 그 전까지 빈 이름 노출 가능 |
| 셸 튜터의 수업 노출 | `CLASS_AVAILABLE=0` — 어드민 검수·오픈 전까지 학생에게 예약 불가 (D4) |
| `TUTOR_TYPE` NULL 상태 | 공지의 TE/TJ 전용 글·인센티브 이벤트 미노출. 어드민이 영어/일본어 지정 시 해결 |
| 필수 코스에 항목 0개 | 빈 코스는 즉시 "완료"로 간주 (완료 판정이 공집합에 대해 참) — 어드민이 빈 필수 코스를 만들지 않도록 안내 |
| 영상을 일부만 보고 이탈 | `watched_sec` 저장 → 다음 방문 시 이어보기 |
| 영상에서 앞으로 건너뛰기 시도 | 미시청 지점으로의 seek는 마지막 시청 위치로 스냅백, 되감기는 허용 (D14) |
| devtools로 `currentTime` 조작·진도 핑 위조 등 의도적 우회 | v1 범위 밖 — 변조 방지는 §9. 내부 튜터 교육 대상이라 캐주얼/실수 스킵 차단으로 충분 |
| 영상 항목 완료 후 재방문 | 잠금 해제 상태로 자유 재시청 (D8) |
| 보충 코스 | 잠금 없음, 진도 기록은 선택 — 온보딩 완료 판정에 미포함 |
| 온보딩 URL 미설정(공통코드 행 없음) | 버튼 숨김 또는 비활성 — 어드민에 설정 안내 |

---

## 8. 성공 기준 / 검증 방법

검증은 수동 (각 환경에서):

1. 튜터가 로그인 페이지에서 이메일+비밀번호로 가입하면 즉시 로그인되고 홈에 진입한다.
2. 가입 시 `GT_USER`와 `GT_TUTOR` 셸 행이 같은 이메일로 생성되고, `CLASS_AVAILABLE=0`이다.
3. 이미 존재하는 이메일로 가입 시 차단된다.
4. grape 어드민에서 코스 > 섹션 > 텍스트·영상 항목을 만들고 필수/보충을 토글할 수 있다.
5. 튜터 웹사이트에 "교육" 탭이 보이고, 필수 코스에서 영상을 95% 미만 시청하면 다음 항목이 잠겨 있다.
6. 영상을 끝까지 보면 다음 항목이 열린다. 텍스트는 "다음" 버튼으로 완료된다.
7. 보충 코스는 잠금 없이 자유 열람된다.
8. 모든 필수 교육 완료 시 교육 페이지에 온보딩 버튼이 노출되고, grape에 설정한 URL로 이동한다.
9. podo-backend는 변경되지 않는다.

---

## 9. 미해결 / 추후 결정 (Decide Later)

- **영상 시청 변조 방지**: v1은 인라인 플레이어에서 앞으로 건너뛰기를 차단(D14)하므로 캐주얼·실수 스킵은 막힌다. 다만 devtools로 `currentTime`을 조작하거나 진도 핑을 위조하는 의도적 우회는 막지 못한다 — 완전한 변조 방지는 서버측 시청 구간 누적 추적이 필요하고 복잡도가 커 후속 과제로 둔다. 내부 튜터 교육 대상이라 v1 수준으로 충분하다고 판단.
- 비밀번호 재설정 / 찾기 흐름.
- 이메일 인증 — 현재 무인증 가입이므로 스팸·오타 계정 발생 가능. 운영 부담이 커지면 도입 검토.
- 가입 폼에서 이름·언어(영어/일본어)를 선택적으로 받을지 — 받으면 빈 프로필 문제 완화.
- LMS 신규 테이블 접두사 컨벤션(`GT_` vs `le_`) — 본 PRD는 `GT_TUTOR_TRAINING_*` 제안.
- 보충 코스 진도 표시 여부.

---

## 부록: 코드 레퍼런스

| 항목 | 위치 |
|---|---|
| 튜터 웹사이트 앱 | `podo-app` `apps/tutor-web` |
| 로그인 로직 | `apps/tutor-web/src/server/modules/auth/service.ts` (`loginByEmail`) |
| 로그인 컨트롤러 | `apps/tutor-web/src/server/modules/auth/controller/login/index.ts` |
| 로그인 폼 | `apps/tutor-web/src/features/auth/ui/login-form/login-form.tsx` |
| 인증 미들웨어 | `apps/tutor-web/src/shared/config/middlewares/withAuthentication.ts` |
| 토큰 검증 미들웨어 | `apps/tutor-web/src/server/middlewares/verifyAccessToken.ts` |
| `GT_TUTOR` / `GT_USER` 스키마 | `apps/tutor-web/src/server/db/schema/tutor.ts`, `user.ts` |
| v1 라우터 | `apps/tutor-web/src/server/routers/v1.ts` |
| 사이드 네비게이션 | `apps/tutor-web/src/widgets/navigation/side-navigation/side-navigation.tsx` |
| 공지(보드) 참고 패턴 | `apps/tutor-web/src/server/modules/boards/service.ts`, `db/schema/board.ts` |
| grape 어드민 튜터 생성 | `grape` `admin/process/teachers_v1_ps.php` |
| grape 콘텐츠 CMS 참고 패턴 | `grape` `admin/cms/content_create.php` · `content_edit.php` · `content_list.php` |
| grape S3 업로드 헬퍼 | `grape` `inc/upload_presigned_for_s3.php`, `inc/upload_for_s3.php` |
| grape 공통코드 시스템 | `grape` `admin/system/code/` (`TB_SYS_CODE` / `TB_SYS_CODE_DETAIL`) |
| grape 어드민 메뉴 등록 | `GT_ADMIN_MENU` 테이블, `admin/sql/*_menu.sql` 참고 |
