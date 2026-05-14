-- =============================================================================
-- Class-Frequency Segment Dashboard (Snapshot + Cohort)
--
-- Population (IMPORTANT):
--   The "denominator" each month is every user who held an active paid ticket
--   at any point during that month — NOT just users who took ≥1 class.
--   This makes "0 classes despite paying" a visible segment, which is where
--   most of the distribution-improvement leverage sits.
--
-- Segments:
--   0_무수강    : Held active ticket, took 0 classes that month
--   1_저빈도    : 1 ≤ N < 6
--   2_중빈도    : 6 ≤ N ≤ 10
--   3_고빈도    : 11 ≤ N ≤ 15
--   4_초고빈도  : N ≥ 16
--   0_이탈      : (Cohort only) Was in pop. last month, NOT in pop. this month
--                 = ticket fully expired/refunded → churned
--
-- "1 class taken" definition (matches backend convention):
--   GT_CLASS, one row per class.
--   INVOICE_STATUS IN ('COMPLETED', 'NOSHOW_BOTH') counts as taken.
--     - COMPLETED   = normal completion
--     - NOSHOW_BOTH = both no-show; ticket is still consumed → counted
--   NOSHOW_S (student no-show), CANCEL*, CANCEL_NOSHOW_T are excluded.
--
-- "Active ticket" definition:
--   GT_CLASS_TICKET rows where:
--     CLASS_TYPE = 'PODO'
--     CURRICULUM_TYPE IN ('BASIC', 'BUSINESS')
--     TICKET_START_DATE  <= last day of month
--     TICKET_EXPIRE_DATE >= first day of month
--     PURCHASED_COUNT - REFUND_COUNT - DESTROY_COUNT > 0   (real remaining count)
--
-- Class scope (matches ticket scope):
--   CLASS_TYPE = 'PODO', CITY IN ('PODO_BASIC', 'PODO_BUSINESS')
--   (TRIAL / AI_CHAT / SMART_TALK excluded to avoid distorting the distribution)
--
-- Sources: gwatop.GT_CLASS (~2M rows), gwatop.GT_CLASS_TICKET (~220K rows)
-- =============================================================================


-- =============================================================================
-- (1) METABASE MODEL: per-user-month with segment label.
--     All dashboard cards reference this one model for consistency.
--     Save as Model: "user_month_class_segment"
-- =============================================================================
SELECT
  pop.month_start,
  pop.user_id,
  COALESCE(cls.class_cnt, 0) AS class_cnt,
  CASE
    WHEN COALESCE(cls.class_cnt, 0) = 0     THEN '0_무수강(0)'
    WHEN cls.class_cnt < 6                   THEN '1_저빈도(<6)'
    WHEN cls.class_cnt BETWEEN 6  AND 10     THEN '2_중빈도(6-10)'
    WHEN cls.class_cnt BETWEEN 11 AND 15     THEN '3_고빈도(11-15)'
    ELSE                                          '4_초고빈도(16+)'
  END AS segment
FROM (
  -- Population: distinct (month, user) for everyone with an active paid ticket
  -- in that month. Adjust the months list / range as needed (or replace the
  -- inline calendar with a real calendar table if you have one).
  SELECT DISTINCT
    cal.month_start,
    tk.USER_ID AS user_id
  FROM GT_CLASS_TICKET tk
  JOIN (
    -- Calendar of months you want to cover (extend or templatize as needed).
    -- Tip: regenerate the list once a year, or replace with a calendar table.
    SELECT DATE '2025-01-01' AS month_start UNION ALL SELECT '2025-02-01'
    UNION ALL SELECT '2025-03-01' UNION ALL SELECT '2025-04-01'
    UNION ALL SELECT '2025-05-01' UNION ALL SELECT '2025-06-01'
    UNION ALL SELECT '2025-07-01' UNION ALL SELECT '2025-08-01'
    UNION ALL SELECT '2025-09-01' UNION ALL SELECT '2025-10-01'
    UNION ALL SELECT '2025-11-01' UNION ALL SELECT '2025-12-01'
    UNION ALL SELECT '2026-01-01' UNION ALL SELECT '2026-02-01'
    UNION ALL SELECT '2026-03-01' UNION ALL SELECT '2026-04-01'
    UNION ALL SELECT '2026-05-01' UNION ALL SELECT '2026-06-01'
  ) cal
    ON tk.TICKET_START_DATE  <= LAST_DAY(cal.month_start) + INTERVAL 1 DAY - INTERVAL 1 SECOND
   AND tk.TICKET_EXPIRE_DATE >= cal.month_start
  WHERE tk.CLASS_TYPE = 'PODO'
    AND tk.CURRICULUM_TYPE IN ('BASIC', 'BUSINESS')
    AND (tk.PURCHASED_COUNT - tk.REFUND_COUNT - tk.DESTROY_COUNT) > 0
) pop
LEFT JOIN (
  -- Class counts per (month, user) for the same scope
  SELECT
    DATE_FORMAT(c.CLASS_DATE, '%Y-%m-01') AS month_start,
    c.STUDENT_USER_ID                     AS user_id,
    COUNT(*)                              AS class_cnt
  FROM GT_CLASS c
  WHERE c.CLASS_TYPE     = 'PODO'
    AND c.CITY           IN ('PODO_BASIC', 'PODO_BUSINESS')
    AND c.INVOICE_STATUS IN ('COMPLETED', 'NOSHOW_BOTH')
    AND c.CLASS_DATE    >= '2025-01-01'
    AND c.CLASS_DATE     < DATE_FORMAT(CURRENT_DATE, '%Y-%m-01')
  GROUP BY month_start, c.STUDENT_USER_ID
) cls
  ON cls.user_id     = pop.user_id
 AND cls.month_start = pop.month_start
WHERE pop.month_start < DATE_FORMAT(CURRENT_DATE, '%Y-%m-01');  -- exclude in-progress month


-- =============================================================================
-- (2) SNAPSHOT — monthly segment share (stacked area / 100% bar)
--     X axis: month_start
--     Y axis: pct_users  |  color: segment
-- =============================================================================
SELECT
  month_start,
  segment,
  COUNT(*)                                                                  AS users,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY month_start), 2)  AS pct_users,
  SUM(class_cnt)                                                            AS total_classes
FROM {{#MODEL_ID}}     -- reference the Metabase model (or paste query (1) inline)
GROUP BY month_start, segment
ORDER BY month_start, segment;


-- =============================================================================
-- (3) SNAPSHOT (summary table) — segment shares for the last 6 months
-- =============================================================================
SELECT
  month_start,
  SUM(CASE WHEN segment='0_무수강(0)'     THEN 1 ELSE 0 END) AS dormant_users,
  SUM(CASE WHEN segment='1_저빈도(<6)'    THEN 1 ELSE 0 END) AS low_users,
  SUM(CASE WHEN segment='2_중빈도(6-10)'  THEN 1 ELSE 0 END) AS mid_users,
  SUM(CASE WHEN segment='3_고빈도(11-15)' THEN 1 ELSE 0 END) AS high_users,
  SUM(CASE WHEN segment='4_초고빈도(16+)' THEN 1 ELSE 0 END) AS super_users,
  COUNT(*)                                                  AS total_users,
  ROUND(100 * SUM(CASE WHEN segment='0_무수강(0)'     THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_dormant,
  ROUND(100 * SUM(CASE WHEN segment='1_저빈도(<6)'    THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_low,
  ROUND(100 * SUM(CASE WHEN segment='2_중빈도(6-10)'  THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_mid,
  ROUND(100 * SUM(CASE WHEN segment='3_고빈도(11-15)' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_high,
  ROUND(100 * SUM(CASE WHEN segment='4_초고빈도(16+)' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_super
FROM {{#MODEL_ID}}
WHERE month_start >= DATE_FORMAT(CURRENT_DATE - INTERVAL 6 MONTH, '%Y-%m-01')
GROUP BY month_start
ORDER BY month_start;


-- =============================================================================
-- (4) COHORT — segment transition matrix (prev month → current month)
--     Pivot chart:  rows = prev_segment, cols = curr_segment, value = pct_of_prev_seg
--     curr_segment = '0_이탈(churned)' means the user is NOT in the population
--       this month (ticket expired/refunded). This is DISTINCT from '0_무수강',
--       which means "still has a ticket, took 0 classes".
--     {{prev_month}} = Metabase Date filter on month_start; e.g. '2026-03-01'
-- =============================================================================
SELECT
  prev.month_start                                  AS prev_month,
  prev.segment                                      AS prev_segment,
  COALESCE(curr.segment, '0_이탈(churned)')         AS curr_segment,
  COUNT(*)                                          AS users,
  ROUND(
    100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY prev.month_start, prev.segment),
    2
  )                                                 AS pct_of_prev_seg
FROM {{#MODEL_ID}} prev
LEFT JOIN {{#MODEL_ID}} curr
  ON curr.user_id     = prev.user_id
 AND curr.month_start = DATE_ADD(prev.month_start, INTERVAL 1 MONTH)
WHERE prev.month_start = {{prev_month}}
GROUP BY prev.month_start, prev.segment, COALESCE(curr.segment, '0_이탈(churned)')
ORDER BY prev_segment, curr_segment;


-- =============================================================================
-- (5) COHORT — transition time-series (retention/up/down/churn by segment)
--     Numeric ranks: 0_무수강=0, 1_저빈도=1, 2_중빈도=2, 3_고빈도=3, 4_초고빈도=4
--     "Churned" = no row in current month (ticket expired/refunded).
--     X axis: prev_month  |  Y axis: stayed_pct / up_pct / down_pct / churn_pct
--             color: prev_segment
-- =============================================================================
SELECT
  prev.month_start                                             AS prev_month,
  prev.segment                                                 AS prev_segment,
  COUNT(*)                                                     AS users_in_seg,
  SUM(CASE WHEN curr.segment IS NULL THEN 1 ELSE 0 END)        AS churned,
  SUM(CASE WHEN curr.segment = prev.segment THEN 1 ELSE 0 END) AS stayed_same,
  SUM(CASE
        WHEN curr.segment IS NOT NULL
         AND LEFT(curr.segment,1) > LEFT(prev.segment,1)
        THEN 1 ELSE 0 END)                                     AS upgraded,
  SUM(CASE
        WHEN curr.segment IS NOT NULL
         AND LEFT(curr.segment,1) < LEFT(prev.segment,1)
        THEN 1 ELSE 0 END)                                     AS downgraded,
  ROUND(100 * SUM(CASE WHEN curr.segment IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2)
                                                               AS churn_pct,
  ROUND(100 * SUM(CASE WHEN curr.segment = prev.segment THEN 1 ELSE 0 END) / COUNT(*), 2)
                                                               AS stayed_pct,
  ROUND(100 * SUM(CASE
                    WHEN curr.segment IS NOT NULL
                     AND LEFT(curr.segment,1) > LEFT(prev.segment,1)
                    THEN 1 ELSE 0 END) / COUNT(*), 2)          AS upgrade_pct,
  ROUND(100 * SUM(CASE
                    WHEN curr.segment IS NOT NULL
                     AND LEFT(curr.segment,1) < LEFT(prev.segment,1)
                    THEN 1 ELSE 0 END) / COUNT(*), 2)          AS downgrade_pct
FROM {{#MODEL_ID}} prev
LEFT JOIN {{#MODEL_ID}} curr
  ON curr.user_id     = prev.user_id
 AND curr.month_start = DATE_ADD(prev.month_start, INTERVAL 1 MONTH)
WHERE prev.month_start >= DATE_FORMAT(CURRENT_DATE - INTERVAL 12 MONTH, '%Y-%m-01')
  AND prev.month_start  < DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01')
GROUP BY prev.month_start, prev.segment
ORDER BY prev.month_start, prev.segment;


-- =============================================================================
-- (6) BONUS — first-month landing segment for newly active users
--     "Where do users land in their first month after activating a ticket?"
--     Leading indicator for distribution-improvement policies.
-- =============================================================================
SELECT
  m.month_start                                                              AS first_month,
  m.segment                                                                  AS first_month_segment,
  COUNT(*)                                                                   AS new_users,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY m.month_start), 2) AS pct
FROM {{#MODEL_ID}} m
INNER JOIN (
  SELECT user_id, MIN(month_start) AS first_month
  FROM {{#MODEL_ID}}
  GROUP BY user_id
) f
  ON f.user_id     = m.user_id
 AND f.first_month = m.month_start
WHERE m.month_start >= DATE_FORMAT(CURRENT_DATE - INTERVAL 12 MONTH, '%Y-%m-01')
GROUP BY m.month_start, m.segment
ORDER BY m.month_start, m.segment;


-- =============================================================================
-- (7) BONUS — drill-down list: at-risk users to target with CRM
--     Two risk types in one list, filterable by `risk_type`:
--       'dormant_stuck'   = had ticket last month, 0 classes; still 0 this month
--       'falling_high'    = was high/super-high last month, dropped to low/dormant
-- =============================================================================
SELECT
  prev.user_id,
  prev.month_start                            AS prev_month,
  prev.class_cnt                              AS prev_class_cnt,
  prev.segment                                AS prev_segment,
  COALESCE(curr.class_cnt, 0)                 AS curr_class_cnt,
  COALESCE(curr.segment, '0_이탈(churned)')   AS curr_segment,
  CASE
    WHEN prev.segment = '0_무수강(0)'
     AND COALESCE(curr.segment,'') = '0_무수강(0)'
      THEN 'dormant_stuck'
    WHEN prev.segment IN ('3_고빈도(11-15)','4_초고빈도(16+)')
     AND (curr.class_cnt IS NULL OR curr.class_cnt < 6)
      THEN 'falling_high'
  END                                         AS risk_type
FROM {{#MODEL_ID}} prev
LEFT JOIN {{#MODEL_ID}} curr
  ON curr.user_id     = prev.user_id
 AND curr.month_start = DATE_ADD(prev.month_start, INTERVAL 1 MONTH)
WHERE prev.month_start = DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01')
  AND (
        (prev.segment = '0_무수강(0)' AND COALESCE(curr.segment,'') = '0_무수강(0)')
     OR (prev.segment IN ('3_고빈도(11-15)','4_초고빈도(16+)')
         AND (curr.class_cnt IS NULL OR curr.class_cnt < 6))
      )
ORDER BY risk_type, prev.class_cnt DESC;


-- =============================================================================
-- (8) METABASE MODEL — MONTHLY, CONTINUOUS-SUBSCRIPTION ONLY
--     Same shape as model (1) but the population is restricted to users who
--     had an UNINTERRUPTED active subscription for every day of the month.
--     Mid-month new buyers / churners are excluded → segment shares reflect
--     "established subscribers only," closer to the ~4K active-user mental model.
--
--     Continuity rule:
--       - User must have a ticket covering month_start AND month_end.
--       - Within the month, every new ticket starting after month_start must
--         be preceded by another ticket of theirs whose expire date is within
--         INTERVAL 2 DAY of the new ticket's start. The 2-day tolerance bridges
--         the systematic ~1-day-1-second billing-renewal lag observed in the
--         data while still flagging real subscription pauses.
--
--     Save as Model: "user_month_class_segment_continuous"
-- =============================================================================
SELECT
  pop.month_start,
  pop.user_id,
  COALESCE(cls.class_cnt, 0) AS class_cnt,
  CASE
    WHEN COALESCE(cls.class_cnt, 0) = 0    THEN '0_무수강(0)'
    WHEN cls.class_cnt < 6                  THEN '1_저빈도(<6)'
    WHEN cls.class_cnt BETWEEN 6  AND 10    THEN '2_중빈도(6-10)'
    WHEN cls.class_cnt BETWEEN 11 AND 15    THEN '3_고빈도(11-15)'
    ELSE                                         '4_초고빈도(16+)'
  END AS segment
FROM (
  SELECT cal.month_start, cand.USER_ID AS user_id
  FROM (
    SELECT DATE '2025-01-01' AS month_start UNION ALL SELECT '2025-02-01'
    UNION ALL SELECT '2025-03-01' UNION ALL SELECT '2025-04-01'
    UNION ALL SELECT '2025-05-01' UNION ALL SELECT '2025-06-01'
    UNION ALL SELECT '2025-07-01' UNION ALL SELECT '2025-08-01'
    UNION ALL SELECT '2025-09-01' UNION ALL SELECT '2025-10-01'
    UNION ALL SELECT '2025-11-01' UNION ALL SELECT '2025-12-01'
    UNION ALL SELECT '2026-01-01' UNION ALL SELECT '2026-02-01'
    UNION ALL SELECT '2026-03-01' UNION ALL SELECT '2026-04-01'
    UNION ALL SELECT '2026-05-01' UNION ALL SELECT '2026-06-01'
  ) cal
  CROSS JOIN (
    SELECT DISTINCT USER_ID
    FROM GT_CLASS_TICKET
    WHERE CLASS_TYPE='PODO' AND CURRICULUM_TYPE IN ('BASIC','BUSINESS')
      AND (PURCHASED_COUNT - REFUND_COUNT - DESTROY_COUNT) > 0
  ) cand
  WHERE
    -- (a) some ticket of user covers month_start (00:00)
    EXISTS (
      SELECT 1 FROM GT_CLASS_TICKET t
      WHERE t.USER_ID = cand.USER_ID
        AND t.CLASS_TYPE='PODO' AND t.CURRICULUM_TYPE IN ('BASIC','BUSINESS')
        AND (t.PURCHASED_COUNT - t.REFUND_COUNT - t.DESTROY_COUNT) > 0
        AND t.TICKET_START_DATE  <= cal.month_start
        AND t.TICKET_EXPIRE_DATE >= cal.month_start
    )
    -- (b) some ticket of user covers month_end (23:59:59)
    AND EXISTS (
      SELECT 1 FROM GT_CLASS_TICKET t
      WHERE t.USER_ID = cand.USER_ID
        AND t.CLASS_TYPE='PODO' AND t.CURRICULUM_TYPE IN ('BASIC','BUSINESS')
        AND (t.PURCHASED_COUNT - t.REFUND_COUNT - t.DESTROY_COUNT) > 0
        AND t.TICKET_START_DATE  <= LAST_DAY(cal.month_start) + INTERVAL 1 DAY - INTERVAL 1 SECOND
        AND t.TICKET_EXPIRE_DATE >= LAST_DAY(cal.month_start) + INTERVAL 1 DAY - INTERVAL 1 SECOND
    )
    -- (c) no internal gap: every ticket starting after month_start within the
    --     month must have a preceding ticket of the same user whose expire date
    --     is within INTERVAL 2 DAY of its start (handles billing-renewal lag).
    AND NOT EXISTS (
      SELECT 1 FROM GT_CLASS_TICKET tg
      WHERE tg.USER_ID = cand.USER_ID
        AND tg.CLASS_TYPE='PODO' AND tg.CURRICULUM_TYPE IN ('BASIC','BUSINESS')
        AND (tg.PURCHASED_COUNT - tg.REFUND_COUNT - tg.DESTROY_COUNT) > 0
        AND tg.TICKET_START_DATE >  cal.month_start
        AND tg.TICKET_START_DATE <= LAST_DAY(cal.month_start) + INTERVAL 1 DAY - INTERVAL 1 SECOND
        AND NOT EXISTS (
          SELECT 1 FROM GT_CLASS_TICKET tp
          WHERE tp.USER_ID = cand.USER_ID
            AND tp.CLASS_TYPE='PODO' AND tp.CURRICULUM_TYPE IN ('BASIC','BUSINESS')
            AND (tp.PURCHASED_COUNT - tp.REFUND_COUNT - tp.DESTROY_COUNT) > 0
            AND tp.TICKET_START_DATE  <  tg.TICKET_START_DATE
            AND tp.TICKET_EXPIRE_DATE >= tg.TICKET_START_DATE - INTERVAL 2 DAY
        )
    )
) pop
LEFT JOIN (
  SELECT
    DATE_FORMAT(c.CLASS_DATE, '%Y-%m-01') AS month_start,
    c.STUDENT_USER_ID                     AS user_id,
    COUNT(*)                              AS class_cnt
  FROM GT_CLASS c
  WHERE c.CLASS_TYPE     = 'PODO'
    AND c.CITY           IN ('PODO_BASIC', 'PODO_BUSINESS')
    AND c.INVOICE_STATUS IN ('COMPLETED', 'NOSHOW_BOTH')
    AND c.CLASS_DATE    >= '2025-01-01'
    AND c.CLASS_DATE     < DATE_FORMAT(CURRENT_DATE, '%Y-%m-01')
  GROUP BY month_start, c.STUDENT_USER_ID
) cls
  ON cls.user_id     = pop.user_id
 AND cls.month_start = pop.month_start
WHERE pop.month_start < DATE_FORMAT(CURRENT_DATE, '%Y-%m-01');


-- =============================================================================
-- (9) METABASE MODEL — WEEKLY, CONTINUOUS-SUBSCRIPTION ONLY
--     Same idea as (8) but grouped into Monday-Sunday weeks.
--     week_start = Monday 00:00 KST-naive; week_end = Sunday 23:59:59.
--
--     Weekly segment thresholds (tweak if needed):
--       0_무수강    : 0 classes that week
--       1_저빈도    : 1 class
--       2_중빈도    : 2-3 classes
--       3_고빈도    : 4-5 classes
--       4_초고빈도  : 6+ classes
--
--     Save as Model: "user_week_class_segment_continuous"
--     The inline week calendar covers ~80 weeks (2025-01-06 onward).
--     Extend the UNION as needed, or replace with a real calendar table.
-- =============================================================================
SELECT
  pop.week_start,
  pop.user_id,
  COALESCE(cls.class_cnt, 0) AS class_cnt,
  CASE
    WHEN COALESCE(cls.class_cnt, 0) = 0    THEN '0_무수강(0)'
    WHEN cls.class_cnt = 1                  THEN '1_저빈도(1)'
    WHEN cls.class_cnt BETWEEN 2 AND 3      THEN '2_중빈도(2-3)'
    WHEN cls.class_cnt BETWEEN 4 AND 5      THEN '3_고빈도(4-5)'
    ELSE                                         '4_초고빈도(6+)'
  END AS segment
FROM (
  SELECT cal.week_start, cand.USER_ID AS user_id
  FROM (
    -- Mondays from 2025-01-06 onward (extend as needed).
    -- Generated via small numbers table; 100 weeks ≈ 2025-01-06 to ~2026-12-07.
    SELECT DATE_ADD(DATE '2025-01-06', INTERVAL n WEEK) AS week_start
    FROM (
      SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
      UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
      UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
      UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
      UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
      UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
      UNION ALL SELECT 24 UNION ALL SELECT 25 UNION ALL SELECT 26 UNION ALL SELECT 27
      UNION ALL SELECT 28 UNION ALL SELECT 29 UNION ALL SELECT 30 UNION ALL SELECT 31
      UNION ALL SELECT 32 UNION ALL SELECT 33 UNION ALL SELECT 34 UNION ALL SELECT 35
      UNION ALL SELECT 36 UNION ALL SELECT 37 UNION ALL SELECT 38 UNION ALL SELECT 39
      UNION ALL SELECT 40 UNION ALL SELECT 41 UNION ALL SELECT 42 UNION ALL SELECT 43
      UNION ALL SELECT 44 UNION ALL SELECT 45 UNION ALL SELECT 46 UNION ALL SELECT 47
      UNION ALL SELECT 48 UNION ALL SELECT 49 UNION ALL SELECT 50 UNION ALL SELECT 51
      UNION ALL SELECT 52 UNION ALL SELECT 53 UNION ALL SELECT 54 UNION ALL SELECT 55
      UNION ALL SELECT 56 UNION ALL SELECT 57 UNION ALL SELECT 58 UNION ALL SELECT 59
      UNION ALL SELECT 60 UNION ALL SELECT 61 UNION ALL SELECT 62 UNION ALL SELECT 63
      UNION ALL SELECT 64 UNION ALL SELECT 65 UNION ALL SELECT 66 UNION ALL SELECT 67
      UNION ALL SELECT 68 UNION ALL SELECT 69 UNION ALL SELECT 70 UNION ALL SELECT 71
      UNION ALL SELECT 72 UNION ALL SELECT 73 UNION ALL SELECT 74 UNION ALL SELECT 75
      UNION ALL SELECT 76 UNION ALL SELECT 77 UNION ALL SELECT 78 UNION ALL SELECT 79
      UNION ALL SELECT 80 UNION ALL SELECT 81 UNION ALL SELECT 82 UNION ALL SELECT 83
      UNION ALL SELECT 84 UNION ALL SELECT 85 UNION ALL SELECT 86 UNION ALL SELECT 87
      UNION ALL SELECT 88 UNION ALL SELECT 89 UNION ALL SELECT 90 UNION ALL SELECT 91
      UNION ALL SELECT 92 UNION ALL SELECT 93 UNION ALL SELECT 94 UNION ALL SELECT 95
      UNION ALL SELECT 96 UNION ALL SELECT 97 UNION ALL SELECT 98 UNION ALL SELECT 99
    ) nums
    WHERE DATE_ADD(DATE '2025-01-06', INTERVAL n WEEK) < CURRENT_DATE - INTERVAL WEEKDAY(CURRENT_DATE) DAY
  ) cal
  CROSS JOIN (
    SELECT DISTINCT USER_ID
    FROM GT_CLASS_TICKET
    WHERE CLASS_TYPE='PODO' AND CURRICULUM_TYPE IN ('BASIC','BUSINESS')
      AND (PURCHASED_COUNT - REFUND_COUNT - DESTROY_COUNT) > 0
  ) cand
  WHERE
    -- (a) ticket covers week_start (Monday 00:00)
    EXISTS (
      SELECT 1 FROM GT_CLASS_TICKET t
      WHERE t.USER_ID = cand.USER_ID
        AND t.CLASS_TYPE='PODO' AND t.CURRICULUM_TYPE IN ('BASIC','BUSINESS')
        AND (t.PURCHASED_COUNT - t.REFUND_COUNT - t.DESTROY_COUNT) > 0
        AND t.TICKET_START_DATE  <= cal.week_start
        AND t.TICKET_EXPIRE_DATE >= cal.week_start
    )
    -- (b) ticket covers week_end (Sunday 23:59:59)
    AND EXISTS (
      SELECT 1 FROM GT_CLASS_TICKET t
      WHERE t.USER_ID = cand.USER_ID
        AND t.CLASS_TYPE='PODO' AND t.CURRICULUM_TYPE IN ('BASIC','BUSINESS')
        AND (t.PURCHASED_COUNT - t.REFUND_COUNT - t.DESTROY_COUNT) > 0
        AND t.TICKET_START_DATE  <= cal.week_start + INTERVAL 7 DAY - INTERVAL 1 SECOND
        AND t.TICKET_EXPIRE_DATE >= cal.week_start + INTERVAL 7 DAY - INTERVAL 1 SECOND
    )
    -- (c) no internal gap (2-day tolerance for renewal lag)
    AND NOT EXISTS (
      SELECT 1 FROM GT_CLASS_TICKET tg
      WHERE tg.USER_ID = cand.USER_ID
        AND tg.CLASS_TYPE='PODO' AND tg.CURRICULUM_TYPE IN ('BASIC','BUSINESS')
        AND (tg.PURCHASED_COUNT - tg.REFUND_COUNT - tg.DESTROY_COUNT) > 0
        AND tg.TICKET_START_DATE >  cal.week_start
        AND tg.TICKET_START_DATE <= cal.week_start + INTERVAL 7 DAY - INTERVAL 1 SECOND
        AND NOT EXISTS (
          SELECT 1 FROM GT_CLASS_TICKET tp
          WHERE tp.USER_ID = cand.USER_ID
            AND tp.CLASS_TYPE='PODO' AND tp.CURRICULUM_TYPE IN ('BASIC','BUSINESS')
            AND (tp.PURCHASED_COUNT - tp.REFUND_COUNT - tp.DESTROY_COUNT) > 0
            AND tp.TICKET_START_DATE  <  tg.TICKET_START_DATE
            AND tp.TICKET_EXPIRE_DATE >= tg.TICKET_START_DATE - INTERVAL 2 DAY
        )
    )
) pop
LEFT JOIN (
  SELECT
    DATE_SUB(c.CLASS_DATE, INTERVAL WEEKDAY(c.CLASS_DATE) DAY) AS week_start,
    c.STUDENT_USER_ID                                          AS user_id,
    COUNT(*)                                                   AS class_cnt
  FROM GT_CLASS c
  WHERE c.CLASS_TYPE     = 'PODO'
    AND c.CITY           IN ('PODO_BASIC', 'PODO_BUSINESS')
    AND c.INVOICE_STATUS IN ('COMPLETED', 'NOSHOW_BOTH')
    AND c.CLASS_DATE    >= '2025-01-06'
    AND c.CLASS_DATE     < DATE_SUB(CURRENT_DATE, INTERVAL WEEKDAY(CURRENT_DATE) DAY)
  GROUP BY week_start, c.STUDENT_USER_ID
) cls
  ON cls.user_id    = pop.user_id
 AND cls.week_start = pop.week_start
WHERE pop.week_start < DATE_SUB(CURRENT_DATE, INTERVAL WEEKDAY(CURRENT_DATE) DAY);


-- =============================================================================
-- (10) WEEKLY SUMMARY TABLE — counts + ratios per week
--      Mirror of query (3) but for the weekly model (9).
--      Default window: last 26 weeks (~6 months). Change as needed.
-- =============================================================================
SELECT
  week_start,
  SUM(CASE WHEN segment='0_무수강(0)'    THEN 1 ELSE 0 END) AS 무수강_수,
  SUM(CASE WHEN segment='2_중빈도(2-3)'  THEN 1 ELSE 0 END) AS 중빈도_수,
  SUM(CASE WHEN segment='3_고빈도(4-5)'  THEN 1 ELSE 0 END) AS 고빈도_수,
  SUM(CASE WHEN segment='4_초고빈도(6+)' THEN 1 ELSE 0 END) AS 초고빈도_수,
  COUNT(*)                                                  AS 총_유저,
  SUM(CASE WHEN segment='0_무수강(0)'    THEN 1 ELSE 0 END) / COUNT(*) AS 무수강_비율,
  SUM(CASE WHEN segment='1_저빈도(1)'    THEN 1 ELSE 0 END) / COUNT(*) AS 저빈도_비율,
  SUM(CASE WHEN segment='2_중빈도(2-3)'  THEN 1 ELSE 0 END) / COUNT(*) AS 중빈도_비율,
  SUM(CASE WHEN segment='3_고빈도(4-5)'  THEN 1 ELSE 0 END) / COUNT(*) AS 고빈도_비율,
  SUM(CASE WHEN segment='4_초고빈도(6+)' THEN 1 ELSE 0 END) / COUNT(*) AS 초고빈도_비율
FROM {{#WEEKLY_MODEL_ID}} m  -- replace with the Metabase model ID for user_week_class_segment_continuous
WHERE week_start >= DATE_SUB(CURRENT_DATE, INTERVAL 26 WEEK)
GROUP BY week_start
ORDER BY week_start DESC;


-- =============================================================================
-- HOW TO USE THE NEW MODELS
--
-- Snapshot queries (2)/(3) and bonus queries (6) work as-is against model (8)
-- by just swapping {{#MODEL_ID}} to point at "user_month_class_segment_continuous".
--
-- For weekly queries based on model (9): replace `month_start` with `week_start`
-- in queries (2)/(3)/(6), and in cohort queries (4)/(5)/(7) change
--   `DATE_ADD(prev.month_start, INTERVAL 1 MONTH)`
-- to
--   `DATE_ADD(prev.week_start, INTERVAL 7 DAY)`
--
-- Also: the weekly segment list is different from the monthly one, so update
-- the literal strings in (3) and (7) accordingly:
--   '1_저빈도(<6)'    → '1_저빈도(1)'
--   '2_중빈도(6-10)'  → '2_중빈도(2-3)'
--   '3_고빈도(11-15)' → '3_고빈도(4-5)'
--   '4_초고빈도(16+)' → '4_초고빈도(6+)'
-- =============================================================================
