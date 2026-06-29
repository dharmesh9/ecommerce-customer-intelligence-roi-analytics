WITH
total_customers_cte AS (
    SELECT COUNT(DISTINCT customer_id) AS total_customers
    FROM orders
    WHERE status = 'Completed'
),
total_orders_cte AS (
    SELECT COUNT(DISTINCT order_id) AS total_orders
    FROM orders
    WHERE status = 'Completed'
),
total_revenue_cte AS (
    SELECT ROUND(SUM(order_total), 2) AS total_revenue
    FROM orders
    WHERE status = 'Completed'
),
net_profit_cte AS (
    SELECT ROUND(
        SUM(oi.line_total)
        - SUM(oi.cost_price * oi.qty)
        - COALESCE(SUM(r.refund_amount), 0)
    , 2) AS net_profit
    FROM order_items oi
    LEFT JOIN returns r
        ON oi.item_id = r.item_id
    WHERE oi.order_status IN ('Completed', 'Returned')
),
clv_cte AS (
    SELECT ROUND(AVG(customer_revenue), 2) AS customer_lifetime_value
    FROM (
        SELECT
            o.customer_id,
            SUM(o.order_total) AS customer_revenue
        FROM orders o
        WHERE o.status = 'Completed'
        GROUP BY o.customer_id
    ) x
),
repeat_purchase_cte AS (
    SELECT ROUND(
        SUM(CASE WHEN customer_orders >= 2 THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
    , 2) AS repeat_purchase_rate
    FROM (
        SELECT
            o.customer_id,
            COUNT(*) AS customer_orders
        FROM orders o
        WHERE o.status = 'Completed'
        GROUP BY o.customer_id
    ) y
),
return_rate_cte AS (
    SELECT ROUND(
        COUNT(DISTINCT r.return_id) * 100.0 / COUNT(DISTINCT oi.item_id)
    , 2) AS return_rate
    FROM order_items oi
    LEFT JOIN returns r
        ON oi.item_id = r.item_id
    WHERE oi.order_status IN ('Completed', 'Returned')
),
refund_amount_cte AS (
    SELECT ROUND(COALESCE(SUM(refund_amount), 0), 2) AS refund_amount
    FROM returns
),
ltv_cac_cte AS (
    SELECT
        ROUND(AVG(CASE WHEN channel = 'Email' THEN ltv_to_cac_ratio END), 2) AS email_ltv_to_cac,
        ROUND(AVG(CASE WHEN channel = 'Organic' THEN ltv_to_cac_ratio END), 2) AS organic_ltv_to_cac,
        ROUND(AVG(CASE WHEN channel = 'Referral' THEN ltv_to_cac_ratio END), 2) AS referral_ltv_to_cac,
        ROUND(AVG(CASE WHEN channel = 'Paid Social' THEN ltv_to_cac_ratio END), 2) AS paid_social_ltv_to_cac,
        ROUND(AVG(CASE WHEN channel = 'Google Ads' THEN ltv_to_cac_ratio END), 2) AS google_ads_ltv_to_cac,
        ROUND(AVG(ltv_to_cac_ratio), 2) AS overall_ltv_to_cac
    FROM (
        SELECT
            c.channel,
            ROUND(l.avg_ltv / c.avg_cac, 2) AS ltv_to_cac_ratio
        FROM (
            SELECT
                channel,
                ROUND(AVG(cac), 2) AS avg_cac
            FROM marketing_spend
            GROUP BY channel
        ) c
        LEFT JOIN (
            SELECT
                o.acquisition_channel AS channel,
                ROUND(SUM(o.order_total) / COUNT(DISTINCT o.customer_id), 2) AS avg_ltv
            FROM orders o
            WHERE o.status = 'Completed'
            GROUP BY o.acquisition_channel
        ) l
            ON c.channel = l.channel
    ) z
),
stockout_lost_revenue_cte AS (
    SELECT ROUND(COALESCE(SUM(ps.stockout_days_peak * ads.avg_daily_units * p.sell_price), 0), 2) AS stockout_lost_revenue
    FROM (
        SELECT
            i.product_id,
            COUNT(*) AS stockout_days_peak
        FROM inventory i
        JOIN date_dim d
            ON i.`date` = d.`date`
        WHERE i.stockout_flag = 1
          AND d.is_peak_season = 1
        GROUP BY i.product_id
    ) ps
    JOIN (
        SELECT
            product_id,
            AVG(units_sold) AS avg_daily_units
        FROM inventory
        WHERE stockout_flag = 0
        GROUP BY product_id
    ) ads
        ON ps.product_id = ads.product_id
    JOIN products p
        ON ps.product_id = p.product_id
),
shipping_pct_cte AS (
    SELECT ROUND(AVG(o.shipping_cost / o.order_total) * 100, 2) AS avg_shipping_cost_pct
    FROM orders o
    WHERE o.status = 'Completed'
),
month_end_discount_cte AS (
    SELECT ROUND(AVG(o.discount_pct) * 100, 2) AS month_end_discount_rate
    FROM orders o
    WHERE o.status = 'Completed'
      AND o.is_month_end = 1
)
SELECT
    tc.total_customers AS `Total Customers`,
    to2.total_orders AS `Total Orders`,
    tr.total_revenue AS `Total Revenue`,
    np.net_profit AS `Net Profit`,
    clv.customer_lifetime_value AS `Customer Lifetime Value`,
    rp.repeat_purchase_rate AS `Repeat Purchase Rate (%)`,
    rr.return_rate AS `Return Rate (%)`,
    ra.refund_amount AS `Refund Amount`,
    ltc.overall_ltv_to_cac AS `LTV to CAC Ratio`,
    slr.stockout_lost_revenue AS `Stockout Lost Revenue`,
    sp.avg_shipping_cost_pct AS `Average Shipping Cost (%)`,
    me.month_end_discount_rate AS `Month-End Discount Rate (%)`
FROM total_customers_cte tc
CROSS JOIN total_orders_cte to2
CROSS JOIN total_revenue_cte tr
CROSS JOIN net_profit_cte np
CROSS JOIN clv_cte clv
CROSS JOIN repeat_purchase_cte rp
CROSS JOIN return_rate_cte rr
CROSS JOIN refund_amount_cte ra
CROSS JOIN ltv_cac_cte ltc
CROSS JOIN stockout_lost_revenue_cte slr
CROSS JOIN shipping_pct_cte sp
CROSS JOIN month_end_discount_cte me;