# PRD: 지연 노출 NPS 프롬프트 (다음 앱 포그라운드 전환 시 NPS 표시)

## 문제점

현재 NPS는 사용자가 예정된 수업 종료 시간 **이후에** 강의실 페이지에서 인앱 "나가기" 버튼을 클릭할 때만 실행됩니다. 이것이 사용자를 `/review-complete`로 이동시키는 유일한 경로입니다.

최근 14일간의 측정 결과:

- **16,778건의 실제 수업** (학생과 튜터 모두 화상 회의에 참여함)
- **1,248건(~7.4%)**만이 `/review-complete` 페이지에 도달함
- **889건(~5.3%)**만이 NPS 평점을 제출함

퍼널(Funnel)의 이탈은 설문조사 화면 자체가 아니라 그 **이전에** 발생합니다. `/review-complete`에 도달한 사용자 중 약 75%가 평점을 제출합니다 (해당 화면은 정상적으로 작동함).

가장 큰 누수(14일간 약 13,020개 세션, 전체 실제 수업의 약 78%)는 **수업 종료 시점이나 그 이후에 강의실을 떠났지만 "나가기" 버튼을 누르지 않은** 사용자들입니다. 이들은 앱을 종료했거나, OS 뒤로가기 제스처를 사용했거나, 다른 앱을 포그라운드로 전환했거나, iframe이 세션을 자체적으로 종료하도록 두었습니다. 이들은 다음에 앱을 실행할 때 `/home`(또는 다른 페이지)에 나타납니다.

이 PRD는 이러한 사용자 집단을 포착하는 "지연 노출 NPS 프롬프트"에 대해 설명합니다. 즉, 사용자가 앱을 다시 열거나 앱 내를 탐색할 때 방금 참석한 수업에 대한 NPS를 표시합니다.

## 목표

다음과 같은 상황을 피하면서 2주마다 발생하는 약 13,020건의 누락된 NPS 기회 대부분을 회수합니다:

- 실제 수업에 참석하지 않은 사용자에게 NPS 표시
- 동일한 수업에 대해 NPS를 여러 번 표시
- 현재 다른 수업을 듣고 있는 사용자의 방해
- 결제, 로그인, 온보딩 또는 기타 마찰이 큰 플로우의 방해

목표: NPS 도달률을 실제 수업의 약 7%에서 50% 이상으로 끌어올리기 (7배 향상).

## 비목표 (제외 대상)

- NPS 양식 자체 변경 (평점 UI, 이유 등 — 현재 상태 유지)
- 푸시 또는 알림톡을 통한 별도의 "나중에 평가하기" 알림 추가 (이는 다른 방식의 레버임)
- AI 캐릭터 채팅 레슨, 예습 세션(prestudy) 또는 다시보기에 대한 NPS 표시
- 과거 수업 데이터 소급 적용 (이 기능이 배포된 시점 이후의 수업만 대상)

## 현재 NPS 작동 방식 (현행)

참조: `apps/web/src/views/class-room/view.tsx:484-502`, `apps/web/src/views/lesson-review-complete/view.tsx`, `src/main/java/com/speaking/podo/applications/podo/nps/usecase/NpsService.java`.

1. 사용자가 수업을 마치고 "나가기"를 클릭함
2. 클라이언트가 `isClassEnded = type === 'CLASS' && now >= unix_class_end_datetime`을 확인함
3. true인 경우 → `/lessons/classroom/{classID}/review-complete`로 라우팅함
4. 해당 페이지는 2초 지연 후 `NpsSurveyFlow`를 표시함 (`tbd_260219_nps_inapp` 플래그로 제어, 현재 100% 배포됨)
5. 사용자가 평가함 → `POST /api/v1/lesson-review/nps` 호출 → 백엔드는 `(classId, studentId)`를 키로 하여 `NpsResponse` 행을 저장함
6. **백엔드는 이미 고유성을 강제하고 있음**: 해당 `(classId, studentId)`에 대한 행이 이미 존재하면 `NpsService.submit()`이 오류를 발생시킴. 즉, 중복 방지는 API 수준에서 해결되었으며, 클라이언트는 사용자가 이미 본 화면으로 괴롭히는 것만 피하면 됨.

현재 "사용자가 NPS를 보았지만 건너뛰었음"에 대한 서버 측 기록은 없으며, ClickHouse 이벤트에만 존재합니다. 이를 추가해야 합니다(아래 "백엔드 변경 사항" 참조).

## 수업 수명주기 컨텍스트 (트리거 타이밍과 관련됨)

최근 14일간 완료된 PODO 수업의 `podo_mysql.GT_CLASS` 분석 결과:

| 필드 | 동작 |
|---|---|
| `CLASS_STATE = 'FINISH'` | 튜터 앱에서 튜터가 수업 완료를 표시할 때 설정됨. **중앙값은 예정된 종료 1분 후. 평균은 약 9분 후.** 드물게 몇 시간까지 이어지는 롱테일이 존재함. |
| `COMP_DATETIME` | 튜터 완료 타임스탬프. `FINISH` 상태인 수업의 약 99%에 채워짐. |
| `CLASS_STATE = NULL` | 주로 예정되어 있거나 취소된 수업. |
| `CLASS_STATE = 'PREFINISH'` | 관리자 전용의 드문 중간 상태 (전체 수업의 약 0.3%). |
| `CANCEL_AT IS NOT NULL` | 수업이 취소됨. NPS가 트리거되어서는 안 됨. |
| `NOSHOW_DATETIME IS NOT NULL` | 학생 또는 튜터의 노쇼(No-show). NPS가 트리거되어서는 안 됨. |

**트리거 게이팅을 위한 핵심 시사점:** 만약 `CLASS_STATE = 'FINISH'`를 기다리게 되면, 학생이 수업을 마치고 30초 이내에 앱을 포그라운드로 전환했는데 튜터는 아직 "완료"를 누르지 않은 경우(**가장 빈번한(중앙값) 케이스**)를 놓치게 됩니다. 따라서 `FINISH`를 유일한 게이트로 사용할 수 없습니다. 대신 예정된 종료 시간 + 유예 시간을 사용하고, `CLASS_STATE`는 *부정적인* 게이트로만 사용해야 합니다(명시적으로 CANCEL/NOSHOW인 경우 건너뜀).

## 적격성 — 수업이 "NPS 대기 중(pending NPS)"인 경우

다음 조건이 **모두** 참인 경우 해당 수업은 학생에게 "NPS 대기 중"으로 간주됩니다.

1. **예습이나 AI가 아닌 실제 수업**: `CLASS_TYPE = 'PODO'` 및 `IS_PRESTUDY != 'Y'`
2. **학생이 해당 수업의 소유자**: `STUDENT_USER_ID = current user`
3. **수업의 예정된 종료 시간이 지남**:  
   `now >= class_end_datetime`  
   추가 유예 버퍼 없음. "강의실 URL에 표시 금지" 억제 규칙이 이미 수업 중 프롬프트를 방지하며, 현행 NPS 경로는 튜터가 시간을 약간 초과하는 경우를 처리함. 여기에 버퍼를 추가하면 이미 떠난 사용자에게 프롬프트를 지연시키거나(일찍 끝나는 경우) 아예 놓치게 될 뿐임.
4. **수업의 예정된 종료 시간이 최근 24시간 이내임**:  
   `now <= class_end_datetime + 24h`  
   24시간이 지나면 평점은 의미가 퇴색되고 짜증을 유발할 가능성이 높음.
5. **수업이 취소되거나 노쇼로 표시되지 않음**:  
   `CANCEL_AT IS NULL AND NOSHOW_DATETIME IS NULL AND CLASS_STATE NOT IN ('CANCEL', 'CANCEL_PAID', 'CANCEL_NOSHOW_T', 'NOSHOW_S', 'NOSHOW_BOTH')`
6. **학생이 실제로 참석함**: 최소한 학생이 이 수업의 화상 회의에 참여했어야 함. 구체적으로 레슨 시간 내에 이 수업과 연결된 `meet_connected` (또는 더 강력하게: 카운트 ≥ 2인 `meet_participant_joined`) ClickHouse 이벤트가 존재해야 함.  
   *추가 목표(Stretch):* 참석 신호를 사용할 수 없는 경우(이벤트 손실 등), "튜터가 수업을 `CLASS_STATE = 'FINISH'`로 표시함(참석을 암시함)"으로 대체함. 두 신호가 모두 없으면 NPS를 표시하지 **않음** — 참석하지 않은 사람에게 묻는 것보다 놓치는 것이 나음.
7. **이전 NPS 제출 없음**: `(class_id, student_id)`에 대한 `nps_response` 행이 없음.
8. **이전에 건너뛰지 않음**: `(class_id, student_id)`에 대한 `nps_skip` 행이 없음 (새 테이블 — "백엔드 변경 사항" 참조).

## 사용자 여정 (User Journeys)

### 여정 1 — "수업 직후 앱 종료" (가장 지배적인 케이스)

1. 학생이 25분 정규 수업을 마침. 튜터가 작별 인사를 함. 학생이 메시지 앱으로 전환하거나 브라우저 탭을 백그라운드로 내림.
2. 약 10분 후 학생이 내일의 예약을 확인하기 위해 PODO 앱을 엶.
3. 앱이 `/home`을 로드함. 홈 인사말을 렌더링하기 전에 앱이 `GET /api/v2/lecture/podo/getPendingNps`를 호출함.
4. 응답에 가장 최근의 대기 중인 수업(방금 마친 수업)이 포함됨.
5. 클라이언트가 `/lessons/classroom/{classId}/review-complete?source=deferred`로 라우팅함 — 현재와 동일한 NPS 플로우 컴포넌트.
6. 학생이 평가함 → 제출됨 → `/home`으로 돌아감.

### 여정 2 — "안드로이드 하드웨어 뒤로가기 버튼을 사용하여 수업에서 나감"

1. 강의실에 있는 학생이 "나가기" 대신 안드로이드 뒤로가기 버튼을 누름.
2. 웹뷰는 강의실 URL에 머무름 (`useBackButtonClose` 훅은 "한 번 더 누르면 종료됩니다"라는 토스트만 표시함 — `apps/native/src/shared/hooks/use-back-button-close.ts` 참조).
3. 학생이 포기하고 앱 전환기를 통해 앱을 종료함.
4. 다음에 앱을 열 때 여정 1과 동일하게 처리됨.

(별도의, 더 적극적인 수정 사항으로 보조 레버인 "강의실 내 안드로이드 뒤로가기 하이재킹" 참조. 이 PRD는 하드웨어 뒤로가기 동작이 현재 상태를 유지한다고 가정함.)

### 여정 3 — "연속된 수업 (Back-to-back)"

1. 학생이 09:25에 수업 A를 마치고, 09:30에 수업 B가 있음.
2. 학생이 바로 `/home`으로 이동한 다음 `/lessons/classroom/{B}`로 이동하여 수업 B에 입장함.
3. `getPendingNps`는 수업 A를 반환함. **클라이언트는 사용자가 강의실 URL에 있거나 강의실에 입장하려는 상황일 때 프롬프트를 억제해야 함.**
4. 학생이 09:55에 수업 B를 마침. 앱을 종료함.
5. 10:30에 학생이 앱을 다시 엶. `getPendingNps`는 수업 B를 반환함 (최신순; 수업 A도 대기 중).
6. 클라이언트가 수업 B에 대한 NPS를 표시함.
7. 학생이 제출하고 `/home`으로 돌아감. 앱이 즉시 `getPendingNps`를 다시 확인함. 이제 수업 A를 반환함.
8. **제한(Cap):** 앱 세션당 **최대 하나**의 지연 노출 NPS만 표시함. 따라서 수업 A는 즉시 표시되지 **않고**, 대기 상태로 유지되며 다음 앱 열기/다음 포그라운드 전환 시 표시됨. 설문조사 두 개가 연달아 나오는 것은 스팸처럼 느껴지기 때문임.

### 여정 4 — "평가 후 앱을 다시 엶"

1. 학생이 막 수업을 마치고, "나가기"를 올바르게 클릭하여 기존 현행 경로를 통해 NPS를 평가함.
2. 10분 후 앱을 다시 엶.
3. 해당 수업에 대해 `getPendingNps`는 아무것도 반환하지 않음 (`nps_response` 행이 이미 존재함).
4. 프롬프트 없음. 예상대로 조용하게 동작함.

### 여정 5 — "NPS를 보고 건너뛰기를 누른 후 앱을 다시 엶"

1. 학생이 수업을 마치고, "나가기"를 클릭하여 `/review-complete`에 도달한 뒤 건너뛰기(Skip)를 누름.
2. 클라이언트가 `nps_survey_skipped` 이벤트를 발생시키고 `nps_skip` 행을 기록하는 `POST /api/v1/lesson-review/nps/skip` (신규 엔드포인트)를 호출함.
3. 나중에 앱을 다시 엶.
4. 해당 수업에 대해 `getPendingNps`는 아무것도 반환하지 않음 (건너뛰기 행이 차단함).
5. 프롬프트 없음. 사용자가 기회를 얻었으나 거절한 것임.

### 여정 6 — "사후에 튜터가 수업을 노쇼로 표시함"

1. 학생이 강의실을 잠깐 열었지만 말하지 않음 (예: 카메라 끄기, 오디오 없음). 기술적으로는 수업이 진행됨.
2. 튜터가 나중에 튜터 앱에서 수업을 `NOSHOW_S`로 표시함.
3. 학생이 10:30에 앱을 엶 — 그러나 `getPendingNps`가 튜터가 노쇼를 표시하기 **전에** 호출되므로 여전히 이 수업을 반환할 수 있음.
4. **트레이드오프:** 응답은 API 호출 시점에 계산됨. 미래를 예측할 수는 없음. 튜터가 아직 노쇼를 표시하지 않았다면 학생은 프롬프트를 받음. 튜터가 나중에 표시하더라도 학생은 이미 평가를 마친 상태임 — 백엔드는 새로운 데이터 삽입을 거부하겠지만(평가가 이미 존재함) `npsResponse` 행은 유지됨. 우리는 이를 수용함 — 노쇼 수업에 대한 몇 개의 무의미한 평점은 허용 가능한 노이즈이며, 이를 굳이 지우려 하지 않음.
5. **완화책:** 프롬프트를 표시하기 전에 참석 신호(적격성 규칙 6번)를 요구함. 학생에 대한 `meet_connected` 이벤트가 0개인 수업은 아직 노쇼로 표시되지 않았더라도 NPS 대상으로 제공되지 않음.

### 여정 7 — "튜터가 수업 완료를 표시하는 데 30분이 걸림"

1. 09:00–09:25 예정된 수업. 실제 수업은 약 09:24에 끝남. 학생이 09:24:30(예정된 종료 전)에 "나가기"를 클릭함 → 기존 `isClassEnded` 게이트를 통해 `/home`으로 라우팅됨 (현행 경로를 통한 NPS 없음).
2. 학생이 앱을 백그라운드로 내림. 튜터는 09:55까지 완료를 표시하지 않음.
3. 학생이 09:35에 앱을 포그라운드로 전환함. `getPendingNps`가 실행됨:
   - 현재 (09:35) >= scheduled_end (09:25)? 예.
   - class_state가 취소/노쇼 집합에 속하지 않음? 예 (여전히 RESERVED 또는 null임).
   - 참석 신호 존재 (학생이 화상 회의에 참여함)? 예.
   - 이전 NPS 없음, 이전 건너뛰기 없음? 맞음.
   - **이 수업을 대기 중인 상태로 반환함.**
4. 학생에게 프롬프트가 표시되고, 평가하고, 제출함.
5. 튜터가 09:55에 완료를 표시함. NPS가 이미 존재함. 충돌 없음.

이것이 우리가 원하는 동작입니다 — 튜터를 기다리지 **않습니다**.

### 여정 8 — "수업이 실제로 시작되지 않음 (튜터 노쇼)"

1. 09:00–09:25 예정된 수업. 학생이 09:00에 참여함. 튜터는 참여하지 않음.
2. 학생이 10분을 기다리다 09:10에 포기함. `meet_participant_joined ≥ 2` 이벤트가 발생하지 않음.
3. 학생이 11:00에 앱을 엶.
4. `getPendingNps`가 실행됨. **참석 규칙 6번 실패** — 실제 수업이 진행되었다는 신호가 없음 (튜터가 참여하지 않음). 대기 중인 수업 없음을 반환함.
5. 프롬프트 없음. (튜터는 결국 노쇼로 표시되며 별도의 플로우에서 환불/크레딧을 처리함.)

### 여정 9 — "NPS 제출 중 네트워크 상태가 좋지 않음"

1. 학생이 수업을 마치고, 앱을 포그라운드로 전환하여, NPS를 보고, 8점을 평가하고, 제출을 누름.
2. POST 실패 (네트워크 끊김). 오류 토스트가 표시됨 ("제출에 실패했어요. 다시 시도해 주세요.").
3. 학생이 답답함을 느끼며 앱을 백그라운드로 내림.
4. 나중에 앱을 다시 엶. `getPendingNps`가 실행됨.
5. 백엔드에 아직 `nps_response` 행이 없음 (POST 실패함). 수업을 다시 대기 상태로 반환함.
6. 학생에게 프롬프트가 다시 표시됨. **이것이 올바른 동작입니다** — 학생은 평가하려 했으나 하지 못한 상태이기 때문입니다.

### 여정 10 — "사용자가 결제 / 온보딩 / 기타 중요한 플로우의 중간에 있음"

1. 학생이 구독 구매를 완료하기 위해 앱을 엶.
2. `/subscribes/checkout`으로 이동함.
3. 우리는 NPS 프롬프트로 인해 이 과정이 방해받는 것을 원치 **않음**.
4. **억제 규칙:** 지연 노출 프롬프트는 안전한 내비게이션 대상의 정의된 허용 목록(`/home`, `/reservation`, `/lessons`(목록 보기만 해당), `/my-podo`)에서만 트리거됨. `/subscribes/*`, `/login`, `/onboarding`, `/lessons/classroom/*`, `/payment/*` 또는 모달이 활성화된 상태에서는 트리거되지 않음.

## 기술 설계

### 백엔드 변경 사항

#### 1. 신규 엔드포인트: `GET /api/v2/lecture/podo/getPendingNps`

**인증(Auth):** 표준 Bearer 토큰.

**쿼리 로직:**

```sql
SELECT 
  c.ID                       AS class_id,
  c.TEACHER_USER_ID          AS tutor_id,
  c.CLASS_DATE,
  c.CLASS_END_TIME,
  c.unix_class_end_datetime  -- 또는 서버 측에서 계산
FROM GT_CLASS c
WHERE c.STUDENT_USER_ID = :studentId
  AND c.CLASS_TYPE = 'PODO'
  AND COALESCE(c.IS_PRESTUDY, 'N') != 'Y'
  AND c.CANCEL_AT IS NULL
  AND c.NOSHOW_DATETIME IS NULL
  AND COALESCE(c.CLASS_STATE, 'OK') NOT IN ('CANCEL','CANCEL_PAID','CANCEL_NOSHOW_T','NOSHOW_S','NOSHOW_BOTH')
  AND TIMESTAMP(c.CLASS_DATE, c.CLASS_END_TIME) <= NOW()
  AND TIMESTAMP(c.CLASS_DATE, c.CLASS_END_TIME) >= NOW() - INTERVAL 24 HOUR
  AND NOT EXISTS (SELECT 1 FROM nps_response  WHERE class_id = c.ID AND student_id = :studentId)
  AND NOT EXISTS (SELECT 1 FROM nps_skip      WHERE class_id = c.ID AND student_id = :studentId)
  AND EXISTS  (
    -- ClickHouse 미러링 출석 테이블 또는 기존 FINISH 상태를 통한 출석 확인
    /* 아래 "참석 신호" 참조 */
  )
ORDER BY TIMESTAMP(c.CLASS_DATE, c.CLASS_END_TIME) DESC
LIMIT 1;
```

**응답:**

```json
{
  "pending": true,
  "class_id": 2607511,
  "tutor_id": 2930,
  "tutor_name": "Alice",
  "class_end_datetime_unix": 1745123456
}
```

또는 적격 항목이 없으면 `{ "pending": false }`.

레이턴시 예산: < 100ms. `(STUDENT_USER_ID, CLASS_DATE)` 인덱스가 이미 존재할 가능성이 높음. 배포 전 확인 필요.

**참석 신호** — 다음 중 하나를 선택:
- (선호) `meet_participant_joined` 이벤트의 존재 여부를 이벤트 컨슈머가 업데이트하는 작은 `class_attendance(class_id, has_tutor_joined_at)` 테이블에 미러링함. 조회 비용 저렴함.
- (대체안) `CLASS_STATE = 'FINISH'` 사용. "튜터가 아직 완료를 표시하지 않은" 사용자 집단을 놓치지만 안전하며 신규 인프라가 필요 없음.

처음에는 대체안(FINISH만 사용)으로 출시하고, 보수적인 게이트로 인해 얼마나 많은 사용자를 놓치는지 측정한 후 v2에서 출석 테이블로 마이그레이션할 것을 권장.

#### 2. 신규 엔드포인트: `POST /api/v1/lesson-review/nps/skip`

본문: `{ classId: number }`. 새 `nps_skip` 테이블에 행을 기록함.

```
nps_skip
  id          BIGINT PK
  class_id    BIGINT (인덱싱됨)
  student_id  INT
  created_at  DATETIME
  UNIQUE (class_id, student_id)
```

멱등적(Idempotent) — 동일한 (class, student)에 대한 반복 호출은 no-op.

이는 오늘날 "건너뛰었음"이 ClickHouse 이벤트에만 존재하는데 이는 "다시 프롬프트해야 하나?"를 결정하기에 너무 손실이 크기 때문에 필요함.

### 클라이언트 변경 사항

#### 웹 (`apps/web`)

**신규 훅:** `useDeferredNpsPrompt()`

- `features/lesson-review/hooks/use-deferred-nps-prompt.ts`에 위치
- 인증된 앱 셸인 `(internal)` 라우트의 루트 레이아웃에 마운트됨
- 마운트 시 그리고 안전 내비게이션 허용 목록 내 경로로 라우트가 변경될 때마다 `getPendingNps`를 디바운스 호출 (60초당 최대 1회)
- 대기 중인 수업이 반환되고 이번 앱 세션에서 아직 지연 노출 프롬프트를 표시하지 않은 경우, `/lessons/classroom/{classId}/review-complete?source=deferred`로 라우팅함
- 사용자가 해당 페이지에서 제출 또는 건너뛰기를 한 후, 다음 앱 열기까지 다시 프롬프트하지 않도록 세션 범위 플래그 `__deferred_nps_shown_this_session = true`를 설정함

**`NpsSurveyFlow` 수정** (`features/lesson-review/ui/nps-survey/nps-survey-flow.tsx`)

- 현재 `handleSkip`은 `nps_survey_skipped` 이벤트를 발생시키고 페이지를 이동함. 추가: 서버가 거부 사실을 기록하도록 `POST /api/v1/lesson-review/nps/skip`도 호출함.
- 이는 현행 경로(나가기 → /review-complete → 건너뛰기) 와 지연 노출 경로 모두에 적용됨. 두 경우 모두 영구적으로 "건너뜀(skipped)" 상태가 되어야 함.

**`/lessons/classroom/[classID]/review-complete/page.tsx` 수정**

- `?source=deferred` 쿼리 파라미터를 읽어 분석 태깅을 위해 `NpsSurveyFlow`에 전달함 (현행 vs 지연 제출률을 비교할 수 있도록).
- 그 외 동작은 동일함.

**`/views/class-room/view.tsx` 수정**

- 이 PRD 자체로는 변경이 필요하지 않음. 기존 `goBackPage()` 경로는 그대로 유지됨. 일찍 떠나는 사용자(다른 레버에서 다룬 ~13% 집단)는 다음 포그라운드 전환 시 지연 노출 프롬프트로 포착됨.
- (전체 커버리지를 원한다면 레버 1 — `isClassEnded` 게이트 제거 — 와 결합 가능.)

#### 네이티브 (`apps/native`)

- 네이티브 셸은 웹을 WebView로 감쌈. 대부분의 작업은 웹 측에서 진행됨.
- `useAppState` 훅(`apps/native/src/shared/hooks/use-app-state.ts`)이 이미 포그라운드/백그라운드를 감지함. 추가: `background` → `active` 전환 시 WebView에 `window.postMessage({ type: 'app-foregrounded' })`를 주입하여 라우트 변경이 없더라도 웹 레이어가 `getPendingNps`를 다시 실행할 수 있도록 함.
- 웹 `useDeferredNpsPrompt` 훅은 라우트 변경 외에도 이 메시지를 수신함.

### 억제 규칙 (프롬프트가 표시되어서는 안 되는 경우)

트리거 확인 시점에 다음 중 어느 하나라도 참이면 지연 노출 프롬프트는 억제됨:

| 조건 | 사유 |
|---|---|
| 현재 경로가 `/lessons/classroom/{id}` 와 일치함 (`/review-complete` 접미사 없음) | 사용자가 수업 중이거나 입장하려 함. 방해 금지. |
| 현재 경로가 `/login`, `/onboarding/*`, `/payment/*`, `/subscribes/checkout/*` | 중요 전환 플로우. 방해 금지. |
| 모달/오버레이가 현재 열려 있음 (`overlay.isOpen()`) | 모달을 중첩하지 말 것. |
| 사용자가 이번 앱 세션에서 이미 지연 노출 NPS를 본 경우 | 세션당 1회 제한. |
| 사용자가 10분 내에 시작 예정인 수업을 가지고 있음 | 곧 준비 모드에 들어갈 예정. 방해 금지. 기존 `getNextLectureInfo` API 또는 캐시를 통해 확인. |
| `getPendingNps` 오류 발생 | 조용한 실패 — 설문조사를 위해 사용자 플로우를 절대 중단하지 말 것. |

### 빈도 제한 (Frequency caps)

- **앱 세션당**: 지연 노출 프롬프트 최대 1회
- **수업당**: 총 1회 프롬프트 (`nps_skip` 행 또는 `nps_response` 행에 의해 강제됨)
- **세션 간 사용자별**: 수업당 규칙 외에는 제한 없음. 사용자가 하루에 3개의 수업을 듣는다면, 3번의 별도 앱 열기에 걸쳐 합법적으로 3개의 지연 노출 프롬프트를 볼 수 있음.

### 분석 (신규 ClickHouse 이벤트)

- `nps_deferred_prompt_eligible` — `getPendingNps`가 수업을 반환할 때 클라이언트 측에서 발생함. 속성: `{ classId, tutorId, secondsSinceClassEnd, suppressedReason: null | "in_classroom" | "modal_open" | "checkout" | "session_cap" | "upcoming_class" }`
- `nps_deferred_prompt_shown` — 지연 노출 경로에서 사용자를 실제로 `/review-complete`로 라우팅했을 때 발생함. 속성: `{ classId, tutorId, secondsSinceClassEnd }`
- `nps_survey_viewed`, `nps_rating_submitted`, `nps_survey_skipped` — 이미 존재함. 진입 경로별로 비율을 분리할 수 있도록 `source: 'inflow' | 'deferred'` 속성 추가.

이를 통해 적격 집단 중 프롬프트를 받는 비율(eligible vs shown)과 제출하는 비율(shown vs submitted)을 진입 경로별로 측정할 수 있음.

## 롤아웃

1. **백엔드 먼저 배포**: `getPendingNps` 엔드포인트 + `nps_skip` 테이블 + skip 엔드포인트. `/home` API 예산 대비 성능 회귀가 없는지 확인. 중복 방지가 엔드 투 엔드로 작동하는지 확인.
2. **클라이언트는 피처 플래그 `tbd_260X_nps_deferred_prompt` 뒤에서 배포됨.**
3. **내부 QA**: 스테이지 환경에서 여정 1, 3, 4, 5, 7, 10을 수동으로 실행함.
4. **출시 시 플래그를 100%로 전환.** 단계적 램프 없음 — 이 기능은 저위험(파괴적 쓰기 없음, 서버 측 중복 방지, 핵심 플로우는 억제 규칙으로 보호됨)이며, 점진적 램프는 도달률 향상을 지연시킬 뿐임.
5. **출시 후 첫 24~48시간 모니터링** 항목:
   - 실제 수업 대비 설문 도달률 (목표: 50%+)
   - 지연 노출 vs 현행 프롬프트의 건너뛰기율 (지연 노출이 유의미하게 높으면 → 프롬프트가 거슬리는 것)
   - 지연 노출 vs 현행의 평균 평점 (유의미하게 다르면 → 자기선택 편향(self-selection) 이슈)
   - `/home` p95 레이턴시 (`getPendingNps` 예산 외 회귀 없음)
   - `getPendingNps` 및 `/nps/skip`의 오류율
6. **위 항목 중 하나라도 트립되면 플래그를 끄는 것으로 롤백.** 플래그가 단일 킬 스위치 — 코드 리버트 불필요. 이미 진행 중인 사용자도 다음 라우트 변경 시점부터 즉시 지연 노출 프롬프트가 중단됨. 백엔드 엔드포인트는 읽기 전용/멱등이므로 그대로 유지 가능하며 리버트 불필요.

## 미해결 질문 (Open Questions)

1. **결국 푸시 알림으로도 사용자를 포착해야 하는가** ("오늘 Alice 선생님과의 수업은 어떠셨나요?")? 이 PRD의 범위 외이지만 인앱 도달률이 정체될 경우 후속으로 고려할 가치가 있음.
2. **지연 노출 프롬프트가 현행 프롬프트와 다르게 보여야 하는가** (예: 사용자가 예상하지 않은 상태이므로 전체 화면 점유 대신 작은 모달)? v1에서는 **동일한 UI**를 권장 — 복잡성을 최소화하고 기존 플로우 컴포넌트를 재사용함. 건너뛰기율이 예상치 못하게 높으면 재평가.
3. **웹에서 수업을 들었지만 모바일 앱으로 나중에 여는 경우는 어떻게 되나요?** (또는 그 반대) `getPendingNps`는 서버 측이며 플랫폼에 무관하므로 별도 작업 없이 동작함.
4. **예정 종료 후 유예 기간이 필요한가?** 현재 설계는 아니오 — `now >= scheduled_end` 시점에 즉시 트리거. 출시 후 분석에서 (억제 규칙이 놓친 엣지 케이스로 인해 현행 경로와 경합하여) 사용자가 마무리하는 도중에 지연 프롬프트가 발생하는 경우가 드러나면 그때 작은 버퍼(30~60초)를 도입할 것. 선제적으로 추가하지 말 것.