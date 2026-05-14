-- =====================================================================
-- NPS 응답률 코호트 대시보드 (NPS Response Cohort Dashboard)
-- =====================================================================
-- 완료된 수업의 시점을 코호트 기준으로 잡고, 그 코호트의 NPS 응답 상태 분포 / 평점 분포를 본다.
-- 기존 모델 #1598 을 참조한다.
--   {{#1598-nps-tutor-nps-new}}
--
-- 모델 구조 (1 row = 1 completed class):
--   class_id, completed_datetime (KST), lang_type, lesson_time,
--   student_id, student_name, tutor_id, tutor_name,
--   answered_at, rating, reasons, reason_text
--   * LEFT JOIN 이라 응답 row 가 없는 클래스는 answered_at / rating 모두 NULL
--
-- 3개의 응답 상태 (le_nps_response.status 를 모델 컬럼으로부터 역추정):
--   미노출 (NOT_SEEN)   = answered_at IS NULL                          (le_nps_response row 없음)
--   스킵 (SKIPPED)      = answered_at IS NOT NULL AND rating IS NULL    (status='SKIPPED')
--   응답 (SUBMITTED)    = rating IS NOT NULL                            (status='SUBMITTED')
--
-- 핵심 지표:
--   응답률 (Submit rate)   = SUBMITTED / 완료 수업
--   노출률 (Seen rate)     = (SUBMITTED + SKIPPED) / 완료 수업
--                            * 노출된 클래스 중에 NPS 프롬프트가 떴거나 노출된 비율 (deferred 포함)
--   노출 후 응답률         = SUBMITTED / (SUBMITTED + SKIPPED)
--                            * 프롬프트를 본 유저가 실제로 평점을 남긴 비율 — UX 품질 지표
--
-- NPS (5점 척도 변형) — 절대값보다 추세를 본다:
--   Promoter  = 5점,   Passive = 3, 4점,   Detractor = 1, 2점
--
-- 검증 환경: gwatop (prod-metabase via MCP)
-- 검증 일자: 2026-05-14
-- =====================================================================


-- ─────────────────────────────────────────────────────────────────────
-- 1. 월별 코호트 — 완료 수업 월 기준
-- ─────────────────────────────────────────────────────────────────────
SELECT
  DATE_FORMAT(completed_datetime, '%Y-%m-01')                                AS `완료 월 (KST)`,
  COUNT(*)                                                                   AS `완료 수업 수`,

  -- 응답 상태 분포
  SUM(CASE WHEN rating IS NOT NULL THEN 1 ELSE 0 END)                        AS `응답 (Submitted)`,
  SUM(CASE WHEN answered_at IS NOT NULL AND rating IS NULL THEN 1 ELSE 0 END) AS `스킵 (Skipped)`,
  SUM(CASE WHEN answered_at IS NULL THEN 1 ELSE 0 END)                       AS `미노출 (Not Seen)`,

  -- 핵심 비율
  ROUND(SUM(CASE WHEN rating IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100, 2)                                      AS `응답률 (%)`,
  ROUND(SUM(CASE WHEN answered_at IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100, 2)                                      AS `노출률 (%)`,
  ROUND(SUM(CASE WHEN rating IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN answered_at IS NOT NULL THEN 1 ELSE 0 END), 0) * 100, 2) AS `노출 후 응답률 (%)`,

  -- 평점 분포 (Submitted 응답만)
  ROUND(AVG(rating), 3)                                                      AS `평균 평점`,
  SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END)                                AS `5점`,
  SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END)                                AS `4점`,
  SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END)                                AS `3점`,
  SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END)                                AS `2점`,
  SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END)                                AS `1점`,

  ROUND(
    (SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END)
     - SUM(CASE WHEN rating <= 2 THEN 1 ELSE 0 END))
    / NULLIF(SUM(CASE WHEN rating IS NOT NULL THEN 1 ELSE 0 END), 0) * 100, 2
  )                                                                          AS `NPS (5점 기반)`
FROM {{#1598-nps-tutor-nps-new}}
GROUP BY `완료 월 (KST)`
ORDER BY `완료 월 (KST)` DESC;


-- ─────────────────────────────────────────────────────────────────────
-- 2. 주별 코호트 — 완료 수업 주 기준 (월요일 시작)
-- ─────────────────────────────────────────────────────────────────────
SELECT
  DATE_SUB(DATE(completed_datetime),
           INTERVAL WEEKDAY(completed_datetime) DAY)                         AS `완료 주 (월요일 시작, KST)`,
  COUNT(*)                                                                   AS `완료 수업 수`,

  SUM(CASE WHEN rating IS NOT NULL THEN 1 ELSE 0 END)                        AS `응답 (Submitted)`,
  SUM(CASE WHEN answered_at IS NOT NULL AND rating IS NULL THEN 1 ELSE 0 END) AS `스킵 (Skipped)`,
  SUM(CASE WHEN answered_at IS NULL THEN 1 ELSE 0 END)                       AS `미노출 (Not Seen)`,

  ROUND(SUM(CASE WHEN rating IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100, 2)                                      AS `응답률 (%)`,
  ROUND(SUM(CASE WHEN answered_at IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100, 2)                                      AS `노출률 (%)`,
  ROUND(SUM(CASE WHEN rating IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN answered_at IS NOT NULL THEN 1 ELSE 0 END), 0) * 100, 2) AS `노출 후 응답률 (%)`,

  ROUND(AVG(rating), 3)                                                      AS `평균 평점`,
  SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END)                                AS `5점`,
  SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END)                                AS `4점`,
  SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END)                                AS `3점`,
  SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END)                                AS `2점`,
  SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END)                                AS `1점`,

  ROUND(
    (SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END)
     - SUM(CASE WHEN rating <= 2 THEN 1 ELSE 0 END))
    / NULLIF(SUM(CASE WHEN rating IS NOT NULL THEN 1 ELSE 0 END), 0) * 100, 2
  )                                                                          AS `NPS (5점 기반)`
FROM {{#1598-nps-tutor-nps-new}}
GROUP BY `완료 주 (월요일 시작, KST)`
ORDER BY `완료 주 (월요일 시작, KST)` DESC;


-- ─────────────────────────────────────────────────────────────────────
-- 3. 일별 코호트 — 완료 수업 일 기준
-- ─────────────────────────────────────────────────────────────────────
-- 일별 변동성이 크기 때문에 7일 이동평균이나 주별 (#2) 와 함께 보는 것을 추천.
SELECT
  DATE(completed_datetime)                                                   AS `완료 일 (KST)`,
  COUNT(*)                                                                   AS `완료 수업 수`,

  SUM(CASE WHEN rating IS NOT NULL THEN 1 ELSE 0 END)                        AS `응답 (Submitted)`,
  SUM(CASE WHEN answered_at IS NOT NULL AND rating IS NULL THEN 1 ELSE 0 END) AS `스킵 (Skipped)`,
  SUM(CASE WHEN answered_at IS NULL THEN 1 ELSE 0 END)                       AS `미노출 (Not Seen)`,

  ROUND(SUM(CASE WHEN rating IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100, 2)                                      AS `응답률 (%)`,
  ROUND(SUM(CASE WHEN answered_at IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100, 2)                                      AS `노출률 (%)`,
  ROUND(SUM(CASE WHEN rating IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN answered_at IS NOT NULL THEN 1 ELSE 0 END), 0) * 100, 2) AS `노출 후 응답률 (%)`,

  ROUND(AVG(rating), 3)                                                      AS `평균 평점`,
  SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END)                                AS `5점`,
  SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END)                                AS `4점`,
  SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END)                                AS `3점`,
  SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END)                                AS `2점`,
  SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END)                                AS `1점`,

  ROUND(
    (SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END)
     - SUM(CASE WHEN rating <= 2 THEN 1 ELSE 0 END))
    / NULLIF(SUM(CASE WHEN rating IS NOT NULL THEN 1 ELSE 0 END), 0) * 100, 2
  )                                                                          AS `NPS (5점 기반)`
FROM {{#1598-nps-tutor-nps-new}}
GROUP BY `완료 일 (KST)`
ORDER BY `완료 일 (KST)` DESC;
