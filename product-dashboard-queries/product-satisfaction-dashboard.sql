-- =====================================================================
-- 프로덕트 만족도 대시보드 (Product Satisfaction Dashboard)
-- =====================================================================
-- 모든 쿼리는 Metabase native SQL question으로 만든다.
-- 환불 관련 두 쿼리는 기존 모델 #1619 를 참조한다.
--   {{#1619-model-subscription-and-refund-state-add-purchases-within-3-days-of-refund}}
--
-- 검증 환경: gwatop (prod-metabase via MCP)
-- 검증 일자: 2026-04-29
-- =====================================================================


-- ─────────────────────────────────────────────────────────────────────
-- 1. 체험 퍼널 (예약률 / 완료률 / 결제 전환률)
-- ─────────────────────────────────────────────────────────────────────
-- 앵커: GT_CLASS_TICKET (EVENT_TYPE='PODO_TRIAL') = 체험권 발급 시점
--
-- 정의:
--   체험 예약률   = 실제 슬롯이 잡힌 체험권 / 발급된 체험권
--                   (= INVOICE_STATUS != 'CREATED' on the non-prestudy class row)
--                   * 실데이터 기준 99%대로 거의 모든 체험권이 슬롯과 함께 생성됨
--   체험 완료률   = COMPLETED 체험권 / 예약된 체험권
--   결제 전환률   = 체험 발급 후 60일내 유료 결제한 유저 수
--
-- 월별 트렌드용. 주별로 보려면 trial_week 컬럼으로 변경.
WITH trial_funnel AS (
  SELECT
    gct.ID                                         AS ticket_id,
    gct.USER_ID,
    DATE(gct.CREATE_DATETIME)                      AS ticket_date,
    DATE_FORMAT(gct.CREATE_DATETIME, '%Y-%m-01')   AS ticket_month,
    DATE_SUB(DATE(gct.CREATE_DATETIME),
             INTERVAL WEEKDAY(gct.CREATE_DATETIME) DAY) AS ticket_week,
    gct.LANG_TYPE,
    -- 슬롯이 실제로 잡힌 적이 있는가? (placeholder CREATED 상태가 아니면 예약된 것)
    (SELECT MAX(CASE WHEN gc.INVOICE_STATUS != 'CREATED' THEN 1 ELSE 0 END)
     FROM GT_CLASS gc
     WHERE gc.CLASS_TICKET_ID = gct.ID
       AND gc.IS_PRESTUDY = 'N')                   AS was_booked,
    -- 실제 수업이 완료된 적이 있는가?
    (SELECT MAX(CASE WHEN gc.INVOICE_STATUS = 'COMPLETED' THEN 1 ELSE 0 END)
     FROM GT_CLASS gc
     WHERE gc.CLASS_TICKET_ID = gct.ID
       AND gc.IS_PRESTUDY = 'N')                   AS was_completed,
    -- 체험 발급일로부터 60일내 유료 결제 (TRIAL/REFUND 제외)
    (SELECT MAX(1)
     FROM GT_PAYMENT_INFO gpi
     WHERE gpi.USER_UID  = gct.USER_ID
       AND gpi.CLASS_TYPE = 'PODO'
       AND gpi.EVENT_TYPE NOT IN ('PODO_CARD_TRIAL', 'PODO_REFUND', 'PODO_REFUND_PAY')
       AND gpi.STATUS = 'paid'
       AND gpi.PAID_AMOUNT > 0
       AND gpi.UPDATE_DATE >= gct.CREATE_DATETIME
       AND gpi.UPDATE_DATE <= DATE_ADD(gct.CREATE_DATETIME, INTERVAL 60 DAY)) AS paid_after_trial
  FROM GT_CLASS_TICKET gct
  WHERE gct.EVENT_TYPE     = 'PODO_TRIAL'
    AND gct.CURRICULUM_TYPE = 'TRIAL'
)
SELECT
  ticket_month                                                          AS `기준 월`,
  COUNT(*)                                                              AS `체험권 발급 수`,
  SUM(was_booked)                                                       AS `체험 예약 수`,
  SUM(was_completed)                                                    AS `체험 완료 수`,
  SUM(paid_after_trial)                                                 AS `체험 후 결제 수 (60일내)`,
  ROUND(SUM(was_booked)        / NULLIF(COUNT(*),0)         * 100, 2)   AS `체험 예약률 (%)`,
  ROUND(SUM(was_completed)     / NULLIF(SUM(was_booked),0)  * 100, 2)   AS `체험 완료률 (%)`,
  ROUND(SUM(paid_after_trial)  / NULLIF(SUM(was_completed),0) * 100, 2) AS `완료자 → 결제 전환률 (%)`,
  ROUND(SUM(paid_after_trial)  / NULLIF(COUNT(*),0)         * 100, 2)   AS `발급 → 결제 전환률 (%)`
FROM trial_funnel
WHERE ticket_date >= '2025-01-01'
GROUP BY ticket_month
ORDER BY ticket_month DESC;


-- ─────────────────────────────────────────────────────────────────────
-- 2. 환불 스냅샷 (구매 코호트 기준 - 환불 누적 / D7, D30, D60, D90)
-- ─────────────────────────────────────────────────────────────────────
-- 기존 환불 코호트 (refund-time 기준) 와 보완하는 view.
-- 구매 시점 기준으로 cohort를 묶고, 시간이 지나면서 누적 환불율이 어떻게 쌓이는지를 본다.
-- 모델 #1619 가 이미 3일내 재구매 환불 = "진짜 환불 아님" 처리를 해줘서 그대로 사용.
SELECT
  DATE_FORMAT(model.purchase_date, '%Y-%m-01')                         AS `구매 월 (스냅샷)`,
  COUNT(*)                                                             AS `구매 수`,
  SUM(model.total_paid_amount)                                         AS `구매 액`,

  SUM(CASE WHEN model.sub_status = 'REFUND' THEN 1 ELSE 0 END)         AS `누적 환불 수`,
  ROUND(SUM(CASE WHEN model.sub_status = 'REFUND' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100, 2)                                AS `누적 환불율 (%)`,

  -- D7 누적
  SUM(CASE WHEN model.sub_status='REFUND' AND model.refund_days <= 7  THEN 1 ELSE 0 END) AS `D7내 환불 수`,
  ROUND(SUM(CASE WHEN model.sub_status='REFUND' AND model.refund_days <= 7  THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100, 2)                                                  AS `D7 환불율 (%)`,

  -- D30 누적
  SUM(CASE WHEN model.sub_status='REFUND' AND model.refund_days <= 30 THEN 1 ELSE 0 END) AS `D30내 환불 수`,
  ROUND(SUM(CASE WHEN model.sub_status='REFUND' AND model.refund_days <= 30 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100, 2)                                                  AS `D30 환불율 (%)`,

  -- D60 누적
  SUM(CASE WHEN model.sub_status='REFUND' AND model.refund_days <= 60 THEN 1 ELSE 0 END) AS `D60내 환불 수`,
  ROUND(SUM(CASE WHEN model.sub_status='REFUND' AND model.refund_days <= 60 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100, 2)                                                  AS `D60 환불율 (%)`,

  -- D90 누적
  SUM(CASE WHEN model.sub_status='REFUND' AND model.refund_days <= 90 THEN 1 ELSE 0 END) AS `D90내 환불 수`,
  ROUND(SUM(CASE WHEN model.sub_status='REFUND' AND model.refund_days <= 90 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100, 2)                                                  AS `D90 환불율 (%)`

FROM {{#1619-model-subscription-and-refund-state-add-purchases-within-3-days-of-refund}} model
GROUP BY `구매 월 (스냅샷)`
ORDER BY `구매 월 (스냅샷)` DESC;


-- ─────────────────────────────────────────────────────────────────────
-- 3-A. 수업 빈도 세그먼트 - 스냅샷 (월별 액티브 유저 분포)
-- ─────────────────────────────────────────────────────────────────────
-- 매달말 시점에 액티브한 구독 유저 → 그 달의 완료 수업 수로 segment.
-- 0회 = 액티브한데 수업 안 한 유저 (잠재 환불/이탈 위험)
-- 1-3회 = 목표상 0%로 만들고 싶은 구간
-- 4-7, 8-11, 12+ = 정상/우수 구간
WITH active_user_month AS (
  SELECT DISTINCT
    gsm.user_id,
    months.m AS active_month
  FROM GT_SUBSCRIBE_MAPP gsm
  JOIN GT_SUBSCRIBE gs ON gs.id = gsm.subscribe_id
  -- 보고 싶은 월 리스트 (대시보드 운영 시 calendar 테이블이나 파라미터로 대체)
  JOIN (
    SELECT '2025-10-01' AS m UNION ALL SELECT '2025-11-01' UNION ALL SELECT '2025-12-01'
    UNION ALL SELECT '2026-01-01' UNION ALL SELECT '2026-02-01' UNION ALL SELECT '2026-03-01'
    UNION ALL SELECT '2026-04-01'
  ) months
    ON gsm.cre_datetime <  DATE_ADD(months.m, INTERVAL 1 MONTH)
   AND (gsm.cancel_at IS NULL OR gsm.cancel_at >= months.m)
   AND (gsm.end_date  IS NULL OR gsm.end_date  >= months.m)
  WHERE gs.payment_type NOT IN ('TRIAL', 'EXTEND', 'BONUS')
),
user_month_lessons AS (
  SELECT
    gc.STUDENT_USER_ID                          AS user_id,
    DATE_FORMAT(gc.CLASS_DATE, '%Y-%m-01')      AS lesson_month,
    COUNT(*)                                    AS lessons
  FROM GT_CLASS gc
  JOIN GT_CLASS_TICKET gct ON gct.ID = gc.CLASS_TICKET_ID
  WHERE gc.INVOICE_STATUS = 'COMPLETED'
    AND gc.IS_PRESTUDY    = 'N'
    AND gct.EVENT_TYPE   != 'PODO_TRIAL'
    AND gc.CLASS_DATE >= '2025-10-01'
  GROUP BY gc.STUDENT_USER_ID, lesson_month
),
joined AS (
  SELECT
    a.active_month,
    a.user_id,
    COALESCE(l.lessons, 0) AS lessons
  FROM active_user_month a
  LEFT JOIN user_month_lessons l
    ON l.user_id = a.user_id
   AND l.lesson_month = a.active_month
)
SELECT
  active_month                                                              AS `기준 월`,
  COUNT(*)                                                                  AS `액티브 유저 수`,
  SUM(CASE WHEN lessons =  0          THEN 1 ELSE 0 END)                    AS `0회`,
  SUM(CASE WHEN lessons BETWEEN 1 AND 3 THEN 1 ELSE 0 END)                  AS `1-3회 (목표=0)`,
  SUM(CASE WHEN lessons BETWEEN 4 AND 7 THEN 1 ELSE 0 END)                  AS `4-7회`,
  SUM(CASE WHEN lessons BETWEEN 8 AND 11 THEN 1 ELSE 0 END)                 AS `8-11회`,
  SUM(CASE WHEN lessons >= 12         THEN 1 ELSE 0 END)                    AS `12회+`,
  ROUND(SUM(CASE WHEN lessons = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2)   AS `0회 비율 (%)`,
  ROUND(SUM(CASE WHEN lessons BETWEEN 1 AND 3 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `1-3회 비율 (%) ★ 목표 0%`,
  ROUND(SUM(CASE WHEN lessons BETWEEN 4 AND 7 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `4-7회 비율 (%)`,
  ROUND(SUM(CASE WHEN lessons BETWEEN 8 AND 11 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `8-11회 비율 (%)`,
  ROUND(SUM(CASE WHEN lessons >= 12 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2)            AS `12회+ 비율 (%)`,
  ROUND(AVG(lessons), 2)                                                     AS `유저 평균 수업 수`
FROM joined
GROUP BY active_month
ORDER BY active_month DESC;


-- ─────────────────────────────────────────────────────────────────────
-- 3-B. 수업 빈도 세그먼트 - 코호트 (구매 후 첫 30일)
-- ─────────────────────────────────────────────────────────────────────
-- 구매월 cohort 기준으로 첫 구매 후 30일 동안의 수업 수를 segment.
-- 같은 segment 라도 신규 구매 cohort vs 전체 액티브 유저 (3-A) 가 다른 그림.
-- 예: 신규는 1-3회 비율이 ~25% 인데 액티브 전체는 ~15%, 0회까지 합치면 50%대 등.
SELECT
  cohort_month                                                                AS `구매 월 (코호트)`,
  COUNT(*)                                                                    AS `구매자 수`,
  SUM(CASE WHEN lessons = 0           THEN 1 ELSE 0 END)                      AS `0회`,
  SUM(CASE WHEN lessons BETWEEN 1 AND 3 THEN 1 ELSE 0 END)                    AS `1-3회 (목표=0)`,
  SUM(CASE WHEN lessons BETWEEN 4 AND 7 THEN 1 ELSE 0 END)                    AS `4-7회`,
  SUM(CASE WHEN lessons BETWEEN 8 AND 11 THEN 1 ELSE 0 END)                   AS `8-11회`,
  SUM(CASE WHEN lessons >= 12         THEN 1 ELSE 0 END)                      AS `12회+`,
  ROUND(SUM(CASE WHEN lessons = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2)     AS `0회 비율 (%)`,
  ROUND(SUM(CASE WHEN lessons BETWEEN 1 AND 3 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `1-3회 비율 (%) ★ 목표 0%`,
  ROUND(SUM(CASE WHEN lessons BETWEEN 4 AND 7 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `4-7회 비율 (%)`,
  ROUND(SUM(CASE WHEN lessons BETWEEN 8 AND 11 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `8-11회 비율 (%)`,
  ROUND(SUM(CASE WHEN lessons >= 12 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2)            AS `12회+ 비율 (%)`,
  ROUND(AVG(lessons), 2)                                                                AS `평균 수업 수 (30일)`
FROM (
  SELECT
    gsm.user_id,
    DATE_FORMAT(gsm.cre_datetime, '%Y-%m-01') AS cohort_month,
    -- 첫 구독 결제일 ~ +30일 동안의 완료 수업 수
    (SELECT COUNT(*)
     FROM GT_CLASS gc
     JOIN GT_CLASS_TICKET gct ON gct.ID = gc.CLASS_TICKET_ID
     WHERE gc.STUDENT_USER_ID = gsm.user_id
       AND gc.INVOICE_STATUS  = 'COMPLETED'
       AND gc.IS_PRESTUDY     = 'N'
       AND gct.EVENT_TYPE    != 'PODO_TRIAL'
       AND gc.CLASS_DATE     >= DATE(gsm.cre_datetime)
       AND gc.CLASS_DATE     <  DATE_ADD(DATE(gsm.cre_datetime), INTERVAL 30 DAY)) AS lessons
  FROM GT_SUBSCRIBE_MAPP gsm
  JOIN GT_SUBSCRIBE gs ON gs.id = gsm.subscribe_id
  WHERE gs.payment_type NOT IN ('TRIAL', 'EXTEND', 'BONUS')
    AND gsm.cre_datetime >= '2025-01-01'
    -- 코호트가 충분히 maturity 가 차야 의미가 있음 (>=30일 지난 cohort 만)
    AND gsm.cre_datetime <= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
) cohort
GROUP BY cohort_month
ORDER BY cohort_month DESC;


-- ─────────────────────────────────────────────────────────────────────
-- 4. 액티브 유저 당 수업 수 (스냅샷, 일별)
-- ─────────────────────────────────────────────────────────────────────
-- 매일: 그 날 시점 액티브한 유료 구독자 수 vs 그 날 완료된 수업 수.
-- 일별 변동성 크니 7일 이동평균이나 주별로도 같이 보는 걸 추천.
SELECT
  active_date                                  AS `날짜`,
  active_users                                 AS `액티브 유저 수`,
  total_lessons                                AS `완료 수업 수`,
  ROUND(total_lessons / NULLIF(active_users, 0), 4) AS `유저 당 수업 수`
FROM (
  SELECT
    DATE_SUB(CURDATE(), INTERVAL gn.NUM-1 DAY) AS active_date,
    (SELECT COUNT(DISTINCT gsm.user_id)
     FROM GT_SUBSCRIBE_MAPP gsm
     JOIN GT_SUBSCRIBE gs ON gs.id = gsm.subscribe_id
     WHERE gs.payment_type NOT IN ('TRIAL', 'EXTEND', 'BONUS')
       AND gsm.cre_datetime <= DATE_SUB(CURDATE(), INTERVAL gn.NUM-1 DAY)
       AND (gsm.cancel_at IS NULL OR gsm.cancel_at >  DATE_SUB(CURDATE(), INTERVAL gn.NUM-1 DAY))
       AND (gsm.end_date  IS NULL OR gsm.end_date  >= DATE_SUB(CURDATE(), INTERVAL gn.NUM-1 DAY))
    ) AS active_users,
    (SELECT COUNT(*)
     FROM GT_CLASS gc
     JOIN GT_CLASS_TICKET gct ON gct.ID = gc.CLASS_TICKET_ID
     WHERE gc.INVOICE_STATUS = 'COMPLETED'
       AND gc.IS_PRESTUDY    = 'N'
       AND gct.EVENT_TYPE   != 'PODO_TRIAL'
       AND gc.CLASS_DATE     = DATE_SUB(CURDATE(), INTERVAL gn.NUM-1 DAY)
    ) AS total_lessons
  FROM GT_NUMBERS gn
  WHERE gn.NUM <= 60   -- 최근 60일 (GT_NUMBERS max=60). 더 길게 보려면 numbers self-join 필요.
) snap
ORDER BY active_date DESC;


-- ─────────────────────────────────────────────────────────────────────
-- 5. 액티브 유저 당 수업 수 (스냅샷, 주별)
-- ─────────────────────────────────────────────────────────────────────
-- 주의 시작(월요일) 시점의 액티브 유저 vs 그 주의 완료 수업.
SELECT
  active_week                                  AS `기준 주`,
  active_users                                 AS `주초 액티브 유저 수`,
  total_lessons                                AS `주간 완료 수업 수`,
  ROUND(total_lessons / NULLIF(active_users, 0), 4) AS `유저 당 주간 수업 수`
FROM (
  SELECT
    DATE_SUB(CURDATE(),
             INTERVAL (gn.NUM-1)*7 + WEEKDAY(CURDATE()) DAY) AS active_week,
    (SELECT COUNT(DISTINCT gsm.user_id)
     FROM GT_SUBSCRIBE_MAPP gsm
     JOIN GT_SUBSCRIBE gs ON gs.id = gsm.subscribe_id
     WHERE gs.payment_type NOT IN ('TRIAL', 'EXTEND', 'BONUS')
       AND gsm.cre_datetime <= DATE_SUB(CURDATE(),
                                        INTERVAL (gn.NUM-1)*7 + WEEKDAY(CURDATE()) DAY)
       AND (gsm.cancel_at IS NULL OR gsm.cancel_at >  DATE_SUB(CURDATE(),
                                                       INTERVAL (gn.NUM-1)*7 + WEEKDAY(CURDATE()) DAY))
       AND (gsm.end_date  IS NULL OR gsm.end_date  >= DATE_SUB(CURDATE(),
                                                       INTERVAL (gn.NUM-1)*7 + WEEKDAY(CURDATE()) DAY))
    ) AS active_users,
    (SELECT COUNT(*)
     FROM GT_CLASS gc
     JOIN GT_CLASS_TICKET gct ON gct.ID = gc.CLASS_TICKET_ID
     WHERE gc.INVOICE_STATUS = 'COMPLETED'
       AND gc.IS_PRESTUDY    = 'N'
       AND gct.EVENT_TYPE   != 'PODO_TRIAL'
       AND gc.CLASS_DATE >= DATE_SUB(CURDATE(),
                                     INTERVAL (gn.NUM-1)*7 + WEEKDAY(CURDATE()) DAY)
       AND gc.CLASS_DATE <  DATE_SUB(CURDATE(),
                                     INTERVAL (gn.NUM-2)*7 + WEEKDAY(CURDATE()) DAY)
    ) AS total_lessons
  FROM GT_NUMBERS gn
  WHERE gn.NUM <= 26    -- 최근 26주 (~6개월)
) wk
ORDER BY active_week DESC;


-- ─────────────────────────────────────────────────────────────────────
-- 6-A. 튜터 NPS - 월별 트렌드
-- ─────────────────────────────────────────────────────────────────────
-- le_nps_response: rating 1~5, want_block (재배정 거부)
-- NPS 정의 (1~5 척도용 변형):
--   Promoter   = rating 5
--   Passive    = rating 3, 4
--   Detractor  = rating 1, 2
--   NPS        = (Promoter% - Detractor%)
-- 표준 NPS (0~10) 가 아니므로 절대값 비교는 주의 — 월간 변동 추세가 핵심.
SELECT
  DATE_FORMAT(created_at, '%Y-%m-01')                                       AS `기준 월`,
  COUNT(*)                                                                  AS `응답 수`,
  COUNT(DISTINCT student_id)                                                AS `응답 유저 수`,
  COUNT(DISTINCT tutor_id)                                                  AS `응답 튜터 수`,
  ROUND(AVG(rating), 3)                                                     AS `평균 평점`,
  SUM(CASE WHEN rating = 5      THEN 1 ELSE 0 END)                          AS `5점`,
  SUM(CASE WHEN rating = 4      THEN 1 ELSE 0 END)                          AS `4점`,
  SUM(CASE WHEN rating = 3      THEN 1 ELSE 0 END)                          AS `3점`,
  SUM(CASE WHEN rating = 2      THEN 1 ELSE 0 END)                          AS `2점`,
  SUM(CASE WHEN rating = 1      THEN 1 ELSE 0 END)                          AS `1점`,
  ROUND(SUM(CASE WHEN rating = 5  THEN 1 ELSE 0 END) / COUNT(*) * 100, 2)   AS `Promoter (5점) (%)`,
  ROUND(SUM(CASE WHEN rating IN (3,4) THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS `Passive (3-4점) (%)`,
  ROUND(SUM(CASE WHEN rating <= 2 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2)   AS `Detractor (1-2점) (%)`,
  ROUND(
    (SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END)
     - SUM(CASE WHEN rating <= 2 THEN 1 ELSE 0 END))
    / NULLIF(COUNT(*), 0) * 100, 2
  )                                                                         AS `NPS (5점기반)`,
  SUM(want_block)                                                           AS `Want Block 응답 수`,
  ROUND(SUM(want_block) / NULLIF(COUNT(*), 0) * 100, 2)                     AS `Want Block 비율 (%)`
FROM le_nps_response
GROUP BY `기준 월`
ORDER BY `기준 월` DESC;


-- ─────────────────────────────────────────────────────────────────────
-- 6-B. 튜터별 NPS 랭킹 (worst-N: 개입 우선순위)
-- ─────────────────────────────────────────────────────────────────────
-- 응답 5건 이상인 튜터만 보고, NPS 낮은 순.
-- want_block 도 함께 봐서 패턴 있는 튜터 식별.
SELECT
  nr.tutor_id                                                            AS `튜터 ID`,
  gt.NAME                                                                AS `튜터명`,
  COUNT(*)                                                               AS `응답 수`,
  ROUND(AVG(nr.rating), 2)                                               AS `평균 평점`,
  SUM(CASE WHEN nr.rating = 5      THEN 1 ELSE 0 END)                    AS `5점`,
  SUM(CASE WHEN nr.rating <= 2     THEN 1 ELSE 0 END)                    AS `≤2점`,
  ROUND(
    (SUM(CASE WHEN nr.rating = 5 THEN 1 ELSE 0 END)
     - SUM(CASE WHEN nr.rating <= 2 THEN 1 ELSE 0 END))
    / NULLIF(COUNT(*), 0) * 100, 2
  )                                                                      AS `NPS (5점기반)`,
  SUM(nr.want_block)                                                     AS `Want Block 누적`,
  ROUND(SUM(nr.want_block) / NULLIF(COUNT(*), 0) * 100, 2)               AS `Want Block 비율 (%)`
FROM le_nps_response nr
LEFT JOIN GT_TUTOR gt ON gt.ID = nr.tutor_id
WHERE nr.created_at >= [[ {{from_date}} ]] -- Metabase parameter
  AND nr.created_at <  [[ {{to_date}}   ]]
GROUP BY nr.tutor_id, gt.NAME
HAVING COUNT(*) >= 5
ORDER BY `NPS (5점기반)` ASC, `Want Block 누적` DESC;
