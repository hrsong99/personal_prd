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
- 튜터 웹사이트 자체 회원가입 — 이메일+비밀번호+**교육 언어**(영어/일본어 드롭다운, 기본값 없음, 필수 선택).
- 튜터 웹사이트에 **교육(Training)** 신규 탭 — 사이드 네비게이션(데스크톱/태블릿)과 하단 네비게이션(모바일) 양쪽에 추가.
- 교육 코스는 **언어별 분리** — 영어 튜터/일본어 튜터가 각자 자기 언어의 코스만 본다.
- grape 어드민의 LMS 코스 편집 화면 — 코스마다 **아이콘 이미지 업로드**(S3) + 배경색 프리셋 6개 중 선택.
- grape 어드민의 **검수 대기 튜터 필터** — 자체가입한 셸 행을 빠르게 찾기 위한 목록 필터.
- grape 어드민의 **튜터 교육 진도 조회 팝업** — 튜터별 코스·항목 진도 및 완료 시각 표시 (v1 읽기 전용).
- 출시 시점 기존 튜터를 잠금에서 면제하는 **유예(grandfather) 처리**.
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
| D15 | 출시 시점 기존 튜터 | **유예(grandfather)** — `GT_TUTOR`에 `IS_TRAINING_GRANDFATHERED` 컬럼 추가, 출시 시점 모든 기존 튜터 `'Y'` 백필. 완료 판정 시 `'Y'`이면 항상 완료로 간주 | 기존 튜터가 갑자기 잠금된 교육에 노출되지 않도록 |
| D16 | 코스 언어 구분 | **언어별 분리** — `GT_TUTOR_TRAINING_COURSE`에 `tutor_type` 컬럼 추가 (`영어` / `일본어`). 튜터는 자기 `TUTOR_TYPE`에 해당하는 코스만 노출 | 사용자 결정 — 영어/일본어 튜터의 교육 내용이 다름 |
| D17 | 자체가입 신규 튜터 가시화 | grape `admin/podo_teachers_v1.php` 튜터 목록에 **"검수 대기" 필터** 추가 (예: `CLASS_AVAILABLE=0 AND NAME=''` 같은 셸 행 조건). 별도 큐 페이지는 만들지 않음 | 어드민이 셀프 가입 튜터의 온보딩 폼 정보를 보고 검수할 대상을 빠르게 찾도록 |
| D18 | S3 영상 접근 | **공개(public)** — presigned URL 사용 안 함 | 사용자 결정 — 교육 영상은 비공개 자산이 아님 |
| D19 | 가입 시 언어 입력 위치 | **가입 폼 내 드롭다운** (영어/일본어, 기본값 없음, 필수). 이메일·비밀번호·언어를 한 폼에서 받고 제출 시 모두 함께 저장 | D16 때문에 자체가입 튜터가 자기 언어를 알려줘야 교육 시작 가능. 별도 페이지보다 한 화면이 단순 |
| D20 | 가입 직후 랜딩 + 안내 | 가입 완료 → **`/training` 페이지로 이동**. 교육 페이지 상단에 미완료 튜터용 진도 hero 카드(남은 시간 · 진행률 %)와 안내 문구 표시 — "필수 교육 완료 시 온보딩 활성화·어드민 검수 후 수업 시작" | 가입 직후 다음 액션(교육 시작)이 명확히 보이도록. 홈에 떨구면 무엇을 해야 할지 막연 |
| D21 | 온보딩 단계 시각 디자인 | 코스 타일과 **같은 시각 언어**(아이콘·테두리·라운드) + **전체 너비** + **중앙 정렬 강조형**(promoted). 잠금 시: 회색 아이콘, "🔒 필수 교육 완료 후 활성화", 비활성 버튼. 활성 시: 녹색 그라데이션 아이콘, 녹색 강조 테두리, 큰 CTA "온보딩 시작하기 →" | "마지막 결승선" 느낌을 가장 강하게 주면서 그리드의 다른 카드와 시각적으로 통일. 사용자가 변형 3을 선택 |
| D22 | 보충 교육 표시 방식 | **컴팩트 가로 리스트** — 작은 아이콘(32px) + 한 줄(제목 + 시간 + chevron). 필수 코스 그리드와 온보딩 카드보다 시각적 비중 낮춤 | 보충은 선택·자율 학습이므로 시선을 덜 끌게. 진도와 무관 |
| D23 | 코스 아이콘 | **이미지 파일 업로드** (S3 공개 버킷, D18 재사용 — `inc/upload_presigned_for_s3.php`) + **배경색 프리셋 6개**(purple / blue / green / orange / pink / teal). 신규 컬럼 `GT_TUTOR_TRAINING_COURSE.icon_url`, `icon_color` | 어드민이 자유롭게 시각 아이덴티티를 구성하되, 배경색은 프리셋으로 제한해 디자인 일관성 유지 |
| D24 | 어드민 튜터 교육 진도 조회 | 기존 `admin/podo_teachers_v1.php` 튜터 목록에 **"교육 진도" 컬럼**(미니 progress bar) + **"교육 진도 보기" 버튼**. 클릭 시 팝업(`admin/tutor_training/tutor_progress.php?tutor_id=<id>`)으로 코스·항목별 진도, 완료 시각, grandfather 여부 표시. v1은 **읽기 전용** | 어드민이 튜터 검수 시 교육 진도까지 한 화면에서 파악. 직접 수정은 v1 제외 |

---

## 5. 기능 명세

### 5.1 자체 회원가입

**화면 흐름**
1. 로그인 페이지에 "계정 만들기" 링크 추가 → `/signup` 이동.
2. 회원가입 페이지: 이메일, 비밀번호(+비밀번호 확인), **교육 언어 드롭다운**(영어/일본어, 기본값 없음, 필수 선택) 입력. 이름·전화는 받지 않는다.
3. 클라이언트·서버 검증: 언어 미선택 시 제출 차단.
4. 제출 → 서버:
   - `GT_USER`에 동일 이메일 존재 시 → **거부**, "이미 사용 중인 이메일입니다" 메시지 (D3).
   - 트랜잭션으로 `GT_USER`와 `GT_TUTOR` 셸 행을 INSERT — `GT_TUTOR.TUTOR_TYPE`은 가입 폼에서 받은 값(`'영어'` 또는 `'일본어'`).
   - 자동 로그인(토큰 발급) → **`/training` 페이지로 이동** (D20).

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
| `TUTOR_TYPE` | 가입 폼에서 선택한 언어 (`'영어'` 또는 `'일본어'`) (D19) |
| `IS_TRAINING_GRANDFATHERED` | `'N'` — 신규 가입 튜터는 교육 잠금 적용 대상 (D15) |

> ⚠️ 이메일만으로 가입하므로 `NAME`이 빈 값이다. 네비게이션·프로필에 빈 이름이 보일 수 있다 — 어드민이 검수 시 프로필을 채워야 한다.

**미들웨어 변경**: `withAuthentication`(`src/shared/config/middlewares/withAuthentication.ts`)은 현재 `isLoginPage = segments.startsWith('login')` 기준으로 로그인 페이지만 비로그인 공개 경로로 본다. `/signup`도 공개 경로에 포함해야 한다 (토큰 없을 때 `/login`으로 리다이렉트되지 않도록).

### 5.2 교육(LMS) — 튜터 화면

**신규 탭**: 사이드 네비게이션(`side-navigation.tsx`)과 하단 네비게이션 양쪽에 **교육(Training)** 항목 추가, `/training` 라우트.

**코스 목록 화면** (`/training`) — 위에서 아래로 4개 블록 구성:

1. **상단 hero 진도 카드 (D20)** — 미완료 시: "필수 교육 진행 중 · 남은 시간 약 N분 · 진행률 N%"와 진행바. 완료 시: 축하 톤("🎉 필수 교육 완료 · 아래 온보딩만 마치면 끝!"). Grandfather: "자동 완료 처리됨 · 온보딩 자료 준비됨".
2. **필수 교육 — 3-열 카드 그리드** (`is_mandatory='Y'`, `use_yn='Y'`, 튜터 언어 일치 코스, D16). 각 카드: 아이콘(D23), 제목, `필수` 배지 + 예상 시간 + 항목 수, 진행바 + %.
3. **다음 단계 — 온보딩 (D21)** — 코스 타일과 같은 시각 언어, 전체 너비, 중앙 정렬 강조형:
   - **잠금 상태** (미완료): 회색 아이콘 + "🔒 필수 교육 완료 후 활성화" + 비활성 버튼. 카드 옅게(opacity 0.75).
   - **활성 상태** (완료 or grandfather): 녹색 그라데이션 아이콘 + 녹색 테두리/소프트 글로우 + 큰 녹색 CTA "온보딩 시작하기 →".
4. **보충 교육 — 컴팩트 가로 리스트 (D22)** — 한 줄당 작은 아이콘(32px) + 제목 + 시간 + chevron. 필수 그리드보다 작고 muted 톤. 진도 표시 없음(완료 판정 무관).

표시 규칙:
- 튜터의 `TUTOR_TYPE`에 해당하는 코스만 표시 (D16) — 다른 언어 코스는 노출/조회 불가.
- `IS_TRAINING_GRANDFATHERED='Y'` 튜터 (D15): 모든 필수 코스가 자동 완료 상태로 표시, 온보딩이 처음부터 활성, hero는 grandfather 톤. 코스 자체는 자율 학습용으로 자유 열람.

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
- 기능: 코스 생성/수정/삭제, 코스 내 섹션·항목(텍스트/영상) 편집, 순서 지정, **필수/보충 토글**(`is_mandatory`), **언어 지정**(`tutor_type`: 영어/일본어, D16), 코스 노출 여부(`use_yn`).
- **코스 아이콘 (D23)** — 코스 편집 화면에 아이콘 위젯:
  - 좌측: 실시간 미리보기(원형/라운드 사각형, 선택한 배경색 + 업로드한 이미지).
  - "이미지 업로드" 버튼 → `inc/upload_presigned_for_s3.php`로 S3 공개 버킷 업로드(D18) → URL을 `icon_url`에 저장. 권장 사양 64×64 PNG/SVG 투명 배경.
  - 배경색 프리셋 6개(purple/blue/green/orange/pink/teal) 스와치에서 1개 선택 → `icon_color`에 저장.
- **영상 업로드**: `inc/upload_presigned_for_s3.php` → S3(공개 버킷, D18) → 반환된 S3 URL을 `GT_TUTOR_TRAINING_ITEM.video_url`에 저장. presigned URL은 사용하지 않으므로 영상 URL 자체가 영구 공개.
- 신규 어드민 페이지는 `GT_ADMIN_MENU`에 행 1개 INSERT로 메뉴 등록 (§2.3 컨벤션).
- **검수 대기 튜터 필터 (D17)**: `admin/podo_teachers_v1.php` 튜터 목록에 "검수 대기" 필터 옵션 추가. 조건은 셸 행 식별 가능한 신호(`CLASS_AVAILABLE=0` + `NAME=''` 또는 `MEMO='튜터'` 등 — 정확한 조건은 구현 시 기존 어드민-생성 튜터와의 충돌 점검). 어드민은 이 목록에서 셀프 가입 튜터를 보고, 별도 수단(예: 사전 작성된 온보딩 폼)으로 받은 정보로 검수 후 `CLASS_AVAILABLE=1`로 오픈.
- **튜터 교육 진도 컬럼 + 팝업 (D24)**: 같은 `admin/podo_teachers_v1.php`에 "교육 진도" 컬럼 추가 (미니 progress bar + N/M 항목 + 상태 라벨). 행마다 "교육 진도 보기" 버튼 → `window.open('admin/tutor_training/tutor_progress.php?tutor_id=<id>')` 팝업. 팝업 내용:
  - 헤더: 튜터 이름·이메일·언어·검수 상태.
  - 요약: 필수 진도 %, 완료/grandfather 여부, 온보딩 잠금/활성 상태, 예상 남은 시간.
  - 필수 코스별: 코스 아이콘·이름·진도·항목별 완료 시각(또는 진행 중/잠금).
  - 보충 코스: 참고용(완료 판정 무관).
  - v1은 **읽기 전용** — 직접 수정/삭제 액션 없음.

### 5.4 온보딩 버튼

- 완료 판정 `getMandatoryTrainingStatus(tutorId)`:
  - `GT_TUTOR.IS_TRAINING_GRANDFATHERED='Y'` → **즉시 완료** (D15).
  - 아니면: `is_mandatory='Y'` AND `use_yn='Y'` AND **`tutor_type = 해당 튜터의 TUTOR_TYPE`** 인 모든 코스의 모든 항목에 완료 진도 행이 존재하면 "완료" (D16).
- 교육 페이지에서 완료 상태일 때만 온보딩 버튼 노출 (미완료 시 숨김/비활성, D11).
- 버튼 클릭 → `TB_SYS_CODE_DETAIL`에 설정된 온보딩 URL로 이동 (D12).

---

## 6. 기술 설계

### 6.1 DB 변경 (`gwatop` MySQL — grape·tutor-web 공유)

**회원가입 / 유예 처리**:
- 신규 테이블 없음.
- `GT_TUTOR`에 컬럼 1개 추가: `IS_TRAINING_GRANDFATHERED CHAR(1) NOT NULL DEFAULT 'N'` (D15).
- **출시 시 1회성 백필**: `UPDATE GT_TUTOR SET IS_TRAINING_GRANDFATHERED='Y' WHERE ID > 0` (출시 시점 모든 기존 튜터 유예 처리). 출시 이후 신규 가입은 기본값 `'N'`.

**LMS — 신규 테이블 4개:**

```
GT_TUTOR_TRAINING_COURSE
  id            PK
  title         코스명
  tutor_type    '영어' | '일본어'  (해당 언어 튜터에게만 노출, D16)
  is_mandatory  'Y' | 'N'  (필수 / 보충)
  icon_url      VARCHAR(500) NULL  (admin 업로드, S3 공개 URL, D23)
  icon_color    VARCHAR(20) DEFAULT 'green'  ('purple'|'blue'|'green'|'orange'|'pink'|'teal', D23)
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
| `src/server/db/schema/tutor.ts` | `isTrainingGrandfathered` 컬럼 추가 (D15) |

**LMS**
| 파일 | 작업 |
|---|---|
| `src/server/db/schema/trainingCourse.ts` 등 | 신규 — 4개 테이블 drizzle 스키마 (course에 `icon_url`, `icon_color` 포함) |
| `src/server/modules/training/` | 신규 모듈 — 코스 목록(튜터의 `TUTOR_TYPE`으로 필터, D16), 코스 상세, 진도 기록, 완료 상태 조회(grandfather 우선 판정, D15), hero 진도 요약(남은 시간·진행률 계산) |
| `src/server/routers/v1.ts` | `training` 컨트롤러 라우트 등록 |
| `src/app/[locale]/(after-login)/(with-layout)/training/` | 신규 — 코스 목록·상세 라우트. 페이지 구성: hero 카드 → 필수 그리드 → 온보딩 V3 타일(D21) → 보충 컴팩트 리스트(D22) |
| 코스 아이콘 컴포넌트 | 신규 — `icon_url`을 `icon_color` 배경 위에 렌더. 미업로드 시 기본 아이콘(이모지/SVG) 폴백 |
| 온보딩 V3 타일 컴포넌트 | 신규 — 잠금/활성 상태 분기 (D21) |
| 보충 코스 리스트 행 컴포넌트 | 신규 — 컴팩트 가로 행 (D22) |
| `src/widgets/navigation/side-navigation/side-navigation.tsx` | "교육" 탭 추가 |
| 하단 네비게이션 위젯 | "교육" 탭 추가 |
| 영상 플레이어 컴포넌트 | 신규 — 인라인 플레이어(커스텀 또는 Plyr/react-player). 앞으로 seek 차단(되감기 허용), 네이티브 풀스크린 비활성, `timeupdate`마다 진도 핑 |

**진도 기록 흐름**
- 영상: 플레이어가 `timeupdate` 이벤트에서 주기적으로 `POST /api/v1/training/progress` 호출(item_id, currentTime, duration). 서버가 `watched_sec` 갱신, `currentTime/duration ≥ 0.95`면 `completed_at` 기록.
- 텍스트: "다음" 버튼 → `POST /api/v1/training/progress`가 즉시 `completed_at` 기록.

### 6.3 grape 변경 파일

| 파일 | 작업 |
|---|---|
| `admin/tutor_training/course_list.php` (신규) | 코스 목록 (필터·아이콘 미리보기·항목 수·사용 여부) |
| `admin/tutor_training/course_edit.php` (신규) | 코스 편집 — 메타(이름·언어·구분), **아이콘 업로드 위젯 + 배경색 프리셋 6개**(D23), 섹션·항목 중첩 편집 |
| `admin/tutor_training/process/` (신규) | 코스·섹션·항목·아이콘 CRUD 처리 스크립트 |
| `admin/tutor_training/tutor_progress.php` (신규) | **튜터 교육 진도 조회 팝업** (D24) — 읽기 전용. `check_admin.php` + 읽기 커넥션으로 진도 조회·렌더링 |
| `GT_ADMIN_MENU` | 신규 어드민 메뉴 행 INSERT (SQL) — 코스 관리 메뉴만 (진도 팝업은 튜터 목록에서 진입하므로 메뉴 불필요) |
| `admin/podo_teachers_v1.php` | **검수 대기 필터 추가** (D17) + **"교육 진도" 컬럼 + "교육 진도 보기" 버튼 추가** (D24). 컬럼은 미니 progress bar + N/M 항목 표시 |
| 영상·아이콘 업로드 | 기존 `inc/upload_presigned_for_s3.php` 재사용, **공개 버킷에 업로드** (D18) |
| 온보딩 URL | 기존 `admin/system/code/` 화면 — 신규 파일 없음, 공통코드 행만 추가 |
| DDL 마이그레이션 | `GT_TUTOR.IS_TRAINING_GRANDFATHERED` 추가 + 출시 시 백필 SQL (D15); LMS 4개 테이블 생성 (course에 `icon_url`, `icon_color` 포함, D23) |

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
| 가입 시 언어 미선택 | 클라이언트·서버 모두에서 검증, 제출 차단 (D19 — 기본값 없음 필수 선택) |
| 출시 시점 기존 튜터 | `IS_TRAINING_GRANDFATHERED='Y'` 백필 → 잠금 없이 평소대로 사용, 온보딩 버튼 즉시 활성 (D15) |
| 자기 언어와 다른 코스 직접 URL 접근 | 코스 상세 API가 `tutor_type ≠ TUTOR_TYPE`인 코스를 403/404로 차단 (D16) |
| 어드민이 튜터의 `TUTOR_TYPE`을 변경 (영어 → 일본어) | 진도 행(`GT_TUTOR_TRAINING_PROGRESS`)은 그대로 두되, 새 언어의 코스 기준으로 완료 판정이 다시 계산됨. 드문 케이스 — 운영적 처리 |
| 필수 코스에 항목 0개 | 빈 코스는 즉시 "완료"로 간주 (완료 판정이 공집합에 대해 참) — 어드민이 빈 필수 코스를 만들지 않도록 안내 |
| 영상을 일부만 보고 이탈 | `watched_sec` 저장 → 다음 방문 시 이어보기 |
| 영상에서 앞으로 건너뛰기 시도 | 미시청 지점으로의 seek는 마지막 시청 위치로 스냅백, 되감기는 허용 (D14) |
| devtools로 `currentTime` 조작·진도 핑 위조 등 의도적 우회 | v1 범위 밖 — 변조 방지는 §9. 내부 튜터 교육 대상이라 캐주얼/실수 스킵 차단으로 충분 |
| 영상 항목 완료 후 재방문 | 잠금 해제 상태로 자유 재시청 (D8) |
| 보충 코스 | 잠금 없음, 진도 기록은 선택 — 온보딩 완료 판정에 미포함 |
| 온보딩 URL 미설정(공통코드 행 없음) | 버튼 숨김 또는 비활성 — 어드민에 설정 안내 |
| 코스에 아이콘 미업로드 (`icon_url` NULL) | 기본 아이콘(이모지 또는 SVG)으로 폴백. `icon_color` 배경은 그대로 적용 (D23) |
| 어드민이 코스 아이콘 교체 | 신규 S3 URL이 `icon_url`에 저장, 이전 S3 객체는 즉시 삭제하지 않음(고아 객체로 남음 — 정리 정책은 §9) |
| 튜터 진도 팝업 — 진도 데이터 없음 | 모든 코스가 "0% / 시작 안 함"으로 표시. grandfather 튜터는 "자동 완료" 라벨 |
| 튜터 진도 팝업 — `use_yn='N'` 처리된 코스 | 팝업에서는 표시하지 않거나 회색 처리("비노출 코스")로 구분 — 완료 판정에도 미포함 |

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
9. **출시 직후 기존 튜터는 교육 잠금 없이 평소처럼 사용 가능하며 온보딩 버튼도 즉시 활성된다 (D15).**
10. **영어 튜터는 영어 코스만, 일본어 튜터는 일본어 코스만 노출된다 (D16).**
11. **신규 자체가입 튜터가 grape `admin/podo_teachers_v1.php`의 "검수 대기" 필터로 빠르게 검색된다 (D17).**
12. 가입 폼에서 언어를 선택하지 않으면 제출이 차단된다. 선택 후 가입하면 `GT_TUTOR.TUTOR_TYPE`이 즉시 설정되고 교육 탭에 자기 언어 코스가 보인다 (D19).
14. 가입 완료 직후 `/training` 페이지로 자동 이동하고, 상단에 hero 진도 카드(남은 시간·진행률)와 안내 문구가 노출된다. 필수 교육 완료 시 hero는 축하 톤으로 전환되고 온보딩 타일이 잠금→활성으로 바뀐다 (D20·D21).
15. 보충 교육은 필수 그리드보다 작은 컴팩트 가로 리스트로 표시되고, 완료 판정과 무관하게 자유 열람된다 (D22).
16. grape 코스 편집 화면에서 아이콘 이미지를 업로드하면 S3 공개 URL이 저장되고 배경색 프리셋 6개 중 1개를 선택할 수 있다. 튜터 화면에 즉시 반영된다 (D23).
17. grape 튜터 목록의 "교육 진도 보기" 버튼을 클릭하면 팝업으로 해당 튜터의 코스·항목별 진도와 완료 시각이 표시된다. grandfather 튜터는 "자동 완료" 라벨이 표시된다 (D24).
13. podo-backend는 변경되지 않는다.

---

## 9. 미해결 / 추후 결정 (Decide Later)

- **영상 시청 변조 방지**: v1은 인라인 플레이어에서 앞으로 건너뛰기를 차단(D14)하므로 캐주얼·실수 스킵은 막힌다. 다만 devtools로 `currentTime`을 조작하거나 진도 핑을 위조하는 의도적 우회는 막지 못한다 — 완전한 변조 방지는 서버측 시청 구간 누적 추적이 필요하고 복잡도가 커 후속 과제로 둔다. 내부 튜터 교육 대상이라 v1 수준으로 충분하다고 판단.
- 비밀번호 재설정 / 찾기 흐름.
- 이메일 인증 — 현재 무인증 가입이므로 스팸·오타 계정 발생 가능. 운영 부담이 커지면 도입 검토.
- 가입 폼에서 이름·전화 등을 선택적으로 받을지 — 받으면 빈 프로필 문제 완화.
- LMS 신규 테이블 접두사 컨벤션(`GT_` vs `le_`) — 본 PRD는 `GT_TUTOR_TRAINING_*` 제안.
- 보충 코스 진도 표시 여부.
- 비밀번호 최소 길이·복잡도 규칙, 로그인 시 이메일 대소문자 정규화 — 구현 시 결정.
- 어드민의 "검수 대기" 필터 정확한 조건 — `CLASS_AVAILABLE=0` + `NAME=''` 단순 조합으로 충분한지, 별도 표지 컬럼(예: `SIGNUP_SOURCE='SELF'`)이 필요한지 구현 시 결정 (어드민-생성 튜터와 충돌 여부 점검).
- grandfather 영구성 — 유예된 튜터는 출시 후 추가되는 신규 필수 코스도 자동 완료로 간주된다. 만약 신규 필수 교육이 추가될 때 기존 튜터도 다시 받게 하려면 별도 메커니즘(예: 코스에 `cutover_date`를 두고 그 이후 가입한 튜터에게만 적용) 필요.
- DDL 검증 — `GT_TUTOR`/`GT_USER`의 실제 DDL이 drizzle 스키마(타입 선언)와 일치하는지 마이그레이션 작성 전에 라이브 DB에서 확인.
- 코스 아이콘 S3 고아 객체 — 아이콘 교체/코스 삭제 시 이전 S3 객체는 즉시 삭제하지 않는다. 주기적 정리 잡(예: 미참조 객체 N일 후 삭제)은 운영 부담 정도에 따라 추후 도입.
- 튜터 교육 진도 어드민 수정 — v1은 읽기 전용. 운영적으로 진도 행을 직접 추가/삭제할 필요가 자주 발생하면, 팝업에 "이 항목 완료 처리"·"진도 초기화" 버튼을 추가(grape 직접 DB 쓰기, penalty-skip-admin 패턴) 검토.
- 코스 아이콘 라이브러리 — 업로드 외에 사내 아이콘 세트(SVG 라이브러리)에서 선택하는 옵션을 추후 추가 가능.

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
| grape 어드민 팝업 패턴 (참고용) | `personal_prd/penalty-skip-admin/penalty-skip-admin-prd.md` — 튜터 목록 버튼 → `window.open(...)` 팝업 페이지로 진도/이력 표시하는 같은 패턴 |
| 화면 목업 | `personal_prd/tutor-web-signup-lms/mockups.html` (12개 화면), `training-page-options.html` (교육 페이지 디자인 옵션 3개), `onboarding-tile-variations.html` (온보딩 타일 변형 3종 — 변형 3 채택) |
