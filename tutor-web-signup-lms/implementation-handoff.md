# 구현 핸드오프 — Tutor Web Signup + Training LMS + Onboarding Gate

*작성일: 2026-05-26 · 출처: `.ouroboros/seed.yaml` (QA 0.81, below-threshold 수용)*
*입력 PRD: `tutor-web-signup-lms-prd.md` · PM seed: `.ouroboros/pm.md`*

이 문서는 자동 실행(`ooo run`) 대신 **개발자 또는 후속 자동화가 단계별로 집행할 수 있는** 구현 명세입니다.
각 작업은 (1) 변경 대상 파일·경로 (2) 핵심 로직 요약 (3) Acceptance ID 참조를 포함합니다.

---

## 0. 개요 — 작업 트랙

| 트랙 | 영역 | 변경 영향 | 사전 의존 |
|---|---|---|---|
| Phase 0 | 사전 감사 (코드 변경 없음) | 보고서 산출 | — |
| Migration | gwatop MySQL DDL + 백필 | 운영 DB | Phase 0 완료 |
| Track A | grape PHP 어드민 | grape 레포 | Migration 완료 |
| Track B | tutor-web (Next.js) | podo-app 레포 | Migration 완료, Track A는 병렬 가능 |
| Track C (조건부) | podo-backend 패치 | podo-backend 레포 | Phase 0 결과가 누락 발견 시만 |
| QA | 단위 테스트 + 17 수동 시나리오 | CI | Track A·B·C 코드 완료 |

**배포 순서**: Phase 0 → Migration SQL (운영 DB) → grape 배포 → tutor-web 배포 → 검증.

---

## 1. Phase 0 — 사전 감사 (구현 착수 전 필수)

산출물: `.ouroboros/phase-0-audit.md` (또는 PRD §10 신규 부록)

### 1.1 podo-backend 학생향 튜터 조회의 `CLASS_AVAILABLE=1` 필터 적용 여부

레포: `/Users/johnsong/podo-backend`

조사 대상 (모두 학생이 튜터 정보를 조회하는 경로):
- 튜터 목록 / 검색 API
- 예약 가능 슬롯 API
- 튜터 프로필 단건 조회 API
- 추천 튜터 API
- 매칭 / 자동 배정 로직

조사 명령 (예시):
```bash
cd /Users/johnsong/podo-backend
rg -n "GT_TUTOR" --type ts --type java --type kt --glob '!**/test/**'
rg -n "FROM\s+GT_TUTOR" --type ts --type java --type kt
rg -n "class_available|CLASS_AVAILABLE" -i
```

각 결과 행을 (경로, 라인, 쿼리 요약, `CLASS_AVAILABLE=1` 필터 존재 여부) 4열 표로 기록.

누락 발견 시 → Track C 패치 PR 작성 (단순 `WHERE CLASS_AVAILABLE=1` 절 추가만, 그 외 변경 금지).

### 1.2 GT_TUTOR DDL ↔ drizzle 스키마 일치 검증

레포: `/Users/johnsong/podo-app/apps/tutor-web/src/server/db/schema/tutor.ts`
DB: gwatop production replica 또는 stage

조사 명령:
```sql
-- 라이브 DB
SHOW CREATE TABLE GT_TUTOR;
-- + SELECT column_name, is_nullable, column_default, data_type
-- FROM information_schema.columns WHERE table_name='GT_TUTOR';
```

drizzle 스키마의 컬럼 정의를 한 줄씩 대조. 특히 NOT NULL 컬럼 중 drizzle에서 누락된 것이 있으면, seed의 GT_TUTOR 셸 INSERT가 컬럼 누락으로 실패할 수 있음.

### 1.3 `TUTOR_TYPE` 값 분포

```sql
SELECT TUTOR_TYPE, COUNT(*)
FROM GT_TUTOR
GROUP BY TUTOR_TYPE
ORDER BY COUNT(*) DESC;
```

기대 결과: `'영어'` / `'일본어'` 두 값만. 다른 값(`'ENGLISH'`, NULL, 빈 문자열, 'Chinese' 등)이 보이면 매핑 규칙 또는 정리 SQL 동반.

### 1.4 `GT_USER.EMAIL` collation과 lowercase 정규화 호환성

```sql
SHOW FULL COLUMNS FROM GT_USER LIKE 'EMAIL';
-- collation 컬럼 확인 (예: utf8mb4_unicode_ci 또는 latin1_swedish_ci)
SELECT COUNT(*) FROM GT_USER WHERE EMAIL <> LOWER(EMAIL);
-- 결과 > 0이면 기존 데이터에 대소문자 혼재
```

대소문자 혼재가 있으면 가입 폼의 lowercase 정규화가 기존 사용자와 충돌 가능 → 마이그레이션 시 `UPDATE GT_USER SET EMAIL = LOWER(EMAIL)` 실행 여부 결정.

### 1.5 산출물 템플릿

```markdown
# Phase 0 Audit — tutor-web-signup-lms

## 1.1 podo-backend CLASS_AVAILABLE filter
| 경로 | 라인 | 쿼리 요약 | CLASS_AVAILABLE=1 적용 | 조치 |
| ... |

## 1.2 GT_TUTOR DDL ↔ drizzle 일치
- 누락 컬럼: ...
- 타입 불일치: ...

## 1.3 TUTOR_TYPE 값 분포
- '영어': N rows
- '일본어': N rows
- 기타: ... (정리 SQL or 매핑 결정)

## 1.4 EMAIL collation
- collation: ...
- 대소문자 혼재 행: N (정리 SQL 결정)

## Phase 0 종료 게이트
- [ ] 1.1 결과 기록 + 누락 패치 PR 링크 (있는 경우)
- [ ] 1.2 일치 확인 또는 drizzle 스키마 수정 PR 링크
- [ ] 1.3 결과 기록 + 이상치 처리 결정
- [ ] 1.4 결과 기록 + 정리 SQL 결정 (있는 경우)
```

---

## 2. Migration — gwatop DDL + 백필

실행 도구: grape SQL 마이그레이션 트랙 (drizzle-kit 미사용).
파일 위치: `grape/admin/sql/<YYYYMMDD>_tutor_training.sql` (관행에 맞게 명명).

### 2.1 GT_TUTOR 컬럼 추가 + grandfather 백필

```sql
-- 2 컬럼 추가
ALTER TABLE GT_TUTOR
  ADD COLUMN IS_TRAINING_GRANDFATHERED CHAR(1) NOT NULL DEFAULT 'N',
  ADD COLUMN IS_TRAINING_DONE          CHAR(1) NOT NULL DEFAULT 'N';

-- 출시 시점 1회성 grandfather 백필 — 모든 기존 행
UPDATE GT_TUTOR SET IS_TRAINING_GRANDFATHERED = 'Y';
-- (DEFAULT 'N'이 적용된 신규 가입자는 자동으로 'N')
```

> ⚠️ 백필 UPDATE는 모든 행을 한번에 갱신. 큰 테이블(수십만+ 행)이면 chunked update 또는 점진 배포 고려.

### 2.2 신규 4개 테이블

```sql
CREATE TABLE le_tutor_training_course (
  id           BIGINT NOT NULL AUTO_INCREMENT,
  title        VARCHAR(255) NOT NULL,
  tutor_type   ENUM('영어','일본어') NOT NULL,
  is_mandatory CHAR(1)  NOT NULL DEFAULT 'N',
  icon_url     VARCHAR(500) NULL,
  icon_color   VARCHAR(20)  NOT NULL DEFAULT 'green',
  order_no     INT NOT NULL DEFAULT 0,
  use_yn       CHAR(1)  NOT NULL DEFAULT 'Y',
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_course_listing (tutor_type, use_yn, is_mandatory, order_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE le_tutor_training_section (
  id        BIGINT NOT NULL AUTO_INCREMENT,
  course_id BIGINT NOT NULL,
  title     VARCHAR(255) NOT NULL,
  order_no  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_section_course (course_id, order_no),
  CONSTRAINT fk_section_course FOREIGN KEY (course_id)
    REFERENCES le_tutor_training_course (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE le_tutor_training_item (
  id                 BIGINT NOT NULL AUTO_INCREMENT,
  section_id         BIGINT NOT NULL,
  type               ENUM('TEXT','VIDEO') NOT NULL,
  order_no           INT NOT NULL DEFAULT 0,
  text_body          TEXT NULL,
  video_url          VARCHAR(500) NULL,
  video_duration_sec INT NULL,
  PRIMARY KEY (id),
  KEY idx_item_section (section_id, order_no),
  CONSTRAINT fk_item_section FOREIGN KEY (section_id)
    REFERENCES le_tutor_training_section (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE le_tutor_training_progress (
  id           BIGINT NOT NULL AUTO_INCREMENT,
  tutor_id     BIGINT NOT NULL,
  item_id      BIGINT NOT NULL,
  completed_at DATETIME NULL,
  watched_sec  INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uk_progress (tutor_id, item_id),
  KEY idx_progress_tutor_completed (tutor_id, completed_at),
  CONSTRAINT fk_progress_item FOREIGN KEY (item_id)
    REFERENCES le_tutor_training_item (id) ON DELETE CASCADE
  -- 주의: GT_TUTOR ↔ FK는 GT_TUTOR.id 명세를 Phase 0에서 확인 후 추가
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

> 💡 `le_tutor_training_progress → GT_TUTOR` FK는 Phase 0에서 GT_TUTOR의 PK 컬럼 이름·타입(ID vs id, BIGINT vs INT)을 확인한 뒤 추가.

### 2.3 온보딩 URL 공통코드

```sql
-- 부모 그룹 (있으면 생략)
INSERT INTO TB_SYS_CODE (group_code, group_name, use_yn)
VALUES ('TUTOR_TRAINING', '튜터 교육/온보딩 설정', 'Y')
ON DUPLICATE KEY UPDATE group_name = VALUES(group_name);

-- 자식 2행 — value는 실제 외부 폼 URL로 어드민이 편집
INSERT INTO TB_SYS_CODE_DETAIL (group_code, detail_code, value, use_yn)
VALUES
  ('TUTOR_TRAINING', 'ONBOARDING_URL_EN', '<영어 튜터 온보딩 폼 URL>', 'Y'),
  ('TUTOR_TRAINING', 'ONBOARDING_URL_JP', '<일본어 튜터 온보딩 폼 URL>', 'Y');
```

### 2.4 GT_ADMIN_MENU 어드민 메뉴 등록

```sql
-- 정확한 컬럼은 GT_ADMIN_MENU 기존 행 1~2개를 SELECT * 해서 동일 형식으로 INSERT
-- (보통: menu_id, parent_id, menu_name, menu_url, order_no, use_yn 등)
INSERT INTO GT_ADMIN_MENU (parent_id, menu_name, menu_url, order_no, use_yn)
VALUES (
  <튜터 관리 상위 메뉴 id>,
  '코스 관리',
  'tutor_training/course_list.php',
  <적절한 order_no>,
  'Y'
);
```

### 2.5 롤백 계획

```sql
-- 신규 테이블만 제거 (CASCADE FK로 자식 자동 정리)
DROP TABLE IF EXISTS le_tutor_training_progress;
DROP TABLE IF EXISTS le_tutor_training_item;
DROP TABLE IF EXISTS le_tutor_training_section;
DROP TABLE IF EXISTS le_tutor_training_course;
-- GT_TUTOR 컬럼 제거 (운영 영향 큼, 신중)
ALTER TABLE GT_TUTOR
  DROP COLUMN IS_TRAINING_DONE,
  DROP COLUMN IS_TRAINING_GRANDFATHERED;
-- 공통코드 제거
DELETE FROM TB_SYS_CODE_DETAIL WHERE group_code='TUTOR_TRAINING';
DELETE FROM TB_SYS_CODE WHERE group_code='TUTOR_TRAINING';
-- 어드민 메뉴 제거
DELETE FROM GT_ADMIN_MENU WHERE menu_url='tutor_training/course_list.php';
```

---

## 3. Track A — grape PHP 어드민

레포: `/Users/johnsong/grape`

### 3.1 신규 페이지

| 파일 | 역할 | 참고 패턴 |
|---|---|---|
| `admin/tutor_training/course_list.php` | 코스 목록 (필터·아이콘 미리보기·항목 수·use_yn) | `admin/cms/content_list.php` |
| `admin/tutor_training/course_edit.php` | 코스 편집 (메타·아이콘 위젯·6색 프리셋·섹션·아이템 중첩) | `admin/cms/content_edit.php` |
| `admin/tutor_training/process/course_save.php` | 코스 CRUD 처리 | `admin/cms/content_process.php` |
| `admin/tutor_training/process/section_save.php` | 섹션 CRUD | 동일 |
| `admin/tutor_training/process/item_save.php` | 아이템 CRUD | 동일 |
| `admin/tutor_training/process/icon_upload.php` | 아이콘 업로드 (inc/upload_presigned_for_s3.php 호출) | `admin/cms/file_upload.php` 등 |
| `admin/tutor_training/tutor_progress.php` | **읽기 전용** 진도 팝업 | `personal_prd/penalty-skip-admin/penalty-skip-admin-prd.md` 패턴 |

각 페이지 첫 줄: `require_once '../check_admin.php';` (기존 어드민 인증).

#### 3.1.1 course_edit.php 핵심 UI 요구사항 (AC29, AC30)

- 코스 메타 입력: title, tutor_type 드롭다운('영어'|'일본어'), is_mandatory 토글, use_yn 토글, order_no
- **아이콘 위젯** (AC30):
  - 좌측 미리보기 (원형/라운드 사각형, 선택 색 + 업로드 이미지)
  - "이미지 업로드" 버튼 → `process/icon_upload.php` → `icon_url`
  - 색 프리셋 6개 스와치 (purple/blue/green/orange/pink/teal, hex는 디자인 토큰 위임) → `icon_color`
- is_mandatory 토글 변경 시 confirm dialog: "진행 중 튜터의 잠금 체인이 변경될 수 있습니다. 계속하시겠습니까?"
- 섹션·아이템 중첩 편집 (드래그&드롭 또는 order_no 직접 입력)
- 아이템 type=VIDEO 행은 video_url(S3 업로드) + video_duration_sec(자동 추출 or 수동 입력)
- 아이템 type=TEXT 행은 text_body (TEXT, WYSIWYG 또는 plain textarea)

#### 3.1.2 tutor_progress.php 출력 (AC32)

조회 SQL (읽기 커넥션):
```sql
SELECT
  t.id, t.NAME, t.EMAIL, t.TUTOR_TYPE,
  t.CLASS_AVAILABLE, t.IS_TRAINING_GRANDFATHERED, t.IS_TRAINING_DONE
FROM GT_TUTOR t
WHERE t.id = :tutor_id;

-- 필수 코스 + 항목 + 진도
SELECT
  c.id course_id, c.title course_title, c.icon_url, c.icon_color, c.is_mandatory,
  s.id section_id, s.title section_title, s.order_no section_order,
  i.id item_id, i.type, i.order_no item_order,
  p.completed_at, p.watched_sec
FROM le_tutor_training_course c
JOIN le_tutor_training_section s ON s.course_id = c.id
JOIN le_tutor_training_item    i ON i.section_id = s.id
LEFT JOIN le_tutor_training_progress p
  ON p.tutor_id = :tutor_id AND p.item_id = i.id
WHERE c.use_yn='Y' AND c.tutor_type = (SELECT TUTOR_TYPE FROM GT_TUTOR WHERE id=:tutor_id)
ORDER BY c.is_mandatory DESC, c.order_no, s.order_no, i.order_no;
```

렌더링: 헤더(이름·이메일·언어·검수 상태) · 요약(필수 진도 %·완료/grandfather·온보딩 상태·예상 남은 시간) · 필수 코스별 아이템 진도 + completed_at · 보충 코스 참고.

grandfather 튜터는 모든 항목 옆에 "자동 완료 (grandfather)" 라벨.

### 3.2 수정 페이지

| 파일 | 변경 | AC |
|---|---|---|
| `admin/podo_teachers_v1.php` | "검수 대기" 필터 옵션 (라디오 또는 드롭다운) + WHERE 절 분기 (`CLASS_AVAILABLE=0 AND (IS_TRAINING_DONE='Y' OR IS_TRAINING_GRANDFATHERED='Y')`) | AC31 |
| 동일 | 튜터 목록 행에 "교육 진도" 컬럼 추가 (미니 progress bar + N/M 항목) | AC31 |
| 동일 | 행마다 "교육 진도 보기" 버튼 → `window.open` 으로 `admin/tutor_training/tutor_progress.php?tutor_id=<id>` | AC32 |

진도 컬럼 계산용 서브쿼리 (성능 주의):
```sql
SELECT
  (SELECT COUNT(*) FROM le_tutor_training_item i
     JOIN le_tutor_training_section s ON s.id=i.section_id
     JOIN le_tutor_training_course c ON c.id=s.course_id
   WHERE c.use_yn='Y' AND c.is_mandatory='Y' AND c.tutor_type=t.TUTOR_TYPE) AS total_mandatory_items,
  (SELECT COUNT(*) FROM le_tutor_training_progress p
     JOIN le_tutor_training_item i ON i.id=p.item_id
     JOIN le_tutor_training_section s ON s.id=i.section_id
     JOIN le_tutor_training_course c ON c.id=s.course_id
   WHERE p.tutor_id=t.id AND p.completed_at IS NOT NULL
     AND c.use_yn='Y' AND c.is_mandatory='Y' AND c.tutor_type=t.TUTOR_TYPE) AS done_items
FROM GT_TUTOR t
WHERE ...;
```

→ 튜터 목록이 페이지네이션 적용 중이면 OK. 전체 조회면 큰 비용. 검수 대기 필터 결과는 보통 작은 집합.

### 3.3 영상 업로드

`admin/tutor_training/process/item_save.php`에서 type=VIDEO 아이템 저장 시 영상 파일 인풋이 있으면 `inc/upload_presigned_for_s3.php` 호출 → S3 public-read URL을 `video_url` 컬럼에 저장.

`video_duration_sec`는 클라이언트가 `<video>` 메타데이터에서 추출해 전송하거나 어드민이 수동 입력. 95% 판정에 필수.

---

## 4. Track B — tutor-web (Next.js + Hono + drizzle)

레포: `/Users/johnsong/podo-app`, 앱: `apps/tutor-web`

### 4.1 drizzle 스키마

| 파일 | 변경 | AC |
|---|---|---|
| `src/server/db/schema/tutor.ts` | `isTrainingGrandfathered`, `isTrainingDone` 컬럼 추가 (CHAR(1) NOT NULL DEFAULT 'N') | AC03, AC07, AC23 |
| `src/server/db/schema/trainingCourse.ts` | 신규 — le_tutor_training_course drizzle 정의 | AC28 |
| `src/server/db/schema/trainingSection.ts` | 신규 | AC28 |
| `src/server/db/schema/trainingItem.ts` | 신규 | AC28 |
| `src/server/db/schema/trainingProgress.ts` | 신규 | AC28 |
| `src/server/db/schema/index.ts` | 신규 4 스키마 re-export | — |

### 4.2 회원가입 (Track B-1)

| 파일 | 작업 | AC |
|---|---|---|
| `src/app/[locale]/(before-login)/signup/page.tsx` | 신규 — 회원가입 페이지 (`login` 페이지 미러) | AC01 |
| `src/features/auth/ui/signup-form/signup-form.tsx` | 신규 — 폼 컴포넌트, email/password/password_confirm/tutor_type 필드 | AC01, AC04 |
| `src/features/auth/api/signup-action.ts` | 신규 — 서버 액션 (`'use server'`), submit 시 API 호출 + `redirect()` | AC05 |
| `src/server/modules/auth/controller/signup/index.ts` | 신규 — Hono 라우트 `POST /api/v1/auth/signup` | AC01 |
| `src/server/modules/auth/service.ts` | 신규 메소드 `signUp(input)` — 이메일 중복 검사 + drizzle 트랜잭션 INSERT + 토큰 발급 + `evaluateTrainingDoneLatch()` | AC01–AC04, AC07 |
| `src/server/modules/auth/dto/signupRequest.dto.ts` / `signupResponse.dto.ts` | 신규 — zod 스키마 (8자 이상 + 비밀번호 일치 + tutor_type 필수) | AC01 |
| `src/app/[locale]/(before-login)/login/page.tsx` | 기존 — "계정 만들기" 링크 추가 (→ `/[locale]/signup`) | — |
| `src/shared/config/middlewares/withAuthentication.ts` | 기존 — `isLoginPage` 또는 신규 `isPublicPath` 로직에 `/signup` 추가 | AC06 |
| `src/shared/config/i18n/messages/{ko,ja,en}.json` (기존 메시지 파일 위치 확인) | 신규 키 — 가입 폼 라벨·에러·성공·중복 메시지 ko/ja/en 모두 | AC36 |

#### 4.2.1 signUp 핵심 로직 (의사 코드)

```typescript
async signUp({ email, password, passwordConfirm, tutorType }: SignUpDTO) {
  // 검증
  if (password.length < 8) throw new ValidationError('PASSWORD_TOO_SHORT')
  if (password !== passwordConfirm) throw new ValidationError('PASSWORD_MISMATCH')
  if (!['영어', '일본어'].includes(tutorType)) throw new ValidationError('INVALID_TUTOR_TYPE')

  const normalizedEmail = email.trim().toLowerCase()

  // 중복 검사
  const existing = await db.select().from(gtUser).where(eq(gtUser.email, normalizedEmail)).limit(1)
  if (existing.length > 0) throw new ConflictError('EMAIL_ALREADY_EXISTS')

  // 트랜잭션 INSERT
  await db.transaction(async (tx) => {
    await tx.insert(gtUser).values({
      email: normalizedEmail,
      userPw: sha1(password),
      name: '',
      classType: 'PODO',
      memo: '튜터',
    })

    const [tutorRow] = await tx.insert(gtTutor).values({
      email: normalizedEmail,
      name: '', phone: '', sex: 0,
      hopeCity: '', levTeacher: '', classSubtitle: '',
      classLevel: '', teacherCareer: '', classIntro: '',
      createDate: sql`SYSDATE()`,
      classAvailable: 0,
      classType: 'PODO',
      tutorType,
      isTrainingGrandfathered: 'N',
      isTrainingDone: 'N',
    }).$returningId() // (drizzle MySQL 패턴 따라 조정)
  })

  // 셸 튜터 id 조회 (returningId 미지원 시 SELECT)
  const tutor = await db.select().from(gtTutor).where(eq(gtTutor.email, normalizedEmail)).limit(1).then(r => r[0])

  // 빈 공집합 방어 래치 (트랜잭션 외부)
  await evaluateTrainingDoneLatch(tutor.id)

  // 토큰 발급 (기존 헬퍼 재사용)
  const tokens = await issueTokens({ tutorId: tutor.id, email: tutor.email })

  return { tutorId: tutor.id, tutorType, tokens }
}
```

서버 액션에서 redirect:
```typescript
'use server'
export async function signupAction(formData: FormData) {
  const result = await callSignupApi(formData)
  if (!result.ok) return { error: result.message }
  // tutor_type별 locale 분기
  const locale = result.tutorType === '영어' ? 'en' : 'ja'
  redirect(`/${locale === 'en' ? 'en' : 'jp'}/training`) // LOCALE_PREFIXES 매핑
}
```

### 4.3 LMS (Track B-2)

| 파일 | 작업 | AC |
|---|---|---|
| `src/server/modules/training/service.ts` | 신규 — `listCourses`, `getCourse`, `getHeroProgress`, `recordHeartbeat`, `completeItem`, `evaluateTrainingDoneLatch`, `getOnboardingUrl` | AC07–AC14, AC19, AC20, AC22, AC23, AC25 |
| `src/server/modules/training/controller/list/index.ts` | 신규 — `GET /api/v1/training/courses` (튜터 언어로 필터) | AC09 |
| `src/server/modules/training/controller/detail/index.ts` | 신규 — `GET /api/v1/training/courses/:courseId` (tutor_type 매칭 가드, 미스매치 시 403/404) | AC09 |
| `src/server/modules/training/controller/progress/patch.ts` | 신규 — `PATCH /api/v1/training/items/:itemId/progress` (watched_sec max upsert) | AC19 |
| `src/server/modules/training/controller/complete/post.ts` | 신규 — `POST /api/v1/training/items/:itemId/complete` (잠금 검증 + completed_at + 래치) | AC20 |
| `src/server/modules/training/controller/onboarding-url/get.ts` | 신규 — `GET /api/v1/training/onboarding-url` | AC25, AC26 |
| `src/server/modules/training/dto/*` | 신규 — request/response 스키마 | — |
| `src/server/routers/v1.ts` | 기존 — training 컨트롤러 라우트 등록 | — |
| `src/app/[locale]/(after-login)/(with-layout)/training/page.tsx` | 신규 — 코스 목록 화면 (4-블록 구조) | AC08 |
| `src/app/[locale]/(after-login)/(with-layout)/training/[courseId]/page.tsx` | 신규 — 코스 상세/학습 화면 | AC10–AC18 |
| `src/features/training/ui/hero-progress-card.tsx` | 신규 — 진도 hero 카드 (미완료·완료·grandfather 톤) | AC08 |
| `src/features/training/ui/course-card.tsx` | 신규 — 필수 코스 카드 (아이콘+제목+배지+시간+진행바) | AC08 |
| `src/features/training/ui/onboarding-tile.tsx` | 신규 — V3 타일 (잠금/활성 분기) | AC24 |
| `src/features/training/ui/supplementary-row.tsx` | 신규 — 보충 컴팩트 가로 행 | AC08 |
| `src/features/training/ui/course-icon.tsx` | 신규 — icon_color 배경 + icon_url 이미지 (없으면 폴백 이모지/SVG) | — |
| `src/features/training/ui/video-player/video-player.tsx` | 신규 — 커스텀 React 플레이어 (`<video>` + 자체 컨트롤) | AC14–AC18, AC21 |
| `src/features/training/ui/text-item.tsx` | 신규 — 텍스트 본문 + "다음" 버튼 | AC13 |
| `src/widgets/navigation/side-navigation/side-navigation.tsx` | 기존 — "교육" 탭 추가 (라벨 키 ko/ja/en) | AC34 |
| `src/widgets/navigation/bottom-navigation/*` (실제 경로 확인) | 기존 — "교육" 탭 추가 | AC34 |
| `src/shared/config/i18n/messages/{ko,ja,en}.json` | 신규 키 — training 도메인 전체 (hero·코스 카드·온보딩 CTA·보충·에러 등) | AC36 |

#### 4.3.1 영상 플레이어 핵심 구현 (AC14–AC18, AC21)

```typescript
// video-player.tsx (요지)
function VideoPlayer({ src, initialWatchedSec, durationSec, isCompleted, itemId }) {
  const ref = useRef<HTMLVideoElement>(null)
  const watchedSecRef = useRef(initialWatchedSec)
  const completedRef = useRef(isCompleted)

  // mount: 초기 위치
  useEffect(() => {
    if (ref.current) ref.current.currentTime = watchedSecRef.current
  }, [])

  // playbackRate 강제 1
  useEffect(() => {
    if (!ref.current) return
    const v = ref.current
    const enforce = () => { if (v.playbackRate !== 1) v.playbackRate = 1 }
    v.addEventListener('ratechange', enforce)
    return () => v.removeEventListener('ratechange', enforce)
  }, [])

  // seek 가드
  const onSeeking = (e) => {
    if (completedRef.current) return
    const v = e.currentTarget
    if (v.currentTime > watchedSecRef.current + 1) {
      v.currentTime = watchedSecRef.current
    }
  }

  // timeupdate: HWM 갱신 + 95% 완료
  const onTimeUpdate = (e) => {
    const v = e.currentTarget
    watchedSecRef.current = Math.max(watchedSecRef.current, v.currentTime)
    if (!completedRef.current && v.currentTime / v.duration >= 0.95) {
      completedRef.current = true
      api.complete(itemId).catch(/* 재시도 */)
    }
  }

  // heartbeat 5초
  useEffect(() => {
    const interval = setInterval(() => {
      if (!ref.current?.paused) {
        api.patchProgress(itemId, watchedSecRef.current)
      }
    }, 5000)
    const onPause = () => api.patchProgress(itemId, watchedSecRef.current)
    const onVisChange = () => { if (document.hidden) api.patchProgress(itemId, watchedSecRef.current) }
    const onBeforeUnload = () => {
      navigator.sendBeacon(`/api/v1/training/items/${itemId}/progress`,
        new Blob([JSON.stringify({ watched_sec: watchedSecRef.current })], { type: 'application/json' }))
    }
    ref.current?.addEventListener('pause', onPause)
    document.addEventListener('visibilitychange', onVisChange)
    window.addEventListener('beforeunload', onBeforeUnload)
    window.addEventListener('pagehide', onBeforeUnload)
    return () => {
      clearInterval(interval)
      ref.current?.removeEventListener('pause', onPause)
      document.removeEventListener('visibilitychange', onVisChange)
      window.removeEventListener('beforeunload', onBeforeUnload)
      window.removeEventListener('pagehide', onBeforeUnload)
    }
  }, [itemId])

  return (
    <video
      ref={ref}
      src={src}
      playsInline                  /* webkit-playsinline 효과 */
      controlsList="nodownload noremoteplayback noplaybackrate"
      onSeeking={onSeeking}
      onTimeUpdate={onTimeUpdate}
    />
    /* 자체 재생/일시정지·진행바·볼륨 컨트롤은 별도 컴포넌트로 오버레이 */
  )
}
```

#### 4.3.2 evaluateTrainingDoneLatch (AC23)

```typescript
async function evaluateTrainingDoneLatch(tutorId: number): Promise<void> {
  const tutor = await db.select({ tutorType, isTrainingGrandfathered, isTrainingDone })
    .from(gtTutor).where(eq(gtTutor.id, tutorId)).limit(1).then(r => r[0])
  if (!tutor) return
  if (tutor.isTrainingGrandfathered === 'Y') return         // (a) no-op
  if (tutor.isTrainingDone === 'Y') return                  // (c) no-op

  // (b) 모든 필수 아이템 완료 여부
  const [{ pending }] = await db.execute(sql`
    SELECT COUNT(*) AS pending
    FROM le_tutor_training_item i
      JOIN le_tutor_training_section s ON s.id = i.section_id
      JOIN le_tutor_training_course c ON c.id = s.course_id
      LEFT JOIN le_tutor_training_progress p
        ON p.tutor_id = ${tutorId} AND p.item_id = i.id AND p.completed_at IS NOT NULL
    WHERE c.use_yn = 'Y' AND c.is_mandatory = 'Y' AND c.tutor_type = ${tutor.tutorType}
      AND p.id IS NULL
  `)
  if (Number(pending) === 0) {
    await db.update(gtTutor).set({ isTrainingDone: 'Y' }).where(eq(gtTutor.id, tutorId))
  }
}
```

호출 지점 3곳:
1. `signUp` 직후 (AC07)
2. `completeItem` 안 (POST /complete, AC20)
3. `/training` GET 핸들러 안 (AC22, IS_TRAINING_DONE='N' AND IS_TRAINING_GRANDFATHERED='N' 튜터에만)

#### 4.3.3 잠금 체인 검증 (AC10, AC20)

`POST /complete` 핸들러는 아이템 itemId가 현재 튜터에게 "열려있는지"를 검증:

```sql
-- 해당 아이템과 그 직전까지의 모든 아이템 조회
WITH ordered AS (
  SELECT i.id, c.use_yn, c.is_mandatory, c.tutor_type,
         ROW_NUMBER() OVER (PARTITION BY c.id ORDER BY s.order_no, i.order_no) AS rn
  FROM le_tutor_training_item i
    JOIN le_tutor_training_section s ON s.id = i.section_id
    JOIN le_tutor_training_course c ON c.id = s.course_id
  WHERE c.id = (SELECT s2.course_id FROM le_tutor_training_section s2
                  JOIN le_tutor_training_item i2 ON i2.section_id = s2.id
                  WHERE i2.id = :target_item_id)
)
SELECT o.id, p.completed_at
FROM ordered o
LEFT JOIN le_tutor_training_progress p ON p.item_id = o.id AND p.tutor_id = :tutor_id
WHERE o.rn <= (SELECT rn FROM ordered WHERE id = :target_item_id)
ORDER BY o.rn;
```

target 아이템보다 앞선 모든 아이템에 `completed_at`이 있어야 진행 허용 (필수 코스만; 보충 코스는 검증 생략).

### 4.4 onboarding-url 엔드포인트 (AC25, AC26)

```typescript
async getOnboardingUrl(tutorId: number) {
  const tutor = await ...  // tutorType + email
  const code = tutor.tutorType === '영어' ? 'ONBOARDING_URL_EN' : 'ONBOARDING_URL_JP'
  const row = await db.select().from(tbSysCodeDetail)
    .where(and(eq(tbSysCodeDetail.groupCode, 'TUTOR_TRAINING'), eq(tbSysCodeDetail.detailCode, code)))
    .limit(1).then(r => r[0])
  if (!row || !row.value) return { url: null, reason: 'NOT_CONFIGURED' }
  const u = new URL(row.value)
  u.searchParams.set('email', tutor.email)
  return { url: u.toString() }
}
```

프론트 `OnboardingTile`은 활성 상태에서 클릭 시 이 엔드포인트 호출 → 응답이 null이면 안내 + 버튼 비활성, URL이면 navigate.

---

## 5. Track C (조건부) — podo-backend 패치

레포: `/Users/johnsong/podo-backend`

Phase 0 §1.1에서 `CLASS_AVAILABLE=1` 필터 누락이 발견된 경로에만 패치. **단순 WHERE 절 추가만 허용.**

패치 PR 템플릿:
```sql
-- Before
SELECT ... FROM GT_TUTOR WHERE <기존 조건>;

-- After
SELECT ... FROM GT_TUTOR WHERE <기존 조건> AND CLASS_AVAILABLE = 1;
```

PR 본문에 Phase 0 감사 결과(§1.1) 표를 인용. 그 외 코드 변경 시 본 작업 범위를 벗어남.

---

## 6. 자동 검증 (vitest 단위 테스트) — AC38

레포: `apps/tutor-web`

### 6.1 evaluateTrainingDoneLatch 5케이스

```typescript
describe('evaluateTrainingDoneLatch', () => {
  it('grandfather=Y → no-op (즉시 반환, IS_TRAINING_DONE 변경 안 함)', ...)
  it('IS_TRAINING_DONE=Y → no-op', ...)
  it('필수 아이템 0개 (use_yn=N 또는 is_mandatory=N만 존재) → 즉시 Y로 래치', ...)
  it('부분 완료 → 변경 없음 (Y로 래치 안 됨)', ...)
  it('전체 완료 → Y로 래치', ...)
})
```

### 6.2 signUp 4케이스

```typescript
describe('signUp', () => {
  it('정상 가입 → GT_USER + GT_TUTOR 셸 INSERT + IS_TRAINING_DONE 래치 실행', ...)
  it('이메일 중복 → ConflictError + INSERT 발생 안 함', ...)
  it('INSERT 도중 실패 → 전체 롤백 (GT_USER 행도 남지 않음)', ...)
  it('tutor_type=영어 → /en/training redirect, 일본어 → /jp/training redirect', ...)
})
```

### 6.3 seek 가드 3케이스

```typescript
describe('seekGuard', () => {
  it('target <= watched_sec + 1 → 통과', ...)
  it('target > watched_sec + 1 → watched_sec으로 스냅백', ...)
  it('isCompleted=true → 모든 seek 허용 (가드 비활성)', ...)
})
```

### 6.4 코스 권한

```typescript
describe('courseAccessGuard', () => {
  it('tutor_type 매칭 코스 → 정상 응답', ...)
  it('tutor_type 미스매치 코스 → 403 또는 404 반환 (정책 결정 후 통일)', ...)
})
```

---

## 7. 수동 검증 17개 시나리오 (AC39)

산출물: `.ouroboros/manual-verification.md`

dev / qa / stage 각 환경에서 시나리오 1~17을 실행하고 PASS/FAIL을 표로 기록.
시나리오 본문은 seed.yaml의 AC39 또는 본 핸드오프의 seed 인용을 참고.

---

## 8. 배포 체크리스트

```
[ ] Phase 0 감사 완료 → .ouroboros/phase-0-audit.md 머지
[ ] Track C 패치 PR (필요 시) 머지 → podo-backend 배포 완료
[ ] Migration SQL 작성 → grape PR로 머지 → 스테이지 DB 실행 → 운영 DB 실행 (백필 포함)
[ ] grape 코드 (Track A) PR 머지 → grape 배포
[ ] tutor-web 코드 (Track B) PR 머지 → tutor-web 배포
[ ] vitest 단위 테스트 CI에서 그린
[ ] 17 수동 시나리오 dev/qa/stage 모두 PASS
[ ] TB_SYS_CODE_DETAIL에 ONBOARDING_URL_EN / ONBOARDING_URL_JP 실제 URL 입력 완료
[ ] 어드민 운영 SOP 안내 (검수 대기 필터 사용법, CLASS_AVAILABLE=1 승인 절차)
```

---

## 9. Open Items (decide_later)

본 작업 범위 외이며 후속 PRD/작업으로 추적:

- 6색 프리셋의 정확한 hex/디자인 토큰 매핑
- 영상 시청 변조 방지 (서버측 누적 시청 시간 검증)
- 이메일 인증 메일 발송
- 비밀번호 재설정/찾기 흐름
- S3 presigned URL 또는 CloudFront signed URL 기반 비공개 영상 접근 통제
- S3 고아 객체 정리 잡
- 어드민의 le_tutor_training_progress 직접 수정 UI
- DDL ↔ drizzle 스키마 자동 일치 검증
- 검수 대기 필터의 운영 최적화 (별도 표지 컬럼)
- grandfather 영구성 정책 재검토 (출시 후 추가되는 신규 필수 코스를 기존 튜터에게도 노출하는 메커니즘)

---

## 10. 참조

| 항목 | 위치 |
|---|---|
| 입력 PRD | `tutor-web-signup-lms-prd.md` (D1~D24 24개 설계 결정) |
| PM seed | `.ouroboros/pm.md` |
| Dev seed (QA 0.81) | `.ouroboros/seed.yaml` |
| Seed audit trail | `~/.ouroboros/seed-revisions/tutor-web-signup-lms-20260526T060000Z.md` |
| 화면 목업 | `mockups.html`, `training-page-options.html`, `onboarding-tile-variations.html` (변형 3 채택) |
| tutor-web 앱 | `/Users/johnsong/podo-app/apps/tutor-web` |
| grape 어드민 | `/Users/johnsong/grape` |
| podo-backend (조건부) | `/Users/johnsong/podo-backend` |
