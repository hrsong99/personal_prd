# 마이포도 탭 내 체험 레벨테스트 리포트

*Created At: 2026-05-26T02:04:08.401511+00:00*

## 목표 (Goal)

체험 레벨테스트 PDF 리포트(체험 레벨테스트 리포트)를 일회성 카카오톡 알림톡 버튼에서 앱의 **마이포도** 탭 내 영구적인 위치로 이동시켜, 유저가 언제든지 자신의 리포트에 접근할 수 있도록 한다.

## 유저 스토리 (User Stories)

1. **체험 레벨테스트 응시자(단일 언어)로서**, 마이포도 → 레슨 및 튜터 관리에서 '체험 레슨 레벨테스트 결과'를 탭하여 PDF 리포트를 보고 싶다. **그래서** 일회성 알림톡 메시지에 의존하지 않고 언제든 레벨테스트 결과를 확인할 수 있도록.
2. **이중 언어 체험 응시자(전체 응시자의 약 3%)로서**, `?lang=` URL 동기화가 적용된 레벨테스트 페이지의 상단 탭으로 EN/JP 리포트를 모두 보고 싶다. **그래서** 응시한 각 언어의 리포트를 자유롭게 전환할 수 있도록.
3. **반복 체험 응시자(전체 응시자의 약 6%)로서**, 언어별로 가장 최근 리포트를 자동으로 보고 싶다. **그래서** 오래된 리포트로 인한 혼란 없이 항상 가장 최신의 관련 결과를 확인할 수 있도록.
4. **알림톡을 수신한 체험 응시자로서**, 카카오톡의 `reportLink` 버튼을 탭하여 앱의 레벨테스트 페이지로 딥링크되고 싶다. **그래서** 외부 Google Docs 뷰어가 아닌 앱 내부의 리포트로 바로 진입할 수 있도록.
5. **알림톡을 수신한 비(非)앱 유저로서**, `reportLink` 딥링크를 탭하여 앱스토어/플레이스토어로 안내받고 싶다. **그래서** 앱을 설치하도록 유도되고, 설치 후 리포트를 영구적으로 이용할 수 있도록.
6. **수강권이 없는 유저(체험 리포트 보유)로서**, 홈 화면 인사말 카드에서 '수강권 둘러보기'와 함께 '레벨테스트 결과' 고스트 버튼을 보고 싶다. **그래서** 홈 화면에서 리포트로 가는 단축 경로를 갖고, 동시에 수강권 구매도 안내받을 수 있도록.
7. **수강권이 없는 유저(체험 리포트 미보유)로서**, 단일 '수강권 둘러보기' CTA가 있는 통합 라이트 인사말 카드를 보고 싶다. **그래서** 깔끔하고 일관된 홈 화면 경험을 통해 수강권 구매로 안내받을 수 있도록.

## 제약사항 (Constraints)

- DB 스키마 변경 없음, 마이그레이션 없음 — 기존 `le_level_test` 테이블만 조회
- 피처 플래그 없음 — 앱 내에서 자체적으로 게이팅(리포트 데이터가 있어야만 행이 노출됨); 알림톡 링크는 하드 컷오버
- 선택 규칙: 언어별로 `url`이 NULL이 아닌 가장 최근 `le_level_test` 행 ('레벨 강제 선택' 행 제외)
- 서버 렌더링 게이팅 — 마이포도 행 노출 및 홈 카드 버튼 분기에 클라이언트 깜빡임 없음
- 변경 레포 한정: podo-backend 및 podo-app (apps/web만) — grape 변경 없음, 네이티브 앱 변경 없음
- 비(非)앱 유저용 웹 폴백 없음 — 딥링크 → 앱스토어/플레이스토어 (설치 퍼널), `classLink`와 동일한 포지셔닝
- 네이티브 릴리즈 불필요 — 라우트는 apps/web(웹뷰에서 서빙되는 Next.js)에 존재; open-in-app 프리픽스는 이미 apps/native에 등록되어 있음
- 알림톡 템플릿 링크 컷오버는 apps/web 배포가 프로덕션에 라이브로 확인된 이후에만 진행 (배포 순서 제약)
- 다크 → 라이트 홈 카드 폐기는 순수 시각적 변경 — CTA 컨텐츠 동일, 전환 경로 손실 없음
- 출시 전 디자인이 라이트 싱글 버튼 카드 변형을 승인해야 함 (PRD §5.6)

## 성공 기준 (Success Criteria)

1. 모든 체험 응시자가 마이포도 → 레슨 및 튜터 관리 섹션에서 언제든지 리포트를 찾을 수 있다
2. 이중 언어 유저(~3%)가 언어 탭을 통해 EN과 JP 리포트를 모두 볼 수 있다
3. 반복 응시자(~6%)가 언어별로 최신 리포트만 볼 수 있다
4. 알림톡 `reportLink` 버튼이 앱으로 딥링크되어 올바른 언어 탭을 연다
5. 홈 화면 인사말 카드가 깜빡임 없이 1버튼(리포트 없음) 대 2버튼(리포트 있음) 분기를 렌더링한다
6. 비(非)앱 알림톡 수신자가 앱스토어/플레이스토어로 안내된다 (설치 퍼널)
7. 수강권 없는 유저 회귀(regression) 없음 — 통합 라이트 카드에 '수강권 둘러보기' CTA 유지

## 가정 (Assumptions)

- `le_level_test.student_id`가 인증된 앱 유저 id에 매핑됨 (Q-2, 구현 단계에서 확인 필요)
- v1에는 리포트 히스토리 포함 안됨 — 언어별 최신만 (Q-3, 침묵으로 확인됨)
- open-in-app 프리픽스가 이미 `apps/native/app.config.ts`에 prod/stage/dev로 등록되어 있어 네이티브 릴리즈가 크리티컬 패스에 없음
- 다크와 라이트 `NO_TICKET` 인사말 카드는 동일한 제목, 부제, CTA('수강권 둘러보기' → `/subscribes/tickets`)를 가짐 — 차이는 순수 시각적 스타일링
- 홈 카드 `hasActiveTicket === false` 조건은 미구매자, 만료 구독자, 만료 체험 유저 전반에 걸쳐 동질적임
- API 엔드포인트 `GET /api/v2/leveltest/my`는 0~2개 항목 반환 (언어당 최대 1개)
- PDF 렌더링은 기존 `podo-pdf.pages.dev` 뷰어를 iframe으로 사용 — 새로운 PDF 인프라 불필요
- 카카오톡 인앱 브라우저가 open-in-app 라우터로의 유니버설 링크를 올바르게 처리함 (Q-5에 따라 QA 필요)

## 추후 결정 (Decide Later)

다음 항목들은 이 단계에서 보류되거나 시기상조로 판단되었다. 더 많은 컨텍스트가 확보되면 재검토해야 한다:

- Q-2: `le_level_test.student_id`가 인증된 앱 유저 id와 일치하는지 확인 (구현 단계 검증 과제)
- Q-5: 실제 iOS/Android 디바이스에서 알림톡 버튼 QA — 카카오톡 인앱 브라우저 유니버설 링크 신뢰성 (QA 체크리스트 항목)
- 리포트 히스토리 — v1에서는 언어별 최신 리포트만 표시, 히스토리 뷰 없음
- 비(非)앱 유저가 알림톡 딥링크를 탭할 때의 웹 폴백 PDF 뷰어
- 앱 릴리즈와 알림톡 템플릿 변경 사이의 추가 소크(soak) 기간 또는 단계적 롤아웃 없음 (웹 배포 게이팅으로 인해 불필요)

## 디자인 레퍼런스 (Design References)

확정된 Figma 디자인 (파일: `-PODO- App Update`, `K2pX4mYjQ7mMnnKbXxox3B`):

| # | 화면 | 유저 스토리 | Figma 노드 |
|---|---|---|---|
| 1 | 홈 화면 — `NO_TICKET` 라이트 인사말 카드의 **2버튼 행** ("레벨테스트 결과" 고스트 + "수강권 둘러보기" 프라이머리) | US #6, US #7 | [node 24184-1554](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24184-1554) |
| 2 | 마이포도 탭 — **레슨 및 튜터 관리** 섹션 상단의 "체험 레슨 레벨테스트 결과" 행 | US #1, US #3 | [node 24222-37831](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24222-37831) |
| 3 | `/my-podo/level-test` — 단일 언어 리포트 뷰 (탭 없음, PDF 본문) | US #1, US #3 | [node 24222-38340](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24222-38340) |
| 4 | `/my-podo/level-test` — 이중 언어 리포트 뷰 (🇺🇸 영어 / 🇯🇵 일본어 상단 탭) | US #2 | [node 24222-38255](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24222-38255) |

디자인에서 확인된 사항:
- 디자인 #2에서 행 라벨이 "체험 레슨 레벨테스트 결과"이며, (이름이 변경된) "레슨 및 튜터 관리" 섹션 내에서 학습 통계 / 차단 튜터 관리 **위**에 위치함을 확인.
- 디자인 #3 / #4에서 리포트 본문 자체는 임베드된 PDF 안에 그대로 유지됨을 확인 — 앱은 `FullTopNavigation`("체험 레슨 레벨테스트 결과") 하단에 프레임만 제공하고, 이중 언어인 경우 국기 이모지 + 라벨이 있는 `TabsV1` 행을 추가.
- 디자인 #1에서 2버튼 행 순서 확인: 좌측에 고스트 "레벨테스트 결과", 우측에 프라이머리 "수강권 둘러보기".

## 컴포넌트 (Components)

### Backend (`podo-backend`)

**신규**
- `PodoLevelTestController` — `@AuthenticationPrincipal AuthenticatedUserDto user`를 사용하는 `GET /api/v2/leveltest/my` 핸들러 추가 (기존 `selectLevel`의 인증 패턴 차용).
- `LevelTestServiceImpl.getMyLevelTestReports(Integer studentId)` — §4 선택 규칙 구현 (null/empty `url` 제외, 언어별 최신 `created_at` 유지).
- `LevelTestGateway` — 컨트롤러가 호출하는 위임 메서드 (기존 엔드포인트 미러링).

**수정**
- `LevelTestServiceImpl.receiveMessageCron()` (`LevelTestServiceImpl.java:81`) — `reportLink` 값을 `docs.google.com/gview?url=…`에서 `appBaseUrl() + "/open-in-app/my-podo/level-test?lang=" + dto.getLanguage()`로 교체. 이제 미사용이 된 `:74`의 `encodedUrl` 제거.
- `LectureGateway`의 패턴을 미러링하는 환경별 `appBaseUrl()` 리졸버 추가 (prod / stage / dev 호스트).

**유지(변경 없음)**
- 카카오 템플릿 `PD_TRIAL_ENDRPT_JP_1`, `PD_TRIAL_ENDRPT_JP_2`, `PD_MKT_TRIAL_ENDRPT` — 바인딩되는 `reportLink` 값만 변경되며, 템플릿은 웹링크 버튼 유형 그대로 유지.
- `LevelTestServiceImpl.java:106–126`의 데드 `sendAlimTalk(...)` — 현 상태 유지 (정리 범위 외).

### Frontend (`podo-app`, `apps/web`)

**신규**
- `apps/web/src/entities/level-test/` — entity (api + zod model), `apps/web/src/entities/notice/`의 미러. 베어러 토큰으로 `GET /api/v2/leveltest/my` 호출.
- `apps/web/src/app/(internal)/my-podo/level-test/page.tsx` — 라우트. 보호된 세션, `FullTopNavigation` 타이틀 "체험 레슨 레벨테스트 결과", 신규 뷰 렌더. `apps/web/src/app/(internal)/my-podo/notices/page.tsx`를 미러링.
- `apps/web/src/views/level-test/view.tsx` — 뷰; 0개 / 1개 언어(탭 없음) / 2개 언어(`?lang=` URL 동기화가 있는 `TabsV1`) 케이스 처리. `<iframe src="https://podo-pdf.pages.dev/?url={encodeURIComponent(report.url)}" />`로 PDF 임베드. [Figma #3](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24222-38340) 및 [Figma #4](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24222-38255) 참조.

**수정**
- `apps/web/src/features/my-podo-sections/ui/lesson-manage-section/lesson-manage-section.tsx` — `hasLevelTestReport: boolean` prop 추가. `true`일 때 내부 `VStack`에 `Link` 행을 **최상단**(학습 통계 / 차단 튜터 관리 위)에 렌더: `HStack` + `Typography size="h3"` "체험 레슨 레벨테스트 결과" + `ArrowRightIcon`, `href="/my-podo/level-test"`. [Figma #2](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24222-37831) 참조.
- `apps/web/src/app/(internal)/my-podo/page.tsx` — `GET /api/v2/leveltest/my`를 서버사이드 fetch (기존 `isExtendUser`와 동일한 패턴), `LessonManageSection`에 `hasLevelTestReport` 전달. 클라이언트 fetch 없음 (깜빡임 없음).
- `apps/web/src/features/home-greeting/ui/states/no-ticket-state.tsx` — 라이트 카드 레이아웃으로 재구현. 제목/부제 카피 변경 없음. 하이드레이션된 서버 데이터에서 `GET /api/v2/leveltest/my` 읽음: 리포트 있음 → 2버튼 행 ("레벨테스트 결과" 고스트 → `router.push('/my-podo/level-test')`, "수강권 둘러보기" 프라이머리 → `/subscribes/tickets`); 리포트 없음 → 전체 폭 "수강권 둘러보기" 단일 버튼. [Figma #1](https://www.figma.com/design/K2pX4mYjQ7mMnnKbXxox3B/-PODO--App-Update?node-id=24184-1554) 참조.
- `apps/web/src/widgets/home-greeting/ui/home-no-booking-card.tsx` — 레이아웃을 일반화하여 (또는 공유 레이아웃을 추출하여) **코스 프리뷰 없음**과 **caller가 라벨/핸들러를 제공하는 1버튼 또는 2버튼 행**을 지원. 기존 booking-recommendation 사용처는 변경 없음.
- `apps/web/src/app/(internal)/home/page.tsx` — `GET /api/v2/leveltest/my`를 서버사이드 prefetch 목록에 추가하여 `NO_TICKET` 카드의 버튼 개수가 하이드레이션된 데이터로 결정되도록.
- `apps/web/src/widgets/greeting/hooks/use-greeting-status.ts` — **변경 없음**. `NO_TICKET`은 단일 상태로 유지; 1버튼 vs 2버튼 분기는 카드 내부 로직.

**재사용**
- `@podo-app/design-system-temp`의 `TabsV1` / `TabsV1List` / `TabsV1Trigger` / `TabsV1Content`. URL 동기화 탭 레퍼런스: `apps/web/src/views/my-coupon/view.tsx`.
- `FullTopNavigation`, `Typography`, `HStack`, `VStack`, `ArrowRightIcon`.
- 국기 에셋: `apps/web/public/assets/podo/icon_flag_en.png`, `apps/web/public/assets/podo/icon_flag_jp.png`.
- `apps/web/src/app/open-in-app/[[...path]]/page.tsx` — 제너릭 catch-all; `/open-in-app/my-podo/level-test?lang=…`는 이미 올바르게 라우팅됨. 라우터 코드 작업 불필요.
- PDF 뷰어: `https://podo-pdf.pages.dev/?url=` (확인 완료: `X-Frame-Options` / `frame-ancestors` 없음, iframe 임베드 가능).

**확인 후 삭제 (정리)**
- `GreetingLayout` (다크 `bg-gray-900` 베이스) — `NO_TICKET`이 유일한 소비자였다면 라이트 카드 마이그레이션 이후 제거. 삭제 전 grep으로 확인.

### Native (`podo-app`, `apps/native`)

**변경 없음** — `apps/native/app.config.ts`에 open-in-app 딥링크 프리픽스(`podo.re-speak.com` / `stage-podo.re-speak.com` / `dev-podo.re-speak.com`)가 이미 등록되어 있음. 이 PRD에서 네이티브 릴리즈 불필요.

## 기존 코드베이스 컨텍스트 (Existing Codebase Context)

- **grape** (`/Users/johnsong/grape`) — 이 PRD에서 변경 없음
- **podo-app** (`/Users/johnsong/podo-app`)
- **podo-backend** (`/Users/johnsong/podo-backend`)

---
*PM ID: pm_seed_interview_20260526_012532*
*Interview ID: interview_20260526_012532*
