# 체험 Funnel Dashboard — SQL for Metabase

PODO Speaking trial funnel: **signup → trial booked → trial completed → paid conversion**.

Recommended structure: build **one Metabase Model** (`trial_funnel_user`) that flattens the funnel to one row per user, then point each dashboard card at that Model with simple aggregations. Keeps the joins in one place, lets you slice by signup cohort / lang / etc. without rewriting them.

---

## Source-of-truth definitions (verified against prod data + `podo-backend` code)

| Step | Source | Definition |
|---|---|---|
| **Account created** | `GT_USER` | `CREATE_DATE` (filter `CLASS_TYPE = 'PODO'`) |
| **Trial ticket issued** | `GT_CLASS_TICKET` | `EVENT_TYPE = 'PODO_TRIAL'` AND `APPLY_TYPE IS NULL` (exclude admin-issued `SALES`/`COMPENSATE`/`ETC`) |
| **Trial booked** | `GT_CLASS` joined to ticket | A `GT_CLASS` row tied to the trial ticket with `INVOICE_STATUS != 'CREATED'`. `CREATED` is the placeholder row written when the user registers the trial card; it becomes `RESERVED` / `COMPLETED` / `CANCEL` / `NOSHOW_*` once the user actually picks a slot. |
| **Trial completed** | `GT_CLASS` | `INVOICE_STATUS = 'COMPLETED'` on the trial-ticket class row |
| **Paid conversion** | `GT_PAYMENT_INFO` | `STATUS = 'paid'` AND `PAID_AMOUNT > 0` AND `EVENT_TYPE NOT IN ('PODO_CARD_TRIAL', 'PODO_REFUND', 'PODO_REFUND_PAY')`. Matches `PaymentInfoDslRepositoryImpl.java:82`. `PODO_CARD_TRIAL` is the 0원 card-registration row that runs seconds after signup — it is **not** a real purchase. |

A user can have multiple `GT_CLASS` rows on the same trial ticket (cancel → rebook). We collapse to one row per user using `MIN()` for first-event timestamps.

---

## Step 1 — Metabase Model: `trial_funnel_user`

Create as a SQL Model in Metabase. Each row = one PODO signup.

> **Language note.** `GT_USER.LANG_TYPE` defaults to `'EN'` and isn't a reliable signal of what the user actually tried. We instead pull `lang_type` from the user's **most recent trial ticket** (`GT_CLASS_TICKET.LANG_TYPE`, ordered by `CREATE_DATETIME DESC`). About 22% of users with trial tickets have tickets in both EN and JP — they get bucketed by their latest attempt. `all_trial_langs` is exposed as a diagnostic column so you can spot multi-lang users.

```sql
SELECT
    u.ID                                       AS user_id,
    u.EMAIL                                    AS email,
    u.CLASS_TYPE                               AS class_type,
    u.CREATE_DATE                              AS signup_at,
    DATE(u.CREATE_DATE)                        AS signup_date,

    -- Language from the user's LATEST trial ticket (not GT_USER.LANG_TYPE, which is unreliable)
    SUBSTRING_INDEX(
        GROUP_CONCAT(ct.LANG_TYPE ORDER BY ct.CREATE_DATETIME DESC SEPARATOR ','),
        ',', 1
    )                                          AS trial_lang_type,

    -- All trial languages the user has tried (diagnostic for multi-lang users)
    GROUP_CONCAT(DISTINCT ct.LANG_TYPE ORDER BY ct.LANG_TYPE)
                                               AS all_trial_langs,

    -- Trial ticket (the free trial 수강권 issued at signup / card-trial registration)
    MIN(ct.CREATE_DATETIME)                    AS trial_ticket_issued_at,

    -- Trial BOOKED = a GT_CLASS row on the trial ticket that has moved past CREATED
    MIN(CASE
            WHEN c.INVOICE_STATUS <> 'CREATED'
            THEN COALESCE(c.SCHEDULE_REG_AT, c.UPDATE_DATETIME)
        END)                                   AS trial_booked_at,

    -- Trial COMPLETED
    MIN(CASE WHEN c.INVOICE_STATUS = 'COMPLETED'
             THEN c.COMP_DATETIME END)         AS trial_completed_at,

    -- Whether trial was ever no-show / cancelled (useful for diagnostics)
    MAX(CASE WHEN c.INVOICE_STATUS IN ('NOSHOW_S','NOSHOW_BOTH') THEN 1 ELSE 0 END) AS trial_noshow_yn,

    -- First real (non-zero) paid conversion
    MIN(p.UPDATE_DATE)                         AS first_paid_at,
    MIN(p.PAID_AMOUNT)                         AS first_paid_amount

FROM GT_USER u

LEFT JOIN GT_CLASS_TICKET ct
       ON ct.USER_ID    = u.ID
      AND ct.EVENT_TYPE = 'PODO_TRIAL'
      AND ct.APPLY_TYPE IS NULL

LEFT JOIN GT_CLASS c
       ON c.CLASS_TICKET_ID = ct.ID

LEFT JOIN GT_PAYMENT_INFO p
       ON p.USER_UID    = u.ID
      AND p.CLASS_TYPE  = 'PODO'
      AND p.STATUS      = 'paid'
      AND p.PAID_AMOUNT > 0
      AND p.EVENT_TYPE NOT IN ('PODO_CARD_TRIAL', 'PODO_REFUND', 'PODO_REFUND_PAY')

WHERE u.CLASS_TYPE = 'PODO'
  AND u.USE_YN     = 'Y'
  AND u.CREATE_DATE >= {{signup_start}}     -- Metabase date filter (defaults below)
  AND u.CREATE_DATE <  {{signup_end}}

GROUP BY u.ID, u.EMAIL, u.CLASS_TYPE, u.CREATE_DATE;
```

Suggested Metabase filter widgets:
- `signup_start` → Date filter, default `2026-04-01`
- `signup_end`   → Date filter, default `now`

---

## Step 2 — Dashboard cards (query the Model)

In Metabase, write each of these against the Model with `{{#MODEL_ID}}` or via the GUI builder. SQL versions are below for clarity.

All cards share the same column order: `cohort_label`, `signups`, `book_rate`, `trial_booked`, `completion_rate`, `trial_completed`, `post_trial_payment_rate`, `paid_after_completion`. Rates are raw decimals (multiply by 100 in the Metabase visualization settings for `%`). Each card supports an optional `[[ WHERE trial_lang_type = {{lang_type}} ]]` filter widget for EN/JP slicing.

### 2-A. Funnel summary (big number trio)

```sql
SELECT
    COUNT(*)                                                  AS signups,
    COUNT(trial_booked_at) / NULLIF(COUNT(*), 0)              AS book_rate,
    COUNT(trial_booked_at)                                    AS trial_booked,
    COUNT(trial_completed_at) / NULLIF(COUNT(trial_booked_at), 0) AS completion_rate,
    COUNT(trial_completed_at)                                 AS trial_completed,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
        / NULLIF(COUNT(trial_completed_at), 0)
                                                              AS post_trial_payment_rate,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
                                                              AS paid_after_completion
FROM {{#1663-model-trial-funnel-user}} t
[[ WHERE trial_lang_type = {{lang_type}} ]];
```

`post_trial_payment_rate` only counts payments that happened **after** trial completion. If you want "any payment from a completed-trial user," drop the `first_paid_at >= trial_completed_at` clause.

### 2-B. Daily funnel trend (line chart, x = signup_date)

```sql
SELECT
    signup_date,
    COUNT(*)                                                  AS signups,
    COUNT(trial_booked_at) / NULLIF(COUNT(*), 0)              AS book_rate,
    COUNT(trial_booked_at)                                    AS trial_booked,
    COUNT(trial_completed_at) / NULLIF(COUNT(trial_booked_at), 0) AS completion_rate,
    COUNT(trial_completed_at)                                 AS trial_completed,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
        / NULLIF(COUNT(trial_completed_at), 0)
                                                              AS post_trial_payment_rate,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
                                                              AS paid_after_completion
FROM {{#1663-model-trial-funnel-user}} t
[[ WHERE trial_lang_type = {{lang_type}} ]]
GROUP BY signup_date
ORDER BY signup_date DESC;
```

### 2-C. Weekly cohort funnel

```sql
SELECT
    MIN(signup_date)                                          AS week_start,
    COUNT(*)                                                  AS signups,
    COUNT(trial_booked_at) / NULLIF(COUNT(*), 0)              AS book_rate,
    COUNT(trial_booked_at)                                    AS trial_booked,
    COUNT(trial_completed_at) / NULLIF(COUNT(trial_booked_at), 0) AS completion_rate,
    COUNT(trial_completed_at)                                 AS trial_completed,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
        / NULLIF(COUNT(trial_completed_at), 0)
                                                              AS post_trial_payment_rate,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
                                                              AS paid_after_completion
FROM {{#1663-model-trial-funnel-user}} t
[[ WHERE trial_lang_type = {{lang_type}} ]]
GROUP BY DATE_FORMAT(signup_date, '%x-%v')
ORDER BY MIN(signup_date) DESC;
```

### 2-D. Monthly cohort funnel

```sql
SELECT
    DATE_FORMAT(signup_date, '%Y-%m-01')                      AS month_start,
    COUNT(*)                                                  AS signups,
    COUNT(trial_booked_at) / NULLIF(COUNT(*), 0)              AS book_rate,
    COUNT(trial_booked_at)                                    AS trial_booked,
    COUNT(trial_completed_at) / NULLIF(COUNT(trial_booked_at), 0) AS completion_rate,
    COUNT(trial_completed_at)                                 AS trial_completed,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
        / NULLIF(COUNT(trial_completed_at), 0)
                                                              AS post_trial_payment_rate,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
                                                              AS paid_after_completion
FROM {{#1663-model-trial-funnel-user}} t
[[ WHERE trial_lang_type = {{lang_type}} ]]
GROUP BY DATE_FORMAT(signup_date, '%Y-%m-01')
ORDER BY month_start DESC;
```

### 2-E. Slicing by language

No lang filter widget here — this card *is* the language comparison.

```sql
SELECT
    trial_lang_type,
    COUNT(*)                                                  AS signups,
    COUNT(trial_booked_at) / NULLIF(COUNT(*), 0)              AS book_rate,
    COUNT(trial_booked_at)                                    AS trial_booked,
    COUNT(trial_completed_at) / NULLIF(COUNT(trial_booked_at), 0) AS completion_rate,
    COUNT(trial_completed_at)                                 AS trial_completed,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
        / NULLIF(COUNT(trial_completed_at), 0)
                                                              AS post_trial_payment_rate,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
                                                              AS paid_after_completion
FROM {{#1663-model-trial-funnel-user}} t
GROUP BY trial_lang_type
ORDER BY signups DESC;
```

### 2-F. Median time-to-X (helpful supplementary metric)

```sql
SELECT
    AVG(TIMESTAMPDIFF(HOUR, signup_at, trial_booked_at))          AS avg_hours_signup_to_book,
    AVG(TIMESTAMPDIFF(HOUR, trial_booked_at, trial_completed_at)) AS avg_hours_book_to_complete,
    AVG(TIMESTAMPDIFF(HOUR, trial_completed_at, first_paid_at))   AS avg_hours_complete_to_pay
FROM {{#1663-model-trial-funnel-user}} t
WHERE trial_booked_at IS NOT NULL
  [[ AND trial_lang_type = {{lang_type}} ]];
```

---

## Step 3 — Snapshot dashboard cards (event-date view)

**Difference from Step 2.** Step 2 buckets users by **signup date** — the row for `2026-04-01` tells you what happened to people who signed up that day, regardless of when the events occurred. Step 3 buckets by **event date** — the row for `2026-04-01` tells you how many trials were booked / completed / paid for *on that day*, regardless of when those users signed up.

Use Step 3 to answer "how busy were we this week?" Use Step 2 to answer "how well is our funnel converting?"

The rates in Step 3 are *not* funnel conversions — they're event-day ratios (numerator and denominator can be from different user cohorts). They're useful as throughput indicators, not as conversion KPIs.

### 3-A. Daily snapshot (event counts by day)

```sql
WITH events AS (
    SELECT DATE(signup_at)         AS event_date, 'signup'   AS event_type, user_id, trial_lang_type FROM {{#1663-model-trial-funnel-user}}
    UNION ALL
    SELECT DATE(trial_booked_at),    'book',     user_id, trial_lang_type FROM {{#1663-model-trial-funnel-user}} WHERE trial_booked_at IS NOT NULL
    UNION ALL
    SELECT DATE(trial_completed_at), 'complete', user_id, trial_lang_type FROM {{#1663-model-trial-funnel-user}} WHERE trial_completed_at IS NOT NULL
    UNION ALL
    SELECT DATE(first_paid_at),      'paid',     user_id, trial_lang_type FROM {{#1663-model-trial-funnel-user}} WHERE first_paid_at IS NOT NULL
                                                                                                                    AND first_paid_at >= trial_completed_at
)
SELECT
    event_date,
    SUM(event_type = 'signup')   AS signups,
    SUM(event_type = 'book')     AS trial_booked,
    SUM(event_type = 'complete') AS trial_completed,
    SUM(event_type = 'paid')     AS paid_after_completion
FROM events
WHERE 1=1
  [[ AND trial_lang_type = {{lang_type}} ]]
GROUP BY event_date
ORDER BY event_date DESC;
```

### 3-B. Weekly snapshot

```sql
WITH events AS (
    SELECT DATE(signup_at)         AS event_date, 'signup'   AS event_type, user_id, trial_lang_type FROM {{#1663-model-trial-funnel-user}}
    UNION ALL
    SELECT DATE(trial_booked_at),    'book',     user_id, trial_lang_type FROM {{#1663-model-trial-funnel-user}} WHERE trial_booked_at IS NOT NULL
    UNION ALL
    SELECT DATE(trial_completed_at), 'complete', user_id, trial_lang_type FROM {{#1663-model-trial-funnel-user}} WHERE trial_completed_at IS NOT NULL
    UNION ALL
    SELECT DATE(first_paid_at),      'paid',     user_id, trial_lang_type FROM {{#1663-model-trial-funnel-user}} WHERE first_paid_at IS NOT NULL
                                                                                                                    AND first_paid_at >= trial_completed_at
)
SELECT
    MIN(event_date)              AS week_start,
    SUM(event_type = 'signup')   AS signups,
    SUM(event_type = 'book')     AS trial_booked,
    SUM(event_type = 'complete') AS trial_completed,
    SUM(event_type = 'paid')     AS paid_after_completion
FROM events
WHERE 1=1
  [[ AND trial_lang_type = {{lang_type}} ]]
GROUP BY DATE_FORMAT(event_date, '%x-%v')
ORDER BY MIN(event_date) DESC;
```

### 3-C. Monthly snapshot

```sql
WITH events AS (
    SELECT DATE(signup_at)         AS event_date, 'signup'   AS event_type, user_id, trial_lang_type FROM {{#1663-model-trial-funnel-user}}
    UNION ALL
    SELECT DATE(trial_booked_at),    'book',     user_id, trial_lang_type FROM {{#1663-model-trial-funnel-user}} WHERE trial_booked_at IS NOT NULL
    UNION ALL
    SELECT DATE(trial_completed_at), 'complete', user_id, trial_lang_type FROM {{#1663-model-trial-funnel-user}} WHERE trial_completed_at IS NOT NULL
    UNION ALL
    SELECT DATE(first_paid_at),      'paid',     user_id, trial_lang_type FROM {{#1663-model-trial-funnel-user}} WHERE first_paid_at IS NOT NULL
                                                                                                                    AND first_paid_at >= trial_completed_at
)
SELECT
    DATE_FORMAT(event_date, '%Y-%m-01') AS month_start,
    SUM(event_type = 'signup')   AS signups,
    SUM(event_type = 'book')     AS trial_booked,
    SUM(event_type = 'complete') AS trial_completed,
    SUM(event_type = 'paid')     AS paid_after_completion
FROM events
WHERE 1=1
  [[ AND trial_lang_type = {{lang_type}} ]]
GROUP BY DATE_FORMAT(event_date, '%Y-%m-01')
ORDER BY month_start DESC;
```

### 3-D. Completion → payment (anchored on completion week)

This bridges the two views: for trials *completed* in a given week, what fraction led to a payment? Better than the Step-2 rate when you want to assess the post-trial pitch independently of signup-cohort recency.

```sql
SELECT
    DATE_FORMAT(DATE(trial_completed_at), '%x-%v')            AS completion_week,
    MIN(DATE(trial_completed_at))                             AS week_start,
    COUNT(*)                                                  AS trial_completed,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
                                                              AS paid_after_completion,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)                                 AS post_trial_payment_rate,
    AVG(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at
              THEN TIMESTAMPDIFF(HOUR, trial_completed_at, first_paid_at) END)
                                                              AS avg_hours_complete_to_pay
FROM {{#1663-model-trial-funnel-user}} t
WHERE trial_completed_at IS NOT NULL
  [[ AND trial_lang_type = {{lang_type}} ]]
GROUP BY DATE_FORMAT(DATE(trial_completed_at), '%x-%v')
ORDER BY MIN(DATE(trial_completed_at)) DESC;
```

> Like the Step-2 cohort rates, this one has a recency lag — completions in the last week haven't had time to convert yet. Filter `trial_completed_at <= NOW() - INTERVAL 14 DAY` for a stable view of historical performance.

---

## Step 4 — Apples-to-apples conversion (handling recency lag)

Step-2 cohort rates have a built-in problem: a user who signed up 3 days ago hasn't had time to book/complete/pay yet, so recent cohorts look artificially bad. Two ways to fix it, answering different questions.

### 4-A. Bounded-window conversion (the headline KPI)

Pick a window (default: **14 days** from signup). Only count conversions that happened within that window. Exclude any signup cohort younger than the window — they don't have a full 14 days yet, so they'd lower the average unfairly.

Result: every included cohort has the same opportunity, so the rate is comparable week-over-week even for recent data (recent data just lags by 14 days). Recommended as the **primary conversion KPI** for the dashboard.

```sql
SELECT
    MIN(signup_date)                                          AS week_start,
    COUNT(*)                                                  AS signups,

    SUM(CASE WHEN trial_booked_at IS NOT NULL
              AND trial_booked_at <= signup_at + INTERVAL 14 DAY THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)                                 AS book_rate_14d,
    SUM(CASE WHEN trial_booked_at IS NOT NULL
              AND trial_booked_at <= signup_at + INTERVAL 14 DAY THEN 1 ELSE 0 END)
                                                              AS trial_booked_14d,

    SUM(CASE WHEN trial_completed_at IS NOT NULL
              AND trial_completed_at <= signup_at + INTERVAL 14 DAY THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN trial_booked_at IS NOT NULL
                          AND trial_booked_at <= signup_at + INTERVAL 14 DAY THEN 1 ELSE 0 END), 0)
                                                              AS completion_rate_14d,
    SUM(CASE WHEN trial_completed_at IS NOT NULL
              AND trial_completed_at <= signup_at + INTERVAL 14 DAY THEN 1 ELSE 0 END)
                                                              AS trial_completed_14d,

    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at
              AND first_paid_at <= signup_at + INTERVAL 14 DAY THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN trial_completed_at IS NOT NULL
                          AND trial_completed_at <= signup_at + INTERVAL 14 DAY THEN 1 ELSE 0 END), 0)
                                                              AS post_trial_payment_rate_14d,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at
              AND first_paid_at <= signup_at + INTERVAL 14 DAY THEN 1 ELSE 0 END)
                                                              AS paid_after_completion_14d
FROM {{#1663-model-trial-funnel-user}} t
WHERE signup_at <= NOW() - INTERVAL 14 DAY        -- only mature cohorts
  [[ AND trial_lang_type = {{lang_type}} ]]
GROUP BY DATE_FORMAT(signup_date, '%x-%v')
ORDER BY MIN(signup_date) DESC;
```

To make the window a dashboard parameter, replace `14 DAY` with `{{conversion_window_days}} DAY` and set up a Metabase number filter (default 14). Common values: 7 / 14 / 30. Validate against `avg_hours_complete_to_pay` from 2-F — the window should be ≥ that average so you're not chopping off natural converters.

### 4-B. Reverse cohort — buyer's-eye view (anchored on payment date)

Group by **payment date**, then look back at the buyer's journey. By definition every row is a converted user, so this is **not** a conversion rate — it's a profile of *who is buying right now*. Use this to answer:

- "Of this month's buyers, how long did their journey take from signup to payment?"
- "When did this month's buyers originally sign up?" (handy for attributing recent revenue to marketing campaigns from months ago)
- "Are buyers converting faster or slower over time?"

```sql
SELECT
    DATE_FORMAT(DATE(first_paid_at), '%x-%v')                 AS payment_week,
    MIN(DATE(first_paid_at))                                  AS week_start,
    COUNT(*)                                                  AS buyers,

    AVG(TIMESTAMPDIFF(DAY, signup_at, first_paid_at))         AS avg_days_signup_to_pay,
    AVG(TIMESTAMPDIFF(DAY, trial_completed_at, first_paid_at)) AS avg_days_complete_to_pay,

    SUM(CASE WHEN signup_at >= first_paid_at - INTERVAL 7  DAY THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)                                 AS pct_signed_up_within_7d,
    SUM(CASE WHEN signup_at >= first_paid_at - INTERVAL 30 DAY THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)                                 AS pct_signed_up_within_30d,
    SUM(CASE WHEN signup_at <  first_paid_at - INTERVAL 30 DAY THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)                                 AS pct_long_tail_signups,

    AVG(first_paid_amount)                                    AS avg_paid_amount
FROM {{#1663-model-trial-funnel-user}} t
WHERE first_paid_at IS NOT NULL
  AND first_paid_at >= trial_completed_at
  [[ AND trial_lang_type = {{lang_type}} ]]
GROUP BY DATE_FORMAT(DATE(first_paid_at), '%x-%v')
ORDER BY MIN(DATE(first_paid_at)) DESC;
```

### When to use which view

| Question | Card |
|---|---|
| "How is the funnel converting?" (apples-to-apples, week-over-week) | **4-A bounded-window** |
| "Are last week's signups going to convert?" (forward-looking, but unstable) | 2-C weekly signup cohort |
| "Who is buying right now and what was their journey?" | **4-B reverse cohort** |
| "How busy were we this week?" (throughput) | 3-B weekly snapshot |

---

## Standalone version (if you skip the Model)

Wrap the Model SQL as a CTE and append any of the aggregations:

```sql
WITH trial_funnel_user AS (
    -- paste the Step 1 SELECT here (without the {{signup_start}}/{{signup_end}} filters,
    -- or move them out to the outer query)
)
SELECT
    COUNT(*)                                                  AS signups,
    COUNT(trial_booked_at)                                    AS trial_booked,
    COUNT(trial_completed_at)                                 AS trial_completed,
    SUM(CASE WHEN first_paid_at IS NOT NULL
              AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
                                                              AS paid_after_completion,
    ROUND(100.0 * COUNT(trial_booked_at)    / NULLIF(COUNT(*), 0), 2)               AS pct_book_rate,
    ROUND(100.0 * COUNT(trial_completed_at) / NULLIF(COUNT(trial_booked_at), 0), 2) AS pct_completion_rate,
    ROUND(100.0 *
        SUM(CASE WHEN first_paid_at IS NOT NULL
                  AND first_paid_at >= trial_completed_at THEN 1 ELSE 0 END)
        / NULLIF(COUNT(trial_completed_at), 0), 2)
                                                              AS pct_post_trial_payment_rate
FROM trial_funnel_user;
```

---

## Sanity check (April 2026 PODO signups)

Smoke-tested against prod-metabase MySQL on 2026-05-11:

| Metric | April 2026 |
|---|---|
| New PODO signups | 2,256 |
| Got trial class row | 1,533 |
| Booked a slot (non-CREATED) | 1,527 |
| Completed trial | 724 |

So pencil-line expectations: book rate ~68%, completion rate ~47%. Use these as a baseline when validating the dashboard cards.

---

## Caveats / decisions to revisit with the team

1. **`APPLY_TYPE IS NULL` filter on the trial ticket** excludes admin-issued trial tickets (`SALES`, `COMPENSATE`, `ETC` — ~130/mo). Drop the filter if you want them included.
2. **Booked definition** uses `INVOICE_STATUS != 'CREATED'`. If product treats `RESERVED` as the only true booked state, change to `IN ('RESERVED','COMPLETED','NOSHOW_S','NOSHOW_BOTH','CANCEL','CANCEL_PAID','CANCEL_NOSHOW_T','STARTED')`. Current data shows that's effectively the same population (1,527 vs 1,533).
3. **Paid conversion timing** uses `first_paid_at >= trial_completed_at`. A handful of users buy 일시불 *before* completing the trial — they won't count here. Drop the time-ordering if "any payment by a completed-trial user" is the metric you actually want.
4. **Cohort vs flow**: every rate above is computed on the signup cohort. Users who signed up late in the window may not have had time to complete the trial yet → undercount of completion/payment in the most recent days. Add a `signup_at <= NOW() - INTERVAL 14 DAY` filter for a stabilized view.
5. **Multi-language users** (~22% of users with trial tickets have both EN and JP tickets) are bucketed by their **latest** trial ticket's `LANG_TYPE`. Their full funnel (any trial completion, any payment) still counts in that bucket, even if the activity was on the earlier language. If you want a strict per-language funnel ("did the user complete a JP trial specifically?"), switch the model grain to one row per `(user_id, ct.LANG_TYPE)` and join `GT_CLASS` / `GT_PAYMENT_INFO` on `LANG_TYPE` too.
