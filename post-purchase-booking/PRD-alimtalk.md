# PRD — Alimtalk Templates (Post-Purchase First-Lesson Bonus Funnel)

**Source of truth:** Figma canvas **"결제 후 첫 레슨 유도_260414"** — [figma.com/design/ApQyvuzXNHMw1tlARPZIJq/…?node-id=445-46](https://www.figma.com/design/ApQyvuzXNHMw1tlARPZIJq/%F0%9F%92%9A--PODO--%EC%95%8C%EB%A6%BC%ED%86%A1-%EC%97%85%EB%8D%B0%EC%9D%B4%ED%8A%B8?node-id=445-46)

This document supersedes the inline alimtalk copy in `PRD.md` for the post-purchase first-lesson bonus funnel. If copy here disagrees with `PRD.md`, **this file wins.**

The funnel now has **7 notification moments** (N1–N7). **N7 (T-6) is newly added** as a final push 6 hours before the extended-window deadline.

---

## Overview table

| # | When it fires | Template code (무제한 / 라이트 루틴) | Audience |
|---|---|---|---|
| **N1** | First lesson booked **inside** the active bonus window | `pd_bonus_reg_unlim` / `pd_bonus_reg_count` | 보너스 수업 예약 완료 후 — 해당 플랜 구매자 |
| **N2** | First lesson booked **outside** the active bonus window | `pd_reg_book_all_now` *(single template, not split by plan)* | 수업 예약 완료 후 (보너스 기간 외) — 레슨권 구매자 |
| **N3** | 1차(initial) window — D-1, not yet booked | `pd_bonus_unlim_bd1` / `pd_bonus_count_bd1` | 보너스 수업 마감 1일 전 — 보너스 미예약자 |
| **N4** | Bonus awarded (first lesson completed within window) | `pd_bonus_noti_unlim` / `pd_bonus_noti_count` | 첫 수업 완료 구매자 |
| **N5** | 1차 window expired → extended window opens | `pd_bonus_unlim_bd4` / `pd_bonus_count_bd4` | 보너스 1차 기간 마감 — 보너스 미예약자 |
| **N6** | 2차(extended) window — D-1, not yet booked | `pd_bonus_2_unlim_bd1` / `pd_bonus_2_count_bd1` | 2차 보너스 수업 마감 1일 전 — 보너스 미예약자 |
| **N7** *(new)* | 2차(extended) window — **T-6 hours**, not yet booked | `pd_bonus_2_unlim_h6` / `pd_bonus_2_count_h6` | 2차 보너스 수업 마감 6시간 전 — 보너스 미예약자 |

**Plan split convention:**
- `*_unlim` = 무제한 레슨권 (Unlimited)
- `*_count` = 라이트 루틴 / 월8회 회차권 (Light Routine)

**Template variables used across all templates:**

| Variable | Source | Notes |
|---|---|---|
| `{studentName}` | `User.studentName` | Auto-pulled by `NotificationService` from the `User` object |
| `{subjectName}` | `extras["subjectName"]` | Format: `(영어) Start 1 - {bookName}` — built in `PodoScheduleServiceImplV2.book()` |
| `{classDatetime}` | `extras["classDatetime"]` | `DateTimeUtils.convertFormat(kstClassDateTime)` — KST, `M월 d일(E) 오전/오후 h:mm` |
| `{Lessonterm}` | `extras["Lessonterm"]` | Integer minutes (e.g. `25`) |
| `{langtype}` | `extras["langtype"]` | `영어` / `일본어` (from `PODO_LANG_TYPE` system code) |
| `{rewardDays}` | `extras["rewardDays"]` | Snapped day-extension on the `purchase_bonus` record — `21` / `30` / `60` |
| `{rewardCount}` | `extras["rewardCount"]` | **Light Routine only** — bonus class count: `5` / `8` / `12` |
| `{deadlineDaysLeft}` | `extras["deadlineDaysLeft"]` | Integer days from now until the extended deadline, snapshot-timezone based |

---

## N1 — 첫 레슨 예약 완료 (혜택 기간 안에 예약)

**Replaces:** legacy `pd_reg_infinity_2` / `pd_reg_weeklyclass_2` when the user has an active unawarded `purchase_bonus` AND `lesson.scheduled_end_at <= active_deadline`.

**Trigger point:** `PodoScheduleServiceImplV2.book()` at the `regularCnt == 0` branch (`PodoScheduleServiceImplV2.java:1106-1112`). Routing decision: if `purchase_bonus` is active AND in-window → use N1 instead of the legacy template.

### N1 — 무제한 · `pd_bonus_reg_unlim`

**Headline card:** `첫 레슨 예약 완료 안내`

**Body:**
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

**Buttons (two):**
| 버튼 이름 | Mobile / PC 링크 | Resolves to |
|---|---|---|
| `예습하러 가기` | `{moPrestudyLink}` / `{pcPrestudyLink}` | Prestudy for the booked first lesson |
| `학습 가이드` | `{moHomeLink}` / `{pcHomeLink}` | Home study-guide section |

### N1 — 라이트 루틴 · `pd_bonus_reg_count`

**Headline card:** `첫 레슨 예약 완료 안내`

**Body:**
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

**Buttons:** same as 무제한 variant.

---

## N2 — 첫 레슨 예약 완료 (혜택 기간 밖에 예약) · `pd_reg_book_all_now`

**Single template — not split by plan.** The bonus is deliberately **not** mentioned because the user knowingly booked past the deadline.

**Trigger point:** same branch as N1 in `PodoScheduleServiceImplV2.book()`. If `purchase_bonus` is active AND `lesson.scheduled_end_at > active_deadline` → use N2.

**Headline card:** `첫 레슨 예약 완료 안내`

**Body:**
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

**Buttons (two):** `예습하러 가기` → `{moPrestudyLink}/{pcPrestudyLink}` · `학습 가이드` → `{moHomeLink}/{pcHomeLink}`

---

## N3 — 혜택 마감 D-1 (예약 미완료 리마인더, 1차 window)

**Trigger:** scheduled 9am local on the morning before the **initial** deadline day (`purchase_day + 1`). Suppressed if already booked, awarded, or forfeited.

**Sending strategy:** scheduled send via `notificationService.makeAndSend(templateCode, userId, copyMap, …)` with `copyMap["scheduleAt"] = "yyyy-MM-dd HH:mm"` (format used by existing `PD_FIRSTCLASS_*` / `PD_MKT_REG_REMIND_*` templates in `PaymentGateway.sendScheduledNotifications`), and `copyMap["uniqueKey"] = "{userId}-{TEMPLATE_CODE}"` so it can be cancelled via `disableFutureAlim` when the user books.

### N3 — 무제한 · `pd_bonus_unlim_bd1`

**Headline card:** `첫 레슨 혜택 소멸 1일 전 알림`

**Body:**
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

**Button (single):** `🔥일단 레슨 예약` → `{moHomeLink}` / `{pcHomeLink}` (Home State A)

### N3 — 라이트 루틴 · `pd_bonus_count_bd1`

**Headline card:** `첫 레슨 혜택 소멸 1일 전 알림`

**Body:**
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

**Button:** same as 무제한.

---

## N4 — 보너스 지급 완료

**Trigger:** lesson finalize in `grape` (`GT_CLASS.CLASS_STATE = 'FINISH'`, `INVOICE_STATUS = 'COMPLETED'`, `COMP_DATETIME` stamped) AND `lesson.scheduled_end_at <= active_deadline` AND bonus-award idempotency check passes. Fires immediately (not scheduled) from the bonus-award service after the entitlement mutation commits.

### N4 — 무제한 · `pd_bonus_noti_unlim`

**Headline card:** `첫 레슨 혜택이 지급되었어요`

**Body:**
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

**Button (single):** `🎁혜택 확인하기` → `{moHomeLink}` / `{pcHomeLink}` (Home State B with reward reflected)

### N4 — 라이트 루틴 · `pd_bonus_noti_count`

**Headline card:** `첫 레슨 혜택이 지급되었어요`

**Body:**
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

**Button:** same as 무제한.

---

## N5 — 혜택 기간 연장 안내 (initial window expired → extended window opens)

**Trigger:** the extension cron at the moment the initial deadline passes (end of `purchase_day + 2` in the snapshotted timezone), only if bonus is not yet awarded and not yet booked. Fires immediately, then schedules N6 (D-1) and N7 (T-6) for the extended window.

### N5 — 무제한 · `pd_bonus_unlim_bd4`

**Headline card:** `첫 레슨 혜택 기간 연장안내`

**Body:**
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

**Button (single):** `🔥지금 첫 레슨 예약하기` → `{moHomeLink}` / `{pcHomeLink}` (Home State A with refreshed toast)

### N5 — 라이트 루틴 · `pd_bonus_count_bd4`

**Headline card:** `첫 레슨 혜택 기간 연장안내`

**Body:**
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

**Button:** same as 무제한.

---

## N6 — 혜택 마감 D-1 (2차 window, not yet booked)

**Trigger:** scheduled at the moment N5 fires. Sends at 9am local on the morning before the **extended** deadline day (`purchase_day + 6`). Suppressed if already booked, awarded, or forfeited.

**Sending strategy:** same `scheduleAt` / `uniqueKey` pattern as N3.

### N6 — 무제한 · `pd_bonus_2_unlim_bd1`

**Headline card:** `첫 레슨 혜택 소멸 1일 전 알림`

**Body:**
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

**Button (single):** `🔥일단 레슨 예약` → `{moHomeLink}` / `{pcHomeLink}`

### N6 — 라이트 루틴 · `pd_bonus_2_count_bd1`

**Headline card:** `첫 레슨 혜택 소멸 1일 전 알림`

**Body:**
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

**Button:** same as 무제한.

---

## N7 — 혜택 마감 T-6 (2차 window, 6 hours before final deadline) — **NEW**

**Purpose:** a last-chance nudge 6 hours before the extended deadline expires. Added to the funnel to capture users who saw N5 + N6 but still haven't booked as the clock runs out.

**Trigger:** scheduled at the moment N5 fires (same entry point as N6). Computed send time = `extended_deadline.minusHours(6)`, rendered in the snapshotted timezone as `yyyy-MM-dd HH:mm`. Suppressed if already booked, awarded, or forfeited.

**Sending strategy:** same `scheduleAt` / `uniqueKey` pattern as N3 and N6. Cron job or scheduled notification producer should put the computed UTC-wall-clock time into `copyMap["scheduleAt"]`.

### N7 — 무제한 · `pd_bonus_2_unlim_h6`

**Headline card:** `첫 레슨 혜택 소멸 6시간 전 알림`

**Body:**
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

**Button (single):** `🔥당장 레슨 예약` → `{moHomeLink}` / `{pcHomeLink}`

### N7 — 라이트 루틴 · `pd_bonus_2_count_h6`

**Headline card:** `첫 레슨 혜택 소멸 6시간 전 알림`

**Body:**
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

**Button:** same as 무제한.

---

## Backend implementation notes

All backend references are to `podo-backend`.

### 1. Register the template codes

Each of the 13 codes below needs an entry in **`ToastTemplateCode.java`** (`applications/log/enums/`):

```
pd_bonus_reg_unlim, pd_bonus_reg_count,
pd_reg_book_all_now,
pd_bonus_unlim_bd1, pd_bonus_count_bd1,
pd_bonus_noti_unlim, pd_bonus_noti_count,
pd_bonus_unlim_bd4, pd_bonus_count_bd4,
pd_bonus_2_unlim_bd1, pd_bonus_2_count_bd1,
pd_bonus_2_unlim_h6, pd_bonus_2_count_h6,
```

Entries can be declared as **bare** (no explicit param list — variable set is enforced by the DB row) or with an explicit param list matching the existing style (e.g. `pd_mkt_reg_remind_1(...)`). Follow the existing convention for scheduled templates: include `"reservedSendDatetime"` in the param list for N3 / N5 / N6 / N7 so `ParamBuilder` validates the scheduled-send call sites.

For scheduled templates (N3/N6/N7) that live inside the new bonus-extension job, also add uppercase enum entries to **`NotificationCode.java`** (`applications/notification/enums/`) if they are dispatched through the `PaymentGateway.sendScheduledNotifications` pattern. N1/N2/N4/N5 only need `ToastTemplateCode` because they fire from discrete call sites.

### 2. Create the DB rows in `notification_message`

One row per template code, with:
- `message_code` = lowercase code (e.g. `pd_bonus_2_unlim_h6`)
- `notification_category = 'KAKAO'`
- `message_title` = the headline-card text (e.g. `첫 레슨 혜택 소멸 6시간 전 알림`)
- `message_content` = the body text exactly as above, with `${varName}` placeholders (the PRD uses `{varName}` for readability; the stored template must use `${varName}` or `#{varName}` — see `NotificationService.VARIABLE_PATTERN`)
- `use_yn = 'Y'`
- `additional_data` = JSON with any default extras (button URLs are built at call-site, not stored here)

### 3. Template selection — N1 vs N2 vs legacy fallback

Modify `PodoScheduleServiceImplV2.book()` at the `regularCnt == 0` branch (`PodoScheduleServiceImplV2.java:1106-1112`):

```java
// Pseudocode — insert before the existing infinity/weekly routing
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
        templateCode = "PD_REG_BOOK_ALL_NOW";  // single template, both plan types
    }
} else if (ticket.getOriginCount().equals(999)) {
    templateCode = "PD_REG_INFINITY_2";      // legacy fallback
} else {
    templateCode = "PD_REG_WEEKLYCLASS_2";   // legacy fallback
}
```

N1 and N2 both need `extras["subjectName"]`, `extras["classDatetime"]`, `extras["Lessonterm"]`, `extras["langtype"]`. N1 additionally needs `extras["rewardDays"]` (both plans) and `extras["rewardCount"]` (라이트 루틴 only) — read these from the `purchase_bonus` row, NOT recomputed from the subscribe config.

### 4. Build `moHomeLink` / `pcHomeLink` / `moPrestudyLink` / `pcPrestudyLink`

Reuse the existing auth-wrap pattern from `PodoScheduleServiceImplV2.book()` (lines 1131–1158):

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

For prestudy links (N1, N2), substitute `destination=PRESTUDY&classId={bookedLessonId}` in the inner URL, encode, then wrap the same way. The app side must resolve these destination strings to the right route.

### 5. Schedule N3 / N5 / N6 / N7

Follow the pattern in `PaymentGateway.sendScheduledNotifications` (`PaymentGateway.java:1889-1946`):

```java
Map<String, Object> copyMap = new HashMap<>();
copyMap.put("scheduleAt", sendAt.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")));
copyMap.put("uniqueKey", String.format("%s-%s", userId, templateCode));
notificationService.makeAndSend(templateCode, userId, copyMap, userDto, subscribeDto, extras);
```

Concrete send times:

| Template | When scheduled | `scheduleAt` value |
|---|---|---|
| N3 (`*_bd1`) | At purchase time (or at `purchase_bonus` creation) | 9:00 local on `purchase_day + 1` |
| N5 (`*_bd4`) | Fires immediately when extension cron triggers | not scheduled — sent live |
| N6 (`*_2_*_bd1`) | At extension-job run (same call site as N5) | 9:00 local on `purchase_day + 6` |
| N7 (`*_2_*_h6`) | At extension-job run (same call site as N5) | `extended_deadline.minusHours(6)` in snapshot timezone |

All times format as `yyyy-MM-dd HH:mm`, computed against the purchase's snapshotted timezone (NOT the device's current timezone — see `PRD.md` "Timezone source of truth").

### 6. Cancellation on book / award / forfeit

Add the new scheduled template codes (uppercase form) to `AFTER_BOOK_DISABLE_TARGETS` in `PodoScheduleServiceImplV2.java:142-156` so they're killed when the user books:

```java
private final static List<String> AFTER_BOOK_DISABLE_TARGETS = List.of(
    // ...existing entries...
    "PD_BONUS_UNLIM_BD1",  "PD_BONUS_COUNT_BD1",          // N3
    "PD_BONUS_UNLIM_BD4",  "PD_BONUS_COUNT_BD4",          // N5 (defensive — N5 should already have fired)
    "PD_BONUS_2_UNLIM_BD1","PD_BONUS_2_COUNT_BD1",        // N6
    "PD_BONUS_2_UNLIM_H6", "PD_BONUS_2_COUNT_H6"          // N7
);
```

Also add the lowercase forms to `AlimsEventHandler.AFTER_BOOK_DISABLE_TARGETS` at `applications/log/event/AlimsEventHandler.java:34-50` if the event-handler path is used for this booking.

On **bonus award**, the award service should also cancel any still-pending N3/N5/N6/N7 via `notificationService.disableFutureAlim(templateCode, userId + "-" + templateCode)` — belt-and-suspenders, since the book-time cancellation should already have happened.

On **extended-window forfeit** (end of `purchase_day + 7` passes without completion), cancel N7 if for some reason it's still pending.

### 7. Idempotency

- N1 / N2 fire once per booking (the `regularCnt == 0` branch only runs for the first regular lesson).
- N3 / N6 / N7 use `uniqueKey = "{userId}-{TEMPLATE_CODE}"` — the reserved-alim queue de-dupes on this key, so re-scheduling is safe.
- N4 fires exactly once per `purchase_bonus` — the award service's existing idempotency on `purchase_bonus.awarded_at IS NOT NULL` guards it.
- N5 fires exactly once per `purchase_bonus` — the extension job's one-shot guard (`extended_at IS NULL`) is the gate.

---

## Audit trail / source info

- Figma canvas: `결제 후 첫 레슨 유도_260414` (designed 2026-04-14)
- Figma file key: `ApQyvuzXNHMw1tlARPZIJq`
- Figma node (overview): `445:46`
- Per-template section nodes: `540:9` (N1), `540:509` (N2), `540:106` (N3), `540:351` (N4), `540:430` (N5), `540:189` (N6), `540:270` (N7)

If copy or variables change in Figma, update this file and the corresponding `notification_message` DB rows — the code path doesn't need to change as long as the variable names stay stable.
