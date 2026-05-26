# 수업자료 미리보기 (Lesson Material Preview)

**작성일:** 2026-04-21
**오너:** PM (podo@day1company.co.kr)
**대상:** 튜터(tutor-web)
**배포 범위:** `podo-app` 단독 (백엔드 변경 불필요)

---

## 1. Problem

튜터는 수업 시작 직전까지 어떤 자료로 수업을 진행할지 실물로 보지 못한다. 현재 튜터 앱의 "다가올 수업" 카드에는 챕터명/책 제목/학생명만 보이고, 실제 교재 페이지(이미지)는 수업방(pagecall/레몬보드)에 입장해야 확인 가능하다. 튜터들은 CS에 "수업 전에 자료 미리 보고 싶다"는 요청을 반복해왔다.

## 2. Goal

튜터가 다가올 수업 카드에서 **버튼 1번**으로 그 수업의 교재 페이지 전체를 팝업(dialog)으로 빠르게 훑어볼 수 있게 한다.

**Non-goals**
- 자료 수정/다운로드 기능 (보기 전용)
- 학생용 화면 변경
- 완료된/취소된 수업의 자료 접근
- PDF 별도 렌더링 — 교재는 이미 이미지 페이지로 DB에 저장되어 있음 (아래 3절 참조)

## 3. 현재 코드베이스 실태 (검증 완료)

### 3.1 교재 데이터 모델 (중요)

수업 교재는 **"단일 PDF"가 아니라 "이미지 페이지들의 모음"** 이다:

| 테이블 | 역할 |
|---|---|
| `GT_CLASS_COURSE` (`lectureCourseTable`) | 한 강좌의 `BOOK_FILE_ID`, `PRESTUDY_BOOK_FILE_ID` 등 파일 번들 ID |
| `TB_COM_FILE_DETAIL` | `FILE_ID`별로 여러 행, 각 행이 한 페이지. `ATTACH_FILE`(파일명) + `PHOTO_ORDER`(페이지 순서) 보유 |

최종 이미지 URL 조립 규칙 (`podo-backend/.../AWSUtils.java:9`, `LectureCommandServiceImpl.java:527`):

```
https://d2zfcas1eh1pob.cloudfront.net/book/podo/{langType_lowercase}/{URLEncoded(attachFile)}
```

예외: `bookFileId === 'BOOK_JP_2023_1_LEVEL0'` 일 때는 `attachFile`을 URL 인코딩하지 **않음** (기존 로직 그대로 반영 필요).

### 3.2 튜터 수업 리스트 경로 (이미 구현되어 있음)

- UI 컨테이너: `apps/tutor-web/src/features/lectures/ui/lecture-schedule-list/lecture-schedule-list.tsx`
- 카드 렌더: `apps/tutor-web/src/features/lectures/ui/lecture-schedule/lecture-schedule.tsx`
- 액션 버튼 풋터: `apps/tutor-web/src/features/lectures/ui/lecture-schedule-button-footer/lecture-schedule-button-footer.tsx` (이 파일의 `UpcomingFooter`가 버튼을 추가할 위치)
- 응답 스키마: `apps/tutor-web/src/server/modules/lectures/dto/getLectureListResBody.schema.ts` (`lectureSummarySchema`)
- BFF 서비스: `apps/tutor-web/src/server/modules/lectures/service.ts` `getLectureList()` — 이미 `lectureCourseTable`을 `leftJoin` 중 (`service.ts:117`)
- 공용 Dialog: `apps/tutor-web/src/shared/ui/dialog/dialog.tsx` (title/content/footer slot 구조, Headless UI 기반)
- 기존 다이얼로그 패턴 참조: `apps/tutor-web/src/features/lectures/ui/student-memo-by-tutor-dialog/student-memo-by-tutor-dialog.tsx`
- 다이얼로그 open/close 훅: `useToggleState` (union literal ID로 다이얼로그 구분)

### 3.3 기존 자산으로 가능한 것 / 만들어야 하는 것

| 항목 | 상태 |
|---|---|
| 버튼을 달 UI 지점 | ✅ 존재 (`UpcomingFooter`) |
| 공용 Dialog 컴포넌트 | ✅ 존재 |
| `bookFileId` 컬럼 | ✅ 존재 (`lectureCourseTable.bookFileId`) |
| `TB_COM_FILE_DETAIL` Drizzle 스키마 | ❌ 없음 — **추가 필요** |
| 교재 페이지 목록을 반환하는 API | ❌ 없음 — **신규 엔드포인트 필요** |
| 교재 페이지 URL 조립 로직 (클라이언트) | ❌ 없음 — 백엔드 응답에서 조립해 보냄 |
| Spring 백엔드 변경 | ❌ **필요 없음** — tutor-web Next.js BFF가 DB에 직접 접근 가능 |

---

## 4. UX

### 4.1 진입 지점

`UpcomingFooter` 좌측 버튼 그룹 (`lecture-schedule-button-footer.tsx:158-185` 데스크톱, `:238-266` 모바일) 에 새 버튼 추가:
- 라벨: `수업자료` / `Lesson Material` / `授業資料`
- 아이콘: `Icon.LineBook` 또는 `Icon.LineFileText` (디자인시스템 확인 후 확정)
- 노출 조건: `lecture.status === 'RESERVED'` 이고 `bookFileUrls.length > 0`

### 4.2 다이얼로그 내용

- **제목:** `수업자료 미리보기 — {bookName}`
- **본문:** 페이지 이미지를 세로 스크롤 갤러리로 나열 (한 페이지씩 위에서 아래로). 각 이미지에 `loading="lazy"`, 각 이미지 위에 `P.1`, `P.2 … 순서 라벨.
- **풋터:** `닫기` 버튼 1개
- 빈 상태: 페이지가 0개면 "아직 자료가 등록되지 않았어요" 텍스트 표시
- 로딩 상태: 스켈레톤 (기존 다이얼로그 패턴 사용)

### 4.3 분석 이벤트 (기존 `track` 패턴 그대로)

- `popup_viewed` `{ name: 'lesson_material_preview', type: 'dialog' }`
- `button_clicked` `{ name: 'preview_lesson_material', location: 'lesson_card', action: 'open_material_dialog' }`

---

## 5. 구체 코드 플랜

### 5.1 Drizzle 스키마 신규 추가

**신규 파일:** `apps/tutor-web/src/server/db/schema/comFileDetail.ts`

```ts
import { int, mysqlTable, varchar } from 'drizzle-orm/mysql-core'

export const comFileDetailTable = mysqlTable('TB_COM_FILE_DETAIL', {
  fileDetailId: varchar('FILE_DETAIL_ID', { length: 32 }).notNull(),
  fileId: varchar('FILE_ID', { length: 32 }).notNull(),
  attachFile: varchar('ATTACH_FILE', { length: 500 }),
  attachFileName: varchar('ATTACH_FILE_NAME', { length: 500 }),
  photoOrder: varchar('PHOTO_ORDER', { length: 10 }),
})
```

> 정확한 컬럼 길이는 Spring 쪽 엔티티 또는 실DB 스키마로 재확인 필요 (위 값은 관례값).

### 5.2 새 엔드포인트: 교재 페이지 URL 목록 반환

튜터-웹은 hono RPC 패턴. `apps/tutor-web/src/server/modules/lectures/` 하위에 엔드포인트 추가.

**DTO 신규:** `apps/tutor-web/src/server/modules/lectures/dto/getLectureMaterialResBody.schema.ts`

```ts
import { z } from 'zod'

export const lectureMaterialPageSchema = z.object({
  order: z.number(),
  url: z.string().url(),
})

export const getLectureMaterialResBodySchema = z.object({
  lectureId: z.number(),
  bookName: z.string().nullable(),
  pages: z.array(lectureMaterialPageSchema),
})

export type GetLectureMaterialResBodySchema = z.infer<typeof getLectureMaterialResBodySchema>
```

**서비스 메서드 추가:** `apps/tutor-web/src/server/modules/lectures/service.ts` 내 `LectureService` 클래스

```ts
async getLectureMaterial(tutorId: number, lectureId: number, locale: string) {
  // 1) tutor 소유 수업인지 확인 + bookFileId / prestudyBookFileId / langType / bookTitle 조회
  const [row] = await this.db
    .select({
      bookFileId: lectureCourseTable.bookFileId,
      prestudyBookFileId: lectureCourseTable.prestudyBookFileId,
      langType: lectureCourseTable.langType,
      bookTitle: lectureCourseTable.bookTitle,
      bookName: lectureCourseTable.bookName,
      classState: lectureTable.classState,
      teacherUserId: lectureTable.teacherUserId,
    })
    .from(lectureTable)
    .leftJoin(lectureCourseTable, eq(lectureTable.classCourseId, lectureCourseTable.id))
    .where(and(eq(lectureTable.id, lectureId), eq(lectureTable.teacherUserId, tutorId)))

  if (!row) throw new HttpError(404, { code: 'NOT_FOUND_LECTURE', message: 'Not Found lecture.' })

  // 2) CLASS_STATE가 'PRESTUDY'면 prestudy 파일 ID 사용 (podo-backend LectureOnlineJpaRepository:725~728 로직 그대로)
  const fileId = row.classState === 'PRESTUDY' ? row.prestudyBookFileId : row.bookFileId
  if (!fileId) return { lectureId, bookName: this.resolveBookName(row, locale), pages: [] }

  // 3) 페이지 목록 조회
  const rows = await this.db
    .select({
      attachFile: comFileDetailTable.attachFile,
      photoOrder: comFileDetailTable.photoOrder,
    })
    .from(comFileDetailTable)
    .where(eq(comFileDetailTable.fileId, fileId))
    .orderBy(sql`CAST(${comFileDetailTable.photoOrder} AS DECIMAL(5)) ASC`)

  // 4) URL 조립 — podo-backend LectureCommandServiceImpl:522~527 규칙 그대로 이식
  const host = 'https://d2zfcas1eh1pob.cloudfront.net'
  const langSegment = (row.langType ?? 'cn').toLowerCase()
  const pages = rows
    .map((r, idx) => {
      if (!r.attachFile) return null
      const fileName =
        fileId === 'BOOK_JP_2023_1_LEVEL0' ? r.attachFile : encodeURIComponent(r.attachFile)
      return { order: idx + 1, url: `${host}/book/podo/${langSegment}/${fileName}` }
    })
    .filter((p): p is { order: number; url: string } => p !== null)

  return { lectureId, bookName: this.resolveBookName(row, locale), pages }
}
```

> `resolveBookName`은 기존 `getLectureList`에서 bookTitle(JSON)/bookName fallback 하던 로직을 사소하게 추출해 재사용. 별도 헬퍼로 뽑아도 되고, 인라인으로 복붙해도 됨 (1회성이므로 과한 추상화는 지양).

**라우트 등록:** 기존 hono 라우터 파일(`apps/tutor-web/src/server/modules/lectures/index.ts` 류, 실제 파일명 재확인)에 추가:

```
GET /api/v1/lectures/:lectureId/material   → LectureService.getLectureMaterial
```

### 5.3 클라이언트: React Query hook

**신규 파일:** `apps/tutor-web/src/entities/lectures/api/useLectureMaterial.ts` (기존 엔티티 구조 관례 따르기)

```ts
export const useLectureMaterial = (lectureId: number | null | undefined, enabled: boolean) =>
  useQuery({
    queryKey: ['lectures', lectureId, 'material'],
    queryFn: async () => {
      const res = await getRpcClient().api.v1.lectures[':lectureId'].material.$get({
        param: { lectureId: String(lectureId) },
      })
      return res.json()
    },
    enabled: Boolean(lectureId) && enabled,
    staleTime: 5 * 60 * 1000, // 수업 시작 전까지 자료는 거의 바뀌지 않음
  })
```

### 5.4 UI 변경

**신규 파일:** `apps/tutor-web/src/features/lectures/ui/lesson-material-preview-dialog/lesson-material-preview-dialog.tsx`

- `StudentMemoByTutorDialog`를 템플릿으로 복붙 후 단순화
- `useToggleState<'lessonMaterialPreview'>()` 로 open/close
- `useSelectedLectureContext()`에서 `selectedLecture` 가져와 `useLectureMaterial(selectedLecture?.id, open)` 호출
- content slot에 세로 스크롤 이미지 갤러리; 각 이미지는 `next/image` `<Image>` (`next.config.ts:116`에 `*.cloudfront.net`이 이미 허용되어 있음)
- 로딩 중: 스켈레톤 3개; 빈 상태: 텍스트

**기존 파일 수정:** `apps/tutor-web/src/features/lectures/ui/lecture-schedule-button-footer/lecture-schedule-button-footer.tsx`

1. `useToggleState` 제네릭 union에 `'lessonMaterialPreview'` 추가 (라인 70-78, 모바일 버전도 포함)
2. `UpcomingFooter`의 좌측 버튼 그룹(라인 158-185, 모바일은 238-266)에 새 버튼:

```tsx
<Button
  size="small"
  color="ghost"
  icon={<Icon.LineBook />}
  onClick={() => {
    track('button_clicked', {
      name: 'preview_lesson_material',
      location: 'lesson_card',
      action: 'open_material_dialog',
    })
    selectLecture(lecture)
    onOpen('lessonMaterialPreview')
  }}
>
  {t('preview-material-button')}
</Button>
```

3. 다이얼로그 마운트: 상위에서 이미 `StudentMemoByTutorDialog` 등을 마운트하는 컨테이너(보통 layout 레벨)에 `<LessonMaterialPreviewDialog />` 한 줄 추가. 정확한 위치는 `StudentMemoByTutorDialog`의 마운트 지점을 grep 후 그 옆에 붙이면 됨.

### 5.5 i18n

기존 `useTranslations('lesson-card.footer')` 네임스페이스에 `preview-material-button` 키, `dialog.lesson-material-preview` 네임스페이스에 title/empty/close 키 추가. `ko` / `en` / `ja` 모두.

### 5.6 노출 가드 (버튼 disable 조건)

MVP에서는 버튼은 항상 노출하고 **빈 자료는 다이얼로그 내부의 빈 상태 메시지로 처리**. 이유:
- `bookFileId`가 null인 수업이 얼마나 되는지 확인 전까지 보수적으로 접근
- 버튼 자체를 숨기려면 `getLectureList` 응답에 `hasMaterial: boolean`을 추가해야 하는데(서브쿼리 1회 더) → MVP 이후 사용률 보고 최적화

## 6. 데이터/정합성 체크

릴리스 전 QA DB에서 아래 스팟체크 필수 (`podo-mysql-qa.query` 툴 사용):

1. 최근 30일 `GT_CLASS_COURSE` 중 `BOOK_FILE_ID IS NOT NULL` 비율
2. 대표 `BOOK_FILE_ID` 하나로 `TB_COM_FILE_DETAIL` 조회 시 페이지 수, `PHOTO_ORDER` 정렬 무결성
3. 조립된 URL이 실제로 200을 반환하는지 (EN/JP/CN 각 1건)
4. `BOOK_JP_2023_1_LEVEL0` 예외 케이스가 실제로 유효한지 (예외 분기 유지 여부 재확인)

## 7. 권한/보안

- 엔드포인트는 반드시 **호출 튜터의 수업인지 확인** (`lectureTable.teacherUserId = tutorId` where절) — `getLectureMaterial` 5.2 코드에 이미 포함
- URL은 CloudFront 공개 URL이므로 토큰 부재 시 누구나 접근 가능. 현재 프로덕션에서도 동일 URL을 pagecall에서 사용 중이므로 신규 리스크 아님. 단, 문서에 "이 URL은 공개 CDN이며 CloudFront signed URL 전환은 별도 과제"로 명시.

## 8. 릴리스 순서

1. Drizzle 스키마 추가 → 타입 생성
2. 서비스 메서드 + 라우트 추가 → QA 환경에서 curl로 응답 검증
3. React Query hook + Dialog 컴포넌트
4. 풋터 버튼 추가 + i18n
5. 내부 튜터 QA (특히 데스크톱/모바일 모두 noopener 팝업 없이 인앱 다이얼로그로 제대로 열리는지)
6. 전체 배포

## 9. 성공 지표

- 배포 4주 후 `popup_viewed(name=lesson_material_preview)` 주간 UV가 활성 튜터의 20%+
- 튜터 CS 중 "수업자료 사전 확인" 관련 문의 감소 (정성)
- 다이얼로그 평균 체류 시간 ≥ 8초 (훑어본다는 증거)

## 10. 열린 이슈

- **PDF 지원 여부:** 현재 `TB_COM_FILE_DETAIL.ATTACH_FILE`이 항상 이미지 확장자인지 확인 필요. 만약 일부 강좌가 PDF 한 장으로 업로드되어 있다면 `.pdf` 확장자 분기 → `<iframe>` 렌더 추가. 6-1 데이터 체크로 확정.
- **버튼 노출 조건 최적화:** 6번 결과에서 null 비율이 높으면 `hasMaterial` 플래그 도입 재검토.
- **prestudy 자료 동시 노출 여부:** 현재 설계는 `classState`에 따라 한쪽만 보여줌. 튜터 입장에선 "본강의 자료 + 예습 자료 둘 다" 보고 싶을 수 있음 → 디자인 리뷰 포인트.
