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
