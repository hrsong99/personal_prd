# PRD — 알림톡 템플릿 (결제 후 첫 레슨 보너스 퍼널)

**원천 자료:** Figma 캔버스 **"결제 후 첫 레슨 유도_260414"** — [figma.com/design/ApQyvuzXNHMw1tlARPZIJq/…?node-id=445-46](https://www.figma.com/design/ApQyvuzXNHMw1tlARPZIJq/%F0%9F%92%9A--PODO--%EC%95%8C%EB%A6%BC%ED%86%A1-%EC%97%85%EB%8D%B0%EC%9D%B4%ED%8A%B8?node-id=445-46)

본 문서는 결제 후 첫 레슨 보너스 퍼널에 대해 `PRD.md`의 인라인 알림톡 카피를 대체한다. 본 파일과 `PRD.md`의 카피가 충돌할 경우 **본 파일이 우선한다.**

퍼널은 이제 **7개의 알림 시점(N1–N7)** 으로 구성된다. **N7 (T-6)은 신규 추가된 시점** 으로, 연장된 기간 마감 6시간 전에 발송되는 마지막 푸시이다.

모든 알림은 **두 채널**에서 동시에 발송된다 — **푸시 알림**(디바이스 잠금화면)과 **알림톡**(카카오톡). 아래 각 `## N-X` 섹션은 두 채널을 모두 포함한다: `### N-X — Push notification` 하위 섹션에 제목과 본문이 먼저 나오고, 그 다음 플랜별 알림톡 본문이 이어진다. 푸시의 딥링크 타겟은 기본 알림톡 버튼의 타겟과 동일하다 — 사용자가 어느 쪽을 탭하든 동일한 화면으로 랜딩한다.

---

## 개요 표

| # | 발송 시점 | 템플릿 코드 (무제한 / 라이트 루틴) | 대상 |
|---|---|---|---|
| **N1** | 활성 보너스 기간 **안에서** 첫 레슨 예약 | `pd_bonus_reg_unlim` / `pd_bonus_reg_count` | 보너스 수업 예약 완료 후 — 해당 플랜 구매자 |
| **N2** | 활성 보너스 기간 **밖에서** 첫 레슨 예약 | `pd_reg_book_all_now` *(단일 템플릿, 플랜별 분리 없음)* | 수업 예약 완료 후 (보너스 기간 외) — 레슨권 구매자 |
| **N3** | 1차(초기) 기간 — D-1, 미예약 | `pd_bonus_unlim_bd1` / `pd_bonus_count_bd1` | 보너스 수업 마감 1일 전 — 보너스 미예약자 |
| **N4** | 보너스 지급 (기간 내 첫 레슨 완료) | `pd_bonus_noti_unlim` / `pd_bonus_noti_count` | 첫 수업 완료 구매자 |
| **N5** | 1차 기간 만료 → 2차 기간 오픈 | `pd_bonus_unlim_bd4` / `pd_bonus_count_bd4` | 보너스 1차 기간 마감 — 보너스 미예약자 |
| **N6** | 2차(연장) 기간 — D-1, 미예약 | `pd_bonus_2_unlim_bd1` / `pd_bonus_2_count_bd1` | 2차 보너스 수업 마감 1일 전 — 보너스 미예약자 |
| **N7** *(신규)* | 2차(연장) 기간 — **T-6시간**, 미예약 | `pd_bonus_2_unlim_h6` / `pd_bonus_2_count_h6` | 2차 보너스 수업 마감 6시간 전 — 보너스 미예약자 |

**플랜 분리 규칙:**
- `*_unlim` = 무제한 레슨권 (Unlimited)
- `*_count` = 라이트 루틴 / 월8회 회차권 (Light Routine)

**전 템플릿 공통 변수:**

| 변수 | 출처 | 비고 |
|---|---|---|
| `{studentName}` | `User.studentName` | `NotificationService`가 `User` 객체에서 자동으로 가져옴 |
| `{subjectName}` | `extras["subjectName"]` | 형식: `(영어) Start 1 - {bookName}` — `PodoScheduleServiceImplV2.book()`에서 생성 |
| `{classDatetime}` | `extras["classDatetime"]` | `DateTimeUtils.convertFormat(kstClassDateTime)` — KST, `M월 d일(E) 오전/오후 h:mm` |
| `{Lessonterm}` | `extras["Lessonterm"]` | 분 단위 정수 (예: `25`) |
| `{langtype}` | `extras["langtype"]` | `영어` / `일본어` (`PODO_LANG_TYPE` 시스템 코드 기준) |
| `{rewardDays}` | `extras["rewardDays"]` | `purchase_bonus` 레코드에 스냅샷된 일수 연장 — `21` / `30` / `60` |
| `{rewardCount}` | `extras["rewardCount"]` | **라이트 루틴 전용** — 보너스 레슨 횟수: `5` / `8` / `12` |
| `{deadlineDaysLeft}` | `extras["deadlineDaysLeft"]` | 현재로부터 연장 기간 마감까지 남은 일수 (정수, 스냅샷 타임존 기준) |

---

## N1 — 첫 레슨 예약 완료 (혜택 기간 안에 예약)

**대체 대상:** 사용자가 미지급 상태의 활성 `purchase_bonus`를 보유하고 AND `lesson.scheduled_end_at <= active_deadline`인 경우, 기존 `pd_reg_infinity_2` / `pd_reg_weeklyclass_2`를 대체한다.

**트리거 지점:** `PodoScheduleServiceImplV2.book()`의 `regularCnt == 0` 분기 (`PodoScheduleServiceImplV2.java:1106-1112`). 라우팅 판단: `purchase_bonus`가 활성이고 AND 기간 내라면 → 기존 레거시 템플릿 대신 N1 사용.

### N1 — Push notification

두 플랜 공통 제목, 본문은 플랜별 분리.

- **제목:** `🎁 {studentName}님, 첫 레슨 예약 완료!`
- **본문 (무제한):** `우리 {classDatetime} 수업 수업 끝내주게 받고, {rewardDays}일 무료 받아봐요!😎`
- **본문 (라이트 루틴):** `우리 {classDatetime} 수업 끝내주게 받고 {rewardDays}일 연장 + 레슨 {rewardCount}회 무료 받아봐요!😎`
- **딥링크:** 예약 완료 상세 화면 (Home State B) — 기본 알림톡 버튼과 동일 타겟

### N1 — 무제한 · `pd_bonus_reg_unlim`

**헤드라인 카드:** `첫 레슨 예약 완료 안내`

**본문:**
```
🏃 {studentName}님! 첫 레슨, 외국어 전설의 시.작.⭐

{subjectName} 레슨 등록 완료!
- 레슨 일시 : {classDatetime}
────────────
🎁 오늘 예약한 레슨 완료만 해도 {rewardDays}일 무료!
✅ 2일안에 꼭 완료 해야해요.
✅ 수업을 완료해야 혜택이 지급돼요.
────────────
⚠ 안내사항
- 무료 연장 혜택은 첫 레슨 완료 직후 자동으로 적용돼요.
```

**버튼 (2개):**
| 버튼 이름 | Mobile / PC 링크 | 연결 화면 |
|---|---|---|
| `예습하러 가기` | `{moPrestudyLink}` / `{pcPrestudyLink}` | 예약된 첫 레슨의 예습 화면 |
| `학습 가이드` | `{moHomeLink}` / `{pcHomeLink}` | 홈 학습 가이드 섹션 |

### N1 — 라이트 루틴 · `pd_bonus_reg_count`

**헤드라인 카드:** `첫 레슨 예약 완료 안내`

**본문:**
```
🏃 {studentName}님! 첫 레슨, 외국어 전설의 시.작.⭐

{subjectName} 레슨 등록 완료
- 레슨 일시 : {classDatetime}
────────────
🎁 오늘 예약한 레슨 완료만 해도
🎁 {rewardDays}일 무료 연장 + 보너스 레슨 {rewardCount}회!
✅ 2일안에 꼭 완료 해야해요.
✅ 수업을 완료해야 혜택이 지급돼요
────────────
⚠ 안내사항
- 혜택은 첫 레슨 완료 직후 자동으로 적용돼요.
```

**버튼:** 무제한 버전과 동일.

---

## N2 — 첫 레슨 예약 완료 (혜택 기간 밖에 예약) · `pd_reg_book_all_now`

**단일 템플릿 — 플랜별 분리 없음.** 사용자가 마감일을 인지하고 그 이후로 예약했기 때문에 보너스는 **의도적으로** 언급하지 않는다.

**트리거 지점:** N1과 동일한 `PodoScheduleServiceImplV2.book()` 분기. `purchase_bonus`가 활성이고 AND `lesson.scheduled_end_at > active_deadline`이라면 → N2 사용.

### N2 — Push notification

두 플랜 공통 단일 푸시 (보너스는 의도적으로 언급하지 않음):

- **제목:** `🎉 {studentName}님, 첫 레슨 예약 완료!`
- **본문:** `{classDatetime}에 만나요. 예습하고 오면 대화가 더 편해져요 📗`
- **딥링크:** 예약 완료 상세 화면 (Home State B) — 기본 알림톡 버튼과 동일 타겟

**헤드라인 카드:** `첫 레슨 예약 완료 안내`

**본문:**
```
🏃 {studentName}님! 첫 레슨, 외국어 전설의 시.작.⭐

{subjectName} 레슨 등록 완료
- 레슨 일시 : {classDatetime}

{Lessonterm}분 레슨만으로 원어민과의 5시간 대화만큼 실력 향상 효율을 내는 포도 레슨의 비결은 바로..!

가볍지만 강력한 "🌪폭.풍.예.습"
▶ 예습 1번으로, 레슨 만족도가 아주 좋기로 자자하다구!

🔥 {langtype} 실력 제자리 걸음 NO! 수업 전에 예습하면 더 빨리 느니깐
- "찐 실력향상"을 위해 한 번 클릭해볼까?
👇
```

**버튼 (2개):** `예습하러 가기` → `{moPrestudyLink}/{pcPrestudyLink}` · `학습 가이드` → `{moHomeLink}/{pcHomeLink}`

---

## N3 — 혜택 마감 D-1 (예약 미완료 리마인더, 1차 기간)

**트리거:** **초기** 마감일(`purchase_day + 1`) 전날 아침 9시 로컬 타임에 예약 발송. 이미 예약/지급/소멸된 경우 억제.

**발송 전략:** `notificationService.makeAndSend(templateCode, userId, copyMap, …)`로 예약 발송하며, `copyMap["scheduleAt"] = "yyyy-MM-dd HH:mm"` (`PaymentGateway.sendScheduledNotifications`의 기존 `PD_FIRSTCLASS_*` / `PD_MKT_REG_REMIND_*` 템플릿 형식)과 `copyMap["uniqueKey"] = "{userId}-{TEMPLATE_CODE}"`를 사용해, 사용자가 예약하면 `disableFutureAlim`으로 취소 가능하게 한다.

### N3 — Push notification

두 플랜 공통 제목, 본문은 플랜별 분리.

- **제목:** `⏰ {studentName}님! 내일이 지나면 첫 레슨 혜택이 사라져요💨`
- **본문 (무제한):** `[첫 레슨 완료]만 해도 {rewardDays}일 꽁짜! 지금 일단 예약하기🏃🏻‍♀️💨`
- **본문 (라이트 루틴):** `[첫 레슨 완료] 만 해도 {rewardDays}일 연장 + 레슨 {rewardCount}회 추가! 지금 일단 예약하기🏃🏻‍♀️💨`
- **딥링크:** Home State A — 알림톡 버튼과 동일 타겟

### N3 — 무제한 · `pd_bonus_unlim_bd1`

**헤드라인 카드:** `첫 레슨 혜택 소멸 1일 전 알림`

**본문:**
```
【첫 레슨 혜택 D-1】 {studentName}님! 내일이 지나면 {rewardDays}일 무료 이용권이 사라져요 🔔🔔🔔

{studentName}님, 꼭 확인해주세요💚
내일 밤이 지나면 이용 기간 연장 혜택은 더 이상 받을 수 없어요.
────────────
⏰ 내일 밤까지 한정 ⏰
✅ 첫 레슨 예약 + 완료 시
✅ 이용 기간 {rewardDays}일 자동 연장
────────────
지금 바로 첫 레슨 예약하고, 연장 혜택 받기😎

※ 본 메시지는 첫 구매 혜택 안내에 따라 자동 발송된 메시지입니다.
```

**버튼 (1개):** `🔥일단 레슨 예약` → `{moHomeLink}` / `{pcHomeLink}` (Home State A)

### N3 — 라이트 루틴 · `pd_bonus_count_bd1`

**헤드라인 카드:** `첫 레슨 혜택 소멸 1일 전 알림`

**본문:**
```
【첫 레슨 혜택 D-1】 {studentName}님! 내일이 지나면 {rewardDays}일 무료 이용권이 사라져요 🔔🔔🔔

{studentName}님, 꼭 확인해주세요💚
내일 밤이 지나면 기간 연장과 보너스 레슨 혜택 둘 다 더 이상 받을 수 없어요.
────────────
⏰ 내일 밤까지 한정 ⏰
✅ 첫 레슨 예약 + 완료 시
✅ 이용 기간 {rewardDays}일 자동 연장
✅ 보너스 레슨 {rewardCount}회 자동 지급
────────────
지금 바로 첫 레슨 예약하고, 연장 혜택 받기😎

※ 본 메시지는 첫 구매 혜택 안내에 따라 자동 발송된 메시지입니다.
```

**버튼:** 무제한과 동일.

---

## N4 — 보너스 지급 완료

**트리거:** `grape`의 레슨 파이널라이즈 (`GT_CLASS.CLASS_STATE = 'FINISH'`, `INVOICE_STATUS = 'COMPLETED'`, `COMP_DATETIME` 기록됨) AND `lesson.scheduled_end_at <= active_deadline` AND 보너스 지급 멱등성 검사 통과. 권한 변경이 커밋된 직후 보너스 지급 서비스에서 즉시 발송 (예약 발송 아님).

### N4 — Push notification

제목은 플랜별 분리, 본문은 공통.

- **제목 (무제한):** `🎁 {studentName}님, 이용 기간 {rewardDays}일 연장 완료!`
- **제목 (라이트 루틴):** `🎁 {studentName}님, {rewardDays}일 연장 + 보너스 레슨 {rewardCount}회 지급 완료!`
- **본문:** `첫 레슨.. 꽤 멋지시던데요?😏 포도와 함께 외국어 전설로 남아주세요⭐`
- **딥링크:** 보너스가 반영된 Home State B — 알림톡 버튼과 동일 타겟

### N4 — 무제한 · `pd_bonus_noti_unlim`

**헤드라인 카드:** `첫 레슨 혜택이 지급되었어요`

**본문:**
```
🎉 {studentName}님! 첫 레슨, 꽤 멋지시던데요..?😏

첫 레슨 완료 혜택으로
이용 기간이 {rewardDays}일 연장됐어요 🎁
────────────
💚 혜택 안내
✅ 연장된 기간 동안 무제한으로 레슨 수강 가능
✅ 꾸준한 예습 + 레슨이 실력 향상의 열쇠!
────────────
앱 내 [마이 포도 플랜]에서 지급된 보너스 수강권을 확인하실 수 있어요! 👇🏻
```

**버튼 (1개):** `🎁혜택 확인하기` → `{moHomeLink}` / `{pcHomeLink}` (보너스가 반영된 Home State B)

### N4 — 라이트 루틴 · `pd_bonus_noti_count`

**헤드라인 카드:** `첫 레슨 혜택이 지급되었어요`

**본문:**
```
🎉 {studentName}님! 첫 레슨, 꽤 멋지시던데요..?😏

첫 레슨 완료 혜택으로
이용 기간 {rewardDays}일 연장 + 보너스 레슨 {rewardCount}회가 방금 지급됐어요 🎁
────────────
💚 혜택 안내
✅ 연장된 {rewardDays}일 동안 루틴 레슨 이어가기 가능
✅ 추가된 {rewardCount}회 보너스 레슨도 자유롭게 이용 가능
✅ 꾸준한 예습 + 레슨이 실력 향상의 열쇠!
────────────
앱 내 [마이 포도 플랜]에서 지급된 보너스 수강권을 확인하실 수 있어요! 👇🏻
```

**버튼:** 무제한과 동일.

---

## N5 — 혜택 기간 연장 안내 (1차 기간 만료 → 2차 기간 오픈)

**트리거:** 초기 마감일 통과 시점(스냅샷 타임존 기준 `purchase_day + 2`의 종료 시각)에 연장 크론이 작동. 보너스가 아직 미지급이고 미예약 상태일 때만 작동. 즉시 발송되며, 뒤이어 N6(D-1)와 N7(T-6)을 연장 기간에 맞춰 예약.

### N5 — Push notification

두 플랜 공통 제목, 본문은 플랜별 분리.

- **제목:** `🚨[속보]{studentName}님 첫 레슨 완료 혜택 긴급결정`
- **본문 (무제한):** `외국어 멱살 잠깐 잡아도 될까요..?{rewardDays}일 무료 혜택 부활🔥 지금부터 딱 {deadlineDaysLeft}일까지만! 일단 예약하기 💨`
- **본문 (라이트 루틴):** `{rewardDays}일 무료+보너스 레슨{rewardCount}회 무료 혜택 부활🔥 지금부터 딱 {deadlineDaysLeft}일 까지만! 일단 예약하기 💨`
- **딥링크:** 리프레시된 토스트가 붙은 Home State A — 알림톡 버튼과 동일 타겟

### N5 — 무제한 · `pd_bonus_unlim_bd4`

**헤드라인 카드:** `첫 레슨 혜택 기간 연장안내`

**본문:**
```
🚨[속보] {studentName}님! 첫 레슨 혜택이 부활했어요. 외국어 멱살 잠깐 잡아도 될까요..?

{studentName}님의 첫 레슨을 기다리다가 바쁘신것 같아, 포도가 혜택 기간을 연장했어요💚
결심한 지금, 시작만 해도 실력 폭풍상승의 첫걸음📈
────────────
⏰ 연장 종료일: {deadlineDaysLeft}일⏰
✅ 첫 레슨 예약 + 완료 시
✅ {rewardDays}일 자동 무료 연장 혜택
────────────
🔥 이번 기회 놓치면 연장 혜택은 영영 사.라.져.요
▶ 지금 바로 첫 레슨 예약하고, 연장 혜택까지 챙겨가세요!

※ 본 메시지는 첫 구매 혜택 안내에 따라 자동 발송된 메시지입니다.
```

**버튼 (1개):** `🔥지금 첫 레슨 예약하기` → `{moHomeLink}` / `{pcHomeLink}` (리프레시된 토스트가 붙은 Home State A)

### N5 — 라이트 루틴 · `pd_bonus_count_bd4`

**헤드라인 카드:** `첫 레슨 혜택 기간 연장안내`

**본문:**
```
🚨[속보] {studentName}님! 첫 레슨 혜택이 부활했어요. 외국어 멱살 잠깐 잡아도 될까요..?

{studentName}님의 첫 레슨을 기다리다가 포도가 혜택 기간을 한 번 더 연장했어요💚
결심한 지금, 시작만 해도 실력 폭풍상승의 첫걸음📈
────────────
⏰ 연장 종료일: {deadlineDaysLeft}일⏰
✅ 첫 레슨 예약 + 완료 시
✅ 이용 기간 {rewardDays}일 자동 연장
✅ 보너스 레슨 {rewardCount}회 자동 지급
────────────
🔥 이번 기회 놓치면 연장 + 보너스 레슨 혜택 둘 다 영영 사.라.져.요
▶ 지금 바로 첫 레슨 예약하고, 연장 + 보너스까지 다 챙겨가세요!

※ 본 메시지는 첫 구매 혜택 안내에 따라 자동 발송된 메시지입니다.
```

**버튼:** 무제한과 동일.

---

## N6 — 혜택 마감 D-1 (2차 기간, 미예약)

**트리거:** N5가 발송되는 시점에 예약 등록. **연장된** 마감일(`purchase_day + 6`) 전날 아침 9시 로컬 타임에 발송. 이미 예약/지급/소멸된 경우 억제.

**발송 전략:** N3와 동일한 `scheduleAt` / `uniqueKey` 패턴.

### N6 — Push notification

두 플랜 공통 제목, 본문은 플랜별 분리. 톤은 **N3와 의도적으로 다르게** 구성됨 — 긴박한 ⏰ 프레이밍(N3/N7)이 아니라 쾌활하고 사교적인 프레이밍("세상 사람들!!! 첫 레슨 받으신대요")을 써서, 이미 N3를 무시한 사용자를 다른 감정 앵글로 재참여시킨다.

- **제목:** `🔔🔔🔔세상 사람들!!! {studentName}님 첫 레슨 받으신대요🔔🔔🔔`
- **본문 (무제한):** `라고 자랑하고 싶어요! 결심한 지금, 멋지게 시작하고 {rewardDays}일 무료도 받아주세요💚`
- **본문 (라이트 루틴):** `라고 자랑하고 싶어요! 결심한 지금, 멋지게 시작하고 {rewardDays}일 연장 + 레슨{rewardCount}회도 받아주세요💚`
- **딥링크:** Home State A — 알림톡 버튼과 동일 타겟

### N6 — 무제한 · `pd_bonus_2_unlim_bd1`

**헤드라인 카드:** `첫 레슨 혜택 소멸 1일 전 알림`

**본문:**
```
【첫 레슨 마지막 혜택 D-1】{studentName}님! 내일이 지나면 {rewardDays}일 무료 이용권이 영영 사라져요 🔔🔔🔔

{studentName}님, 꼭 확인해주세요💚
내일 밤이 지나면 이용 기간 연장 혜택은 더 이상 받을 수 없어요.
────────────
⏰ 내일 밤까지 한정 ⏰
✅ 첫 레슨 예약 + 완료 시
✅ 이용 기간 {rewardDays}일 자동 연장
────────────
지금 바로 첫 레슨 예약하고, 연장 혜택 받기😎

※ 본 메시지는 첫 구매 혜택 안내에 따라 자동 발송된 메시지입니다.
```

**버튼 (1개):** `🔥일단 레슨 예약` → `{moHomeLink}` / `{pcHomeLink}`

### N6 — 라이트 루틴 · `pd_bonus_2_count_bd1`

**헤드라인 카드:** `첫 레슨 혜택 소멸 1일 전 알림`

**본문:**
```
【첫 레슨 마지막 혜택 D-1】{studentName}님! 내일이 지나면 {rewardDays}일 무료 이용권이 영영 사라져요 🔔🔔🔔

{studentName}님, 꼭 확인해주세요💚
내일 밤이 지나면 기간 연장과 보너스 레슨 혜택 둘 다 더 이상 받을 수 없어요.
────────────
⏰ 내일 밤까지 한정 ⏰
✅ 첫 레슨 예약 + 완료 시
✅ 이용 기간 {rewardDays}일 자동 연장
✅ 보너스 레슨 {rewardCount}회 자동 지급
────────────
지금 바로 첫 레슨 예약하고, 연장 혜택 받기😎

※ 본 메시지는 첫 구매 혜택 안내에 따라 자동 발송된 메시지입니다.
```

**버튼:** 무제한과 동일.

---

## N7 — 혜택 마감 T-6 (2차 기간, 최종 마감 6시간 전) — **신규**

**목적:** 연장 기간 마감 6시간 전에 마지막 기회로 재촉하는 알림. N5 + N6을 보고도 예약하지 않은 사용자가 시계가 다 되어가는 상황에서 전환되도록 퍼널에 추가됨.

**트리거:** N5가 발송되는 시점에 예약 등록 (N6와 동일한 진입점). 계산된 발송 시각 = `extended_deadline.minusHours(6)`, 스냅샷된 타임존 기준으로 `yyyy-MM-dd HH:mm` 형식으로 렌더링. 이미 예약/지급/소멸된 경우 억제.

**발송 전략:** N3, N6와 동일한 `scheduleAt` / `uniqueKey` 패턴. 크론 잡 또는 예약 발송 프로듀서가 계산된 UTC 벽시계 시각을 `copyMap["scheduleAt"]`에 넣어야 함.

### N7 — Push notification

두 플랜 공통 제목, 본문은 플랜별 분리. 제목은 N3의 ⏰ 긴박감을 이어가되 "내일" → "오늘"로 바꿔, 보너스가 사라지기 전 마지막 하루치 푸시임을 알림. 본문 CTA도 "일단 예약하기"(N3) → "당장 예약하기"(N7)로 강도를 높인다.

- **제목:** `⏰ {studentName}님! 오늘이 지나면 첫 레슨 혜택이 사라져요 🚨`
- **본문 (무제한):** `[첫 레슨 완료]만 해도 {rewardDays}일 꽁짜! 지금 당장 예약하기🏃🏻‍♀️💨`
- **본문 (라이트 루틴):** `[첫 레슨 완료] 만 해도 {rewardDays}일 연장 + 레슨 {rewardCount}회 추가! 지금 당장 예약하기🏃🏻‍♀️💨`
- **딥링크:** Home State A — 알림톡 버튼과 동일 타겟

### N7 — 무제한 · `pd_bonus_2_unlim_h6`

**헤드라인 카드:** `첫 레슨 혜택 소멸 6시간 전 알림`

**본문:**
```
【첫 레슨 마지막 혜택 T-6시간】{studentName}님! 오늘이 지나면 {rewardDays}일 무료 이용권이 영영 사라져요 🔔🔔🔔

{studentName}님, 꼭 확인해주세요💚
오늘 밤이 지나면 이용 기간 연장 혜택은 더 이상 받을 수 없어요.
────────────
⏰ 오늘 밤까지 한정 ⏰
✅ 첫 레슨 예약 + 완료 시
✅ 이용 기간 {rewardDays}일 자동 연장
────────────
지금 바로 첫 레슨 예약하고, 연장 혜택 받기😎

※ 본 메시지는 첫 구매 혜택 안내에 따라 자동 발송된 메시지입니다.
```

**버튼 (1개):** `🔥당장 레슨 예약` → `{moHomeLink}` / `{pcHomeLink}`

### N7 — 라이트 루틴 · `pd_bonus_2_count_h6`

**헤드라인 카드:** `첫 레슨 혜택 소멸 6시간 전 알림`

**본문:**
```
【첫 레슨 마지막 혜택 T-6시간】{studentName}님! 오늘이 지나면 {rewardDays}일 무료 이용권이 영영 사라져요 🔔🔔🔔

{studentName}님, 꼭 확인해주세요💚
오늘 밤이 지나면 기간 연장과 보너스 레슨 혜택 둘 다 더 이상 받을 수 없어요.
────────────
⏰ 오늘 밤까지 한정 ⏰
✅ 첫 레슨 예약 + 완료 시
✅ 이용 기간 {rewardDays}일 자동 연장
✅ 보너스 레슨 {rewardCount}회 자동 지급
────────────
지금 바로 첫 레슨 예약하고, 연장 혜택 받기😎

※ 본 메시지는 첫 구매 혜택 안내에 따라 자동 발송된 메시지입니다.
```

**버튼:** 무제한과 동일.

---

## 백엔드 구현 참고사항

모든 백엔드 참조는 `podo-backend`를 가리킨다.

### 1. 템플릿 코드 등록

아래 13개의 코드는 각각 **`ToastTemplateCode.java`** (`applications/log/enums/`)에 엔트리가 필요하다:

```
pd_bonus_reg_unlim, pd_bonus_reg_count,
pd_reg_book_all_now,
pd_bonus_unlim_bd1, pd_bonus_count_bd1,
pd_bonus_noti_unlim, pd_bonus_noti_count,
pd_bonus_unlim_bd4, pd_bonus_count_bd4,
pd_bonus_2_unlim_bd1, pd_bonus_2_count_bd1,
pd_bonus_2_unlim_h6, pd_bonus_2_count_h6,
```

엔트리는 **파라미터 명시 없이** (변수 세트는 DB 행으로 강제) 선언하거나, 기존 스타일대로 명시적 파라미터 리스트(예: `pd_mkt_reg_remind_1(...)`)로 선언할 수 있다. 예약 발송 템플릿의 기존 컨벤션을 따라, N3 / N5 / N6 / N7의 파라미터 리스트에는 `"reservedSendDatetime"`을 포함시켜 `ParamBuilder`가 예약 발송 호출 지점을 검증하도록 한다.

새 보너스 연장 잡 안에서 사는 예약 발송 템플릿(N3/N6/N7)의 경우, `PaymentGateway.sendScheduledNotifications` 패턴을 통해 디스패치된다면 **`NotificationCode.java`** (`applications/notification/enums/`)에도 대문자 enum 엔트리를 추가한다. N1/N2/N4/N5는 별도 호출 지점에서 발송되므로 `ToastTemplateCode`만 있으면 된다.

### 2. `notification_message` DB 행 생성

템플릿 코드별로 1개 행, 다음 내용 포함:
- `message_code` = 소문자 코드 (예: `pd_bonus_2_unlim_h6`)
- `notification_category = 'KAKAO'`
- `message_title` = 헤드라인 카드 텍스트 (예: `첫 레슨 혜택 소멸 6시간 전 알림`)
- `message_content` = 위의 본문 그대로, `${varName}` 자리표시자 사용 (PRD에서는 가독성을 위해 `{varName}`로 표기하나, 저장되는 템플릿은 `${varName}` 또는 `#{varName}` 사용 — `NotificationService.VARIABLE_PATTERN` 참고)
- `use_yn = 'Y'`
- `additional_data` = 기본 extras가 있다면 JSON (버튼 URL은 여기 저장하지 않고 호출 지점에서 빌드)

### 3. 템플릿 선택 — N1 vs N2 vs 레거시 폴백

`PodoScheduleServiceImplV2.book()`의 `regularCnt == 0` 분기 (`PodoScheduleServiceImplV2.java:1106-1112`)를 수정:

```java
// 의사코드 — 기존 infinity/weekly 라우팅 앞에 삽입
Optional<PurchaseBonus> activeBonus = purchaseBonusService.findActiveUnawarded(ticket.getStudentId());
if (activeBonus.isPresent()) {
    boolean inWindow = utcClassDateTime.plusMinutes(ticket.getLessonTime())
        .isBefore(activeBonus.get().getActiveDeadlineUtc())
        || utcClassDateTime.plusMinutes(ticket.getLessonTime())
           .isEqual(activeBonus.get().getActiveDeadlineUtc());

    if (inWindow) {
        templateCode = ticket.getOriginCount().equals(999)
            ? "PD_BONUS_REG_UNLIM"
            : "PD_BONUS_REG_COUNT";
    } else {
        templateCode = "PD_REG_BOOK_ALL_NOW";  // 단일 템플릿, 두 플랜 공통
    }
} else if (ticket.getOriginCount().equals(999)) {
    templateCode = "PD_REG_INFINITY_2";      // 레거시 폴백
} else {
    templateCode = "PD_REG_WEEKLYCLASS_2";   // 레거시 폴백
}
```

N1과 N2 모두 `extras["subjectName"]`, `extras["classDatetime"]`, `extras["Lessonterm"]`, `extras["langtype"]`이 필요하다. N1은 추가로 `extras["rewardDays"]` (두 플랜 공통)와 `extras["rewardCount"]` (라이트 루틴만)이 필요하며, 이들은 구독 설정에서 재계산하지 말고 `purchase_bonus` 행에서 읽어온다.

### 4. `moHomeLink` / `pcHomeLink` / `moPrestudyLink` / `pcPrestudyLink` 빌드

`PodoScheduleServiceImplV2.book()`의 기존 auth-wrap 패턴(라인 1131–1158) 재사용:

```java
String redirectUrl = getReactUrl() + "/?destination=HOME";                           // Home (State A / B)
String redirectUrlEncoded = URLEncoder.encode(redirectUrl, StandardCharsets.UTF_8);
String authWrapUrl = getReactUrl() +
    "/api/v1/authentication/public-redirect?userId=" + user.getId()
    + "&userToken=" + user.getTokenForPhp()
    + "&redirectUrl=" + redirectUrlEncoded;
extras.put("moHomeLink", authWrapUrl);
extras.put("pcHomeLink", authWrapUrl);
```

예습 링크(N1, N2)는 내부 URL에 `destination=PRESTUDY&classId={bookedLessonId}`를 치환한 뒤 인코딩하고, 같은 방식으로 래핑한다. 앱 측에서는 이 destination 문자열을 올바른 라우트로 해석해야 한다.

### 5. N3 / N5 / N6 / N7 예약

`PaymentGateway.sendScheduledNotifications` (`PaymentGateway.java:1889-1946`)의 패턴을 따른다:

```java
Map<String, Object> copyMap = new HashMap<>();
copyMap.put("scheduleAt", sendAt.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")));
copyMap.put("uniqueKey", String.format("%s-%s", userId, templateCode));
notificationService.makeAndSend(templateCode, userId, copyMap, userDto, subscribeDto, extras);
```

구체적인 발송 시각:

| 템플릿 | 예약 시점 | `scheduleAt` 값 |
|---|---|---|
| N3 (`*_bd1`) | 결제 시점 (또는 `purchase_bonus` 생성 시) | `purchase_day + 1`의 로컬 9:00 |
| N5 (`*_bd4`) | 연장 크론 트리거 시 즉시 발송 | 예약 아님 — 라이브 발송 |
| N6 (`*_2_*_bd1`) | 연장 잡 실행 시점 (N5와 동일한 호출 지점) | `purchase_day + 6`의 로컬 9:00 |
| N7 (`*_2_*_h6`) | 연장 잡 실행 시점 (N5와 동일한 호출 지점) | 스냅샷 타임존 기준 `extended_deadline.minusHours(6)` |

모든 시각은 구매 당시 스냅샷된 타임존(디바이스 현재 타임존이 아님 — `PRD.md` "타임존 원천") 기준으로 계산하여 `yyyy-MM-dd HH:mm` 형식으로 포맷한다.

### 6. 예약/지급/소멸 시 취소

새로 추가된 예약 템플릿 코드(대문자 형식)를 `PodoScheduleServiceImplV2.java:142-156`의 `AFTER_BOOK_DISABLE_TARGETS`에 추가해, 사용자가 예약할 때 함께 취소되도록 한다:

```java
private final static List<String> AFTER_BOOK_DISABLE_TARGETS = List.of(
    // ...기존 엔트리...
    "PD_BONUS_UNLIM_BD1",  "PD_BONUS_COUNT_BD1",          // N3
    "PD_BONUS_UNLIM_BD4",  "PD_BONUS_COUNT_BD4",          // N5 (방어적 — N5는 이미 발송됐어야 함)
    "PD_BONUS_2_UNLIM_BD1","PD_BONUS_2_COUNT_BD1",        // N6
    "PD_BONUS_2_UNLIM_H6", "PD_BONUS_2_COUNT_H6"          // N7
);
```

이 예약에 이벤트 핸들러 경로가 사용된다면, `applications/log/event/AlimsEventHandler.java:34-50`의 `AlimsEventHandler.AFTER_BOOK_DISABLE_TARGETS`에도 소문자 형식으로 추가한다.

**보너스 지급 시,** 지급 서비스도 아직 대기 중인 N3/N5/N6/N7이 남아 있다면 `notificationService.disableFutureAlim(templateCode, userId + "-" + templateCode)`로 취소해야 한다 — 예약 시점 취소가 이미 일어났어야 하지만 벨트 앤 서스펜더스로 보강.

**연장 기간 소멸 시**(`purchase_day + 7` 종료 시까지 미완료), 혹시라도 N7이 아직 대기 중이라면 취소한다.

### 7. 멱등성

- N1 / N2는 예약당 1회 발송 (`regularCnt == 0` 분기는 첫 정규 레슨에서만 실행).
- N3 / N6 / N7은 `uniqueKey = "{userId}-{TEMPLATE_CODE}"` 사용 — 예약 알림톡 큐가 이 키로 중복 제거하므로 재예약해도 안전.
- N4는 `purchase_bonus`당 정확히 1회 발송 — 지급 서비스의 기존 `purchase_bonus.awarded_at IS NOT NULL` 멱등성 검사가 이를 보호.
- N5는 `purchase_bonus`당 정확히 1회 발송 — 연장 잡의 원샷 가드 (`extended_at IS NULL`)가 게이트.

---

## 감사 기록 / 원천 정보

- Figma 캔버스: `결제 후 첫 레슨 유도_260414` (2026-04-14 디자인)
- Figma 파일 키: `ApQyvuzXNHMw1tlARPZIJq`
- Figma 노드 (개요): `445:46`
- 템플릿별 섹션 노드: `540:9` (N1), `540:509` (N2), `540:106` (N3), `540:351` (N4), `540:430` (N5), `540:189` (N6), `540:270` (N7)

Figma에서 카피나 변수가 변경되면 본 파일과 해당 `notification_message` DB 행을 업데이트한다 — 변수명이 안정적으로 유지되는 한 코드 경로는 변경할 필요가 없다.
