-- ============================================================
--  RetailIQ — 12 Business Problems
-- ============================================================


-- 1. Why are so many customers purchasing only once and never returning?

-- 2. Which bestselling products are generating negative true profit after costs and refunds?

-- 3. Which marketing channel is receiving significant budget despite delivering the worst ROI?

-- 4. How much revenue is being lost due to stockouts during peak seasonal demand?

-- 5. Which cities or regions have shipping costs that are eroding profitability?

-- 6. Is the business becoming overly dependent on discounts, especially at month-end?

-- 7. Who are the highest-value (VIP) customers, and are they receiving sufficient attention?

-- 8. Is the product return rate increasing over time, and what is its financial impact?

-- 9. Which low-value orders have shipping costs that make them unprofitable?

-- 10. Is NovaTech Supply causing excessive returns, refunds, and quality-related issues?

-- 11. Is there a meaningful difference in demand between weekends and weekdays?

-- 12. Are customer acquisition costs rising faster than customer lifetime value, reducing growth profitability?


USE retail_shop;


-- ============================================================
--  PROBLEM 1: Silent Customer Churn
-- ============================================================

SELECT
    order_count_band,
    COUNT(*)                                                    AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)        AS pct_of_customers,
    ROUND(AVG(lifetime_value), 2)                              AS avg_lifetime_value,
    ROUND(SUM(lifetime_value), 2)                              AS total_revenue
FROM (
    SELECT
        o.customer_id,
        SUM(o.order_total)   AS lifetime_value,
        CASE
            WHEN COUNT(o.order_id) = 1 THEN '1 order (one-time)'
            WHEN COUNT(o.order_id) = 2 THEN '2 orders'
            WHEN COUNT(o.order_id) <= 5 THEN '3-5 orders'
            ELSE '6+ orders'
        END                  AS order_count_band,
        COUNT(o.order_id)    AS order_count
    FROM orders o
    WHERE o.status = 'Completed'
    GROUP BY o.customer_id
) AS customer_summary
GROUP BY order_count_band
ORDER BY MIN(order_count);




-- ============================================================
--  PROBLEM 2: Bestsellers with Negative True Profit
-- ============================================================

SELECT
    oi.product_id,
    oi.product_name,
    oi.category,
    oi.supplier,
    COUNT(DISTINCT oi.order_id)                                         AS total_orders,
    SUM(oi.qty)                                                         AS units_sold,
    ROUND(SUM(oi.line_total), 2)                                        AS gross_revenue,
    ROUND(SUM(oi.cost_price * oi.qty), 2)                              AS total_cogs,
    ROUND(SUM(oi.line_total) - SUM(oi.cost_price * oi.qty), 2)        AS gross_profit,
    ROUND(COALESCE(SUM(r.refund_amount), 0), 2)                        AS total_refunds,
    ROUND(
        SUM(oi.line_total)
        - SUM(oi.cost_price * oi.qty)
        - COALESCE(SUM(r.refund_amount), 0)
    , 2)                                                                AS net_profit
FROM order_items oi
LEFT JOIN `returns` r ON oi.item_id = r.item_id
WHERE oi.order_status IN ('Completed', 'Returned')
GROUP BY oi.product_id, oi.product_name, oi.category, oi.supplier
ORDER BY net_profit ASC;


-- ============================================================
--  PROBLEM 3: Marketing Budget on Worst ROI Channel
-- ============================================================

WITH channel_spend AS (
    SELECT
        channel,
        ROUND(SUM(spend), 2)    AS total_spend,
        ROUND(AVG(cac), 2)      AS avg_cac,
        SUM(conversions)        AS customers_acquired
    FROM marketing_spend
    GROUP BY channel
),
channel_ltv AS (
    SELECT
        o.acquisition_channel,
        COUNT(DISTINCT o.customer_id)                                       AS unique_customers,
        ROUND(SUM(o.order_total), 2)                                        AS total_revenue,
        ROUND(SUM(o.order_total) / COUNT(DISTINCT o.customer_id), 2)       AS avg_ltv
    FROM orders o
    WHERE o.status = 'Completed'
    GROUP BY o.acquisition_channel
)
SELECT
    cs.channel,
    cs.total_spend,
    ROUND(
        cs.total_spend / (SELECT SUM(spend) FROM marketing_spend) * 100
    , 1)                                    AS budget_share_pct,
    cs.avg_cac,
    cs.customers_acquired,
    cl.avg_ltv,
    ROUND(cl.avg_ltv / cs.avg_cac, 2)     AS ltv_to_cac_ratio
FROM channel_spend cs
LEFT JOIN channel_ltv cl ON cs.channel = cl.acquisition_channel
ORDER BY ltv_to_cac_ratio ASC;


-- ============================================================
--  PROBLEM 4: Seasonal Stockouts Killing Peak Revenue
-- ============================================================

WITH avg_daily_sales AS (
    SELECT
        product_id,
        AVG(units_sold) AS avg_daily_units
    FROM inventory
    WHERE stockout_flag = 0
    GROUP BY product_id
),
peak_stockouts AS (
    SELECT
        i.product_id,
        COUNT(*) AS stockout_days_peak
    FROM inventory i
    JOIN date_dim d ON i.`date` = d.`date`
    WHERE i.stockout_flag  = 1
      AND d.is_peak_season = 1
    GROUP BY i.product_id
)
SELECT
    ps.product_id,
    p.product_name,
    p.category,
    p.sell_price,
    ps.stockout_days_peak,
    ROUND(ads.avg_daily_units, 2)                                           AS avg_daily_units_sold,
    ROUND(ps.stockout_days_peak * ads.avg_daily_units * p.sell_price, 2)   AS est_lost_revenue
FROM peak_stockouts ps
JOIN products        p   ON ps.product_id = p.product_id
JOIN avg_daily_sales ads ON ps.product_id = ads.product_id
ORDER BY est_lost_revenue DESC;


-- ============================================================
--  PROBLEM 5: Regional Black Holes (High Shipping Cost Cities)
-- ============================================================

SELECT
    o.city,
    o.region,
    COUNT(o.order_id)                                      AS total_orders,
    ROUND(SUM(o.order_total), 2)                           AS total_revenue,
    ROUND(AVG(o.order_total), 2)                           AS avg_order_value,
    ROUND(AVG(o.shipping_cost), 2)                         AS avg_shipping_cost,
    ROUND(SUM(o.shipping_cost), 2)                         AS total_shipping_cost,
    ROUND(AVG(o.shipping_cost / o.order_total) * 100, 1)  AS shipping_pct_of_order
FROM orders o
WHERE o.status = 'Completed'
GROUP BY o.city, o.region
ORDER BY avg_shipping_cost DESC;


-- ============================================================
--  PROBLEM 6: Discount Addiction at Month-End
-- ============================================================

SELECT
    CASE
        WHEN o.is_month_end = 1 THEN 'Month-end (days 24-31)'
        ELSE                         'Rest of month (days 1-23)'
    END                                                          AS period,
    COUNT(o.order_id)                                            AS order_count,
    ROUND(AVG(o.discount_pct) * 100, 2)                         AS avg_discount_pct,
    ROUND(AVG(o.order_total), 2)                                 AS avg_order_value,
    ROUND(SUM(o.order_total), 2)                                 AS total_revenue,
    ROUND(SUM(
        o.subtotal * o.discount_pct / (1 - o.discount_pct)
    ), 2)                                                        AS total_discount_given
FROM orders o
WHERE o.status = 'Completed'
GROUP BY o.is_month_end
ORDER BY o.is_month_end DESC;

-- Month-end trend by year
SELECT
    o.order_year,
    CASE
        WHEN o.is_month_end = 1 THEN 'Month-end'
        ELSE                         'Rest of month'
    END                                                          AS period,
    COUNT(o.order_id)                                            AS order_count,
    ROUND(AVG(o.discount_pct) * 100, 2)                         AS avg_discount_pct,
    ROUND(SUM(
        o.subtotal * o.discount_pct / (1 - o.discount_pct)
    ), 2)                                                        AS total_discount_given
FROM orders o
WHERE o.status = 'Completed'
GROUP BY o.order_year, o.is_month_end
ORDER BY o.order_year, o.is_month_end DESC;


-- ============================================================
--  PROBLEM 7: VIP Customers Getting No Attention
--  Top 10% of customers by LTV (decile = 1).
-- ============================================================

WITH customer_summary AS (
    SELECT
        o.customer_id,
        COUNT(o.order_id)            AS total_orders,
        ROUND(SUM(o.order_total), 2) AS lifetime_value,
        MIN(o.order_date)            AS first_order_date,
        MAX(o.order_date)            AS last_order_date,
        DATEDIFF('2024-12-31', MAX(o.order_date)) AS days_since_last_order
    FROM orders o
    WHERE o.status = 'Completed'
    GROUP BY o.customer_id
),
ranked AS (
    SELECT *,
        NTILE(10) OVER (ORDER BY lifetime_value DESC) AS decile
    FROM customer_summary
)
SELECT
    r.customer_id,
    c.first_name,
    c.last_name,
    c.city,
    c.acquisition_channel,
    r.total_orders,
    r.lifetime_value,
    r.first_order_date,
    r.last_order_date,
    r.days_since_last_order
FROM ranked r
JOIN customers c ON r.customer_id = c.customer_id
WHERE r.decile = 1
ORDER BY r.lifetime_value DESC;

-- VIP vs non-VIP summary
WITH customer_summary AS (
    SELECT
        o.customer_id,
        COUNT(o.order_id)            AS total_orders,
        ROUND(SUM(o.order_total), 2) AS lifetime_value
    FROM orders o
    WHERE o.status = 'Completed'
    GROUP BY o.customer_id
),
ranked AS (
    SELECT *,
        NTILE(10) OVER (ORDER BY lifetime_value DESC) AS decile
    FROM customer_summary
)
SELECT
    CASE WHEN decile = 1 THEN 'VIP (top 10%)' ELSE 'Non-VIP' END AS segment,
    COUNT(*)                                                        AS customer_count,
    ROUND(AVG(total_orders), 1)                                    AS avg_orders,
    ROUND(AVG(lifetime_value), 2)                                  AS avg_lifetime_value,
    ROUND(SUM(lifetime_value), 2)                                  AS total_revenue_contributed
FROM ranked
GROUP BY CASE WHEN decile = 1 THEN 'VIP (top 10%)' ELSE 'Non-VIP' END
ORDER BY avg_lifetime_value DESC;


-- ============================================================
--  PROBLEM 8: Rising Return Rate (Silent)
--  Tracked quarterly using order_date (not return_date) so all
--  3,716 returns are captured including the 92 from Jan 2025.
-- ============================================================

SELECT
    d.`year`,
    d.quarter,
    COUNT(DISTINCT oi.item_id)                                           AS items_fulfilled,
    COUNT(DISTINCT r.return_id)                                          AS items_returned,
    ROUND(
        COUNT(DISTINCT r.return_id) * 100.0 / COUNT(DISTINCT oi.item_id)
    , 2)                                                                 AS return_rate_pct,
    ROUND(COALESCE(SUM(r.refund_amount), 0), 2)                         AS refunds_paid
FROM order_items oi
JOIN  date_dim d   ON oi.order_date = d.`date`
LEFT JOIN `returns` r ON oi.item_id = r.item_id
WHERE oi.order_status IN ('Completed', 'Returned')
GROUP BY d.`year`, d.quarter
ORDER BY d.`year`, d.quarter;

-- Annual summary
SELECT
    d.`year`,
    COUNT(DISTINCT oi.item_id)                                           AS items_fulfilled,
    COUNT(DISTINCT r.return_id)                                          AS items_returned,
    ROUND(
        COUNT(DISTINCT r.return_id) * 100.0 / COUNT(DISTINCT oi.item_id)
    , 2)                                                                 AS return_rate_pct,
    ROUND(COALESCE(SUM(r.refund_amount), 0), 2)                         AS refunds_paid
FROM order_items oi
JOIN  date_dim d   ON oi.order_date = d.`date`
LEFT JOIN `returns` r ON oi.item_id = r.item_id
WHERE oi.order_status IN ('Completed', 'Returned')
GROUP BY d.`year`
ORDER BY d.`year`;


-- ============================================================
--  PROBLEM 9: Small Orders Losing Money on Shipping
--  42 completed orders have shipping_cost >= subtotal.
--  492 orders have shipping cost above 50% of subtotal.
-- ============================================================

SELECT
    CASE
        WHEN o.subtotal <  20 THEN 'A: Under 20'
        WHEN o.subtotal <  50 THEN 'B: 20-49'
        WHEN o.subtotal < 100 THEN 'C: 50-99'
        ELSE                       'D: 100+'
    END                                                        AS order_size_band,
    COUNT(o.order_id)                                          AS order_count,
    ROUND(AVG(o.subtotal), 2)                                  AS avg_subtotal,
    ROUND(AVG(o.shipping_cost), 2)                             AS avg_shipping_cost,
    ROUND(AVG(o.shipping_cost / o.order_total) * 100, 1)      AS avg_ship_pct_of_total,
    SUM(CASE WHEN o.shipping_cost >= o.subtotal       THEN 1 ELSE 0 END)
                                                               AS orders_ship_exceeds_subtotal,
    SUM(CASE WHEN o.shipping_cost >= o.subtotal * 0.5 THEN 1 ELSE 0 END)
                                                               AS orders_ship_over_50pct_subtotal
FROM orders o
WHERE o.status = 'Completed'
GROUP BY order_size_band
ORDER BY order_size_band;

-- Worst 20 individual orders: shipping >= subtotal
SELECT
    o.order_id,
    o.order_date,
    o.city,
    o.num_items,
    ROUND(o.subtotal, 2)                             AS subtotal,
    ROUND(o.shipping_cost, 2)                        AS shipping_cost,
    ROUND(o.order_total, 2)                          AS order_total,
    ROUND(o.shipping_cost / o.order_total * 100, 1) AS shipping_pct_of_total
FROM orders o
WHERE o.status        = 'Completed'
  AND o.shipping_cost >= o.subtotal
ORDER BY shipping_pct_of_total DESC
LIMIT 20;


-- ============================================================
--  PROBLEM 10: NovaTech Supply — Bad Supplier
--  NovaTech true return rate: 42.1% (was inflated to 45.0%).
--  Still by far the worst supplier. All others are 10-20%.
-- ============================================================

-- Part A: Return rate by supplier (corrected denominator)
SELECT
    oi.supplier,
    COUNT(DISTINCT oi.item_id)                                           AS items_sold,
    COUNT(DISTINCT r.return_id)                                          AS items_returned,
    ROUND(
        COUNT(DISTINCT r.return_id) * 100.0 / COUNT(DISTINCT oi.item_id)
    , 1)                                                                 AS return_rate_pct,
    ROUND(COALESCE(SUM(r.refund_amount), 0), 2)                         AS total_refunds
FROM order_items oi
LEFT JOIN `returns` r ON oi.item_id = r.item_id
WHERE oi.order_status IN ('Completed', 'Returned')
GROUP BY oi.supplier
ORDER BY return_rate_pct DESC;

-- Part B: NovaTech return reasons breakdown
SELECT
    r.return_reason,
    COUNT(r.return_id)                                                       AS return_count,
    ROUND(COUNT(r.return_id) * 100.0 / SUM(COUNT(r.return_id)) OVER (), 1) AS pct_of_novatech_returns,
    ROUND(SUM(r.refund_amount), 2)                                           AS total_refund_value
FROM `returns` r
WHERE r.supplier = 'NovaTech Supply'
GROUP BY r.return_reason
ORDER BY return_count DESC;

-- Part C: Which NovaTech products are driving returns
SELECT
    r.product_id,
    r.product_name,
    COUNT(r.return_id)             AS return_count,
    ROUND(SUM(r.refund_amount), 2) AS total_refund_value
FROM `returns` r
WHERE r.supplier = 'NovaTech Supply'
GROUP BY r.product_id, r.product_name
ORDER BY return_count DESC;

-- ============================================================
--  PROBLEM 11: Weekend Demand Gap
--  NOT PRESENT IN DATA. Included to confirm the signal is absent.
--  No meaningful difference exists between weekend and weekday
--  order volumes or values in this dataset.
-- ============================================================

SELECT
    o.day_of_week,
    o.is_weekend,
    COUNT(o.order_id)              AS order_count,
    ROUND(AVG(o.order_total), 2)  AS avg_order_value,
    ROUND(SUM(o.order_total), 2)  AS total_revenue
FROM orders o 
WHERE o.status = 'Completed'
GROUP BY o.day_of_week, o.is_weekend
ORDER BY o.is_weekend DESC, total_revenue DESC;


-- ============================================================
--  PROBLEM 12: CAC Rising 99%, LTV Flat (Actually Falling)
--  CAC: £24.70 (2022) -> £34.86 (2023) -> £49.21 (2024) = +99%
--  Avg customer LTV by signup year is falling, not flat.
-- ============================================================

-- Part A: CAC trend by year and channel
SELECT
    ms.`year`, 
    ms.channel,
    ROUND(AVG(ms.cac), 2)          AS avg_cac,
    ROUND(SUM(ms.spend), 2)        AS total_spend,
    SUM(ms.conversions)            AS customers_acquired,
    ROUND(AVG(ms.budget_share), 1) AS avg_budget_share_pct
FROM marketing_spend ms
GROUP BY ms.`year`, ms.channel
ORDER BY ms.channel, ms.`year`;

-- Part B: Blended CAC by year (all channels combined)
SELECT
    ms.`year`,
    ROUND(AVG(ms.cac), 2)    AS blended_avg_cac,
    ROUND(SUM(ms.spend), 2)  AS total_spend,
    SUM(ms.conversions)      AS total_customers_acquired
FROM marketing_spend ms
GROUP BY ms.`year`
ORDER BY ms.`year`;

-- Part C: Average LTV by customer signup year
SELECT
    YEAR(c.signup_date)                                            AS signup_year,
    COUNT(DISTINCT c.customer_id)                                  AS cohort_size,
    COUNT(DISTINCT o.order_id)                                     AS total_orders_placed,
    ROUND(COALESCE(SUM(o.order_total), 0), 2)                     AS cohort_total_revenue,
    ROUND(
        COALESCE(SUM(o.order_total), 0) / COUNT(DISTINCT c.customer_id)
    , 2)                                                           AS avg_ltv_per_customer
FROM customers c
LEFT JOIN orders o
    ON  c.customer_id = o.customer_id
    AND o.status      = 'Completed'
GROUP BY YEAR(c.signup_date)
ORDER BY signup_year;

-- Part D: CAC vs LTV side by side — the widening gap
SELECT
    ltv.signup_year,
    ltv.avg_ltv_per_customer,
    cac.blended_avg_cac,
    ROUND(ltv.avg_ltv_per_customer / cac.blended_avg_cac, 2) AS ltv_to_cac_ratio
FROM (
    SELECT
        YEAR(c.signup_date)                                                    AS signup_year,
        ROUND(
            COALESCE(SUM(o.order_total), 0) / COUNT(DISTINCT c.customer_id)
        , 2)                                                                   AS avg_ltv_per_customer
    FROM customers c
    LEFT JOIN orders o
        ON  c.customer_id = o.customer_id
        AND o.status = 'Completed'
    GROUP BY YEAR(c.signup_date)
) ltv
JOIN (
    SELECT
        `year`,
        ROUND(AVG(cac), 2) AS blended_avg_cac
    FROM marketing_spend
    GROUP BY `year`
) cac ON ltv.signup_year = cac.`year`
ORDER BY ltv.signup_year;

-- ============================================================
--  RetailIQ — Problems 13 to 18
-- ============================================================

-- ============================================================
--  PROBLEM 13: RFM Customer Segmentation
-- ============================================================

-- Full customer list
WITH rfm_base AS (
    SELECT
        o.customer_id,
        DATEDIFF('2024-12-31', MAX(o.order_date))  AS recency_days,
        COUNT(o.order_id)                           AS frequency,
        ROUND(SUM(o.order_total), 2)               AS monetary
    FROM orders o
    WHERE o.status = 'Completed'
    GROUP BY o.customer_id
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency    ASC)  AS f_score,
        NTILE(5) OVER (ORDER BY monetary     ASC)  AS m_score
    FROM rfm_base
),
rfm_segments AS (
    SELECT *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champion'
            WHEN r_score >= 3 AND f_score >= 3                   THEN 'Loyal'
            WHEN r_score >= 4 AND f_score <= 2                   THEN 'New Customer'
            WHEN r_score <= 2 AND f_score >= 3                   THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2                   THEN 'Lost'
            ELSE                                                       'Potential Loyal'
        END AS segment
    FROM rfm_scores
)
SELECT
    rs.customer_id,
    c.first_name,
    c.last_name,
    c.city,
    c.acquisition_channel,
    rs.recency_days,
    rs.frequency,
    rs.monetary,
    rs.r_score,
    rs.f_score,
    rs.m_score,
    rs.segment
FROM rfm_segments rs
JOIN customers c ON rs.customer_id = c.customer_id
ORDER BY rs.monetary DESC;

-- Segment summary
WITH rfm_base AS (
    SELECT
        o.customer_id,
        DATEDIFF('2024-12-31', MAX(o.order_date))  AS recency_days,
        COUNT(o.order_id)                           AS frequency,
        ROUND(SUM(o.order_total), 2)               AS monetary
    FROM orders o
    WHERE o.status = 'Completed'
    GROUP BY o.customer_id
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency    ASC)  AS f_score,
        NTILE(5) OVER (ORDER BY monetary     ASC)  AS m_score
    FROM rfm_base
),
rfm_segments AS (
    SELECT *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champion'
            WHEN r_score >= 3 AND f_score >= 3                   THEN 'Loyal'
            WHEN r_score >= 4 AND f_score <= 2                   THEN 'New Customer'
            WHEN r_score <= 2 AND f_score >= 3                   THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2                   THEN 'Lost'
            ELSE                                                       'Potential Loyal'
        END AS segment
    FROM rfm_scores
)
SELECT
    segment,
    COUNT(*)                       AS customer_count,
    ROUND(AVG(recency_days), 1)   AS avg_recency_days,
    ROUND(AVG(frequency), 1)      AS avg_orders,
    ROUND(AVG(monetary), 2)       AS avg_ltv,
    ROUND(SUM(monetary), 2)       AS total_revenue
FROM rfm_segments
GROUP BY segment
ORDER BY avg_ltv DESC;


-- ============================================================
--  PROBLEM 14: Cohort Retention Analysis
-- ============================================================

WITH first_order AS (
    SELECT
        customer_id,
        DATE_FORMAT(MIN(order_date), '%Y-%m-01') AS cohort_month
    FROM orders
    WHERE status = 'Completed'
    GROUP BY customer_id
),
cohort_orders AS (
    SELECT
        f.customer_id,
        f.cohort_month,
        TIMESTAMPDIFF(
            MONTH,
            f.cohort_month,
            DATE_FORMAT(o.order_date, '%Y-%m-01')
        ) AS month_number
    FROM first_order f
    JOIN orders o ON f.customer_id = o.customer_id
    WHERE o.status = 'Completed'
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_customers
    FROM first_order
    GROUP BY cohort_month
)
SELECT
    co.cohort_month,
    cs.cohort_customers,
    COUNT(DISTINCT CASE WHEN co.month_number = 0  THEN co.customer_id END) AS month_0,
    COUNT(DISTINCT CASE WHEN co.month_number = 1  THEN co.customer_id END) AS month_1,
    COUNT(DISTINCT CASE WHEN co.month_number = 2  THEN co.customer_id END) AS month_2,
    COUNT(DISTINCT CASE WHEN co.month_number = 3  THEN co.customer_id END) AS month_3,
    COUNT(DISTINCT CASE WHEN co.month_number = 6  THEN co.customer_id END) AS month_6,
    COUNT(DISTINCT CASE WHEN co.month_number = 12 THEN co.customer_id END) AS month_12,
    ROUND(COUNT(DISTINCT CASE WHEN co.month_number = 1  THEN co.customer_id END) * 100.0 / cs.cohort_customers, 1) AS retention_m1_pct,
    ROUND(COUNT(DISTINCT CASE WHEN co.month_number = 3  THEN co.customer_id END) * 100.0 / cs.cohort_customers, 1) AS retention_m3_pct,
    ROUND(COUNT(DISTINCT CASE WHEN co.month_number = 6  THEN co.customer_id END) * 100.0 / cs.cohort_customers, 1) AS retention_m6_pct,
    ROUND(COUNT(DISTINCT CASE WHEN co.month_number = 12 THEN co.customer_id END) * 100.0 / cs.cohort_customers, 1) AS retention_m12_pct
FROM cohort_orders co
JOIN cohort_size cs ON co.cohort_month = cs.cohort_month
GROUP BY co.cohort_month, cs.cohort_customers
ORDER BY co.cohort_month;


-- ============================================================
--  PROBLEM 15: Month-over-Month Revenue Growth
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m-01')  AS month,
        COUNT(order_id)                       AS order_count,
        ROUND(SUM(order_total), 2)            AS total_revenue
    FROM orders
    WHERE status = 'Completed'
    GROUP BY DATE_FORMAT(order_date, '%Y-%m-01')
),
with_lag AS (
    SELECT
        month,
        order_count,
        total_revenue,
        LAG(total_revenue) OVER (ORDER BY month) AS prev_month_revenue
    FROM monthly_revenue
)
SELECT
    month,
    order_count,
    total_revenue,
    prev_month_revenue,
    ROUND(
        (total_revenue - prev_month_revenue)
        / NULLIF(prev_month_revenue, 0) * 100
    , 1)  AS mom_growth_pct,
    CASE
        WHEN prev_month_revenue IS NULL              THEN 'First Month'
        WHEN total_revenue > prev_month_revenue      THEN 'Growth'
        WHEN total_revenue < prev_month_revenue      THEN 'Decline'
        ELSE                                              'Flat'
    END   AS trend
FROM with_lag
ORDER BY month;


-- ============================================================
--  PROBLEM 16: Product Affinity / Cross-Sell Analysis
-- ============================================================

SELECT
    a.product_id                    AS product_a_id,
    a.product_name                  AS product_a,
    b.product_id                    AS product_b_id,
    b.product_name                  AS product_b,
    COUNT(DISTINCT a.order_id)      AS times_bought_together
FROM order_items a
JOIN order_items b
    ON  a.order_id   = b.order_id
    AND a.product_id < b.product_id
WHERE a.order_status = 'Completed'
  AND b.order_status = 'Completed'
GROUP BY
    a.product_id, a.product_name,
    b.product_id, b.product_name
ORDER BY times_bought_together DESC
LIMIT 20;


-- ============================================================
--  PROBLEM 17: Rolling 30-Day Revenue Trend
--  Note: ROWS BETWEEN 29 PRECEDING counts 30 data rows,
--  not 30 calendar days. If your data has date gaps
--  (days with zero orders), the window may span more than
--  30 calendar days. Safe to use on dense daily retail data.
-- ============================================================

WITH daily_revenue AS (
    SELECT
        order_date,
        COUNT(order_id)                AS daily_orders,
        ROUND(SUM(order_total), 2)     AS daily_revenue
    FROM orders
    WHERE status = 'Completed'
    GROUP BY order_date
)
SELECT
    order_date,
    daily_orders,
    daily_revenue,
    ROUND(SUM(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2)  AS rolling_30d_revenue,
    ROUND(AVG(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2)  AS rolling_30d_avg
FROM daily_revenue
ORDER BY order_date;


-- ============================================================
--  PROBLEM 18: Inventory Turnover Ratio
-- ============================================================

-- Product level
WITH inventory_stats AS (
    SELECT
        product_id,
        SUM(units_sold)             AS total_units_sold,
        ROUND(AVG(stock_level), 2)  AS avg_stock_level,
        SUM(stockout_flag)          AS total_stockout_days,
        COUNT(*)                    AS total_days_tracked
    FROM inventory
    GROUP BY product_id
)
SELECT
    i.product_id,
    p.product_name,
    p.category,
    p.supplier,
    i.total_units_sold,
    i.avg_stock_level,
    ROUND(i.total_units_sold / NULLIF(i.avg_stock_level, 0), 2)          AS turnover_ratio,
    i.total_stockout_days,
    ROUND(i.total_stockout_days * 100.0 / i.total_days_tracked, 1)       AS stockout_rate_pct,
    CASE
        WHEN i.total_units_sold / NULLIF(i.avg_stock_level, 0) >= 2 THEN 'Fast Mover'
        WHEN i.total_units_sold / NULLIF(i.avg_stock_level, 0) >= 1 THEN 'Normal'
        ELSE                                                               'Slow / Dead Stock'
    END                                                                    AS stock_classification
FROM inventory_stats i
JOIN products p ON i.product_id = p.product_id
ORDER BY turnover_ratio DESC;

-- Category level
WITH inventory_stats AS (
    SELECT
        product_id,
        SUM(units_sold)             AS total_units_sold,
        ROUND(AVG(stock_level), 2)  AS avg_stock_level,
        SUM(stockout_flag)          AS total_stockout_days,
        COUNT(*)                    AS total_days_tracked
    FROM inventory
    GROUP BY product_id
)
SELECT
    p.category,
    COUNT(i.product_id)                                                                AS product_count,
    SUM(i.total_units_sold)                                                            AS total_units_sold,
    ROUND(SUM(i.total_units_sold) / NULLIF(AVG(i.avg_stock_level), 0), 2)             AS category_turnover_ratio,
    SUM(i.total_stockout_days)                                                         AS total_stockout_days,
    ROUND(SUM(i.total_stockout_days) * 100.0 / SUM(i.total_days_tracked), 1)          AS stockout_rate_pct
FROM inventory_stats i
JOIN products p ON i.product_id = p.product_id
GROUP BY p.category
ORDER BY category_turnover_ratio DESC;

-- ============================================================
--  END OF SCRIPT
-- ============================================================