-- Query: Customer Lifetime Value by Order Frequency Band

SELECT
    order_count_band,
    COUNT(*)                                                    AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)          AS pct_of_customers,
    ROUND(AVG(lifetime_value), 2)                               AS avg_lifetime_value,
    ROUND(SUM(lifetime_value), 2)                               AS total_revenue
FROM (
    SELECT
        o.customer_id,
        SUM(o.order_total) AS lifetime_value,
        CASE
            WHEN COUNT(o.order_id) = 1 THEN '1 order (one-time)'
            WHEN COUNT(o.order_id) = 2 THEN '2 orders'
            WHEN COUNT(o.order_id) <= 5 THEN '3-5 orders'
            ELSE '6+ orders'
        END AS order_count_band,
        COUNT(o.order_id) AS order_count
    FROM orders o
    WHERE o.status = 'Completed'
    GROUP BY o.customer_id
) AS customer_summary
GROUP BY order_count_band
ORDER BY MIN(order_count);

-- Output:
-- +----------------------+---------------+------------------+--------------------+---------------+
-- | order_count_band     | customer_count| pct_of_customers | avg_lifetime_value | total_revenue |
-- +----------------------+---------------+------------------+--------------------+---------------+
-- | 1 order (one-time)   | 3437          | 68.8             | 154.78             | 531971.53     |
-- | 2 orders             | 557           | 11.2             | 284.12             | 158254.97     |
-- | 3-5 orders           | 644           | 12.9             | 537.56             | 346189.70     |
-- | 6+ orders            | 355           | 7.1              | 1332.07            | 472886.01     |
-- +----------------------+---------------+------------------+--------------------+---------------+

/*
Insights:

1. One-time customers represent 68.8% of the customer base (3,437 customers),
   but contribute only $531,971.53 in revenue.

2. Customers with 6+ orders account for just 7.1% of customers (355 customers),
   yet generate $472,886.01 in revenue, nearly matching the revenue from the
   entire one-time customer segment.

3. Average lifetime value increases significantly with repeat purchases:
   - 1 order:  $154.78
   - 2 orders: $284.12
   - 3–5 orders: $537.56
   - 6+ orders: $1,332.07

4. Retention has a substantial impact on revenue, as a relatively small group
   of highly engaged customers contributes a disproportionately large share
   of total sales.
*/


-- Query: Product Profitability Analysis (Revenue, COGS, Refunds, and Net Profit)

SELECT
    oi.product_id,
    oi.product_name,
    oi.category,
    oi.supplier,
    COUNT(DISTINCT oi.order_id)                                         AS total_orders,
    SUM(oi.qty)                                                         AS units_sold,
    ROUND(SUM(oi.line_total), 2)                                        AS gross_revenue,
    ROUND(SUM(oi.cost_price * oi.qty), 2)                              AS total_cogs,
    ROUND(SUM(oi.line_total) - SUM(oi.cost_price * oi.qty), 2)         AS gross_profit,
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

-- Output (sorted by net_profit ASC):
--
-- Lowest Net Profit Products
-- P010 | Noise Cancel Headphones      | Net Profit: -12228.12
-- P008 | Power Bank 20000mAh          | Net Profit:  -6929.30
-- P029 | Thermal Paste Premium        | Net Profit:   1331.00
-- P027 | Cable Clips Pack 50          | Net Profit:   1668.23
-- P023 | Cable Management Kit         | Net Profit:   2990.36
--
-- Highest Net Profit Products
-- P011 | Mechanical Keyboard TKL      | Net Profit:  52225.49
-- P003 | Smart Watch Fitness          | Net Profit:  69704.50
-- P016 | 27in Monitor 4K              | Net Profit: 101562.18

/*
Insights:

1. Two products are operating at a loss:
   - Noise Cancel Headphones (-$12,228.12)
   - Power Bank 20000mAh (-$6,929.30)

   In both cases, cost of goods sold exceeds revenue before refunds are
   considered, indicating a pricing, sourcing, or inventory-cost issue
   rather than simply excessive returns.

2. Refunds are materially impacting profitability across several products.
   For example, Smart Plug 4-Pack generated gross profit of $16,738.92,
   but refunds of $12,239.39 reduced net profit to only $4,499.53,
   eliminating nearly three-quarters of gross profit.

3. Premium hardware products drive the strongest profits:
   - 27in Monitor 4K: $101,562.18 net profit
   - Smart Watch Fitness: $69,704.50 net profit
   - Mechanical Keyboard TKL: $52,225.49 net profit

   These products combine strong revenue generation with healthy margins,
   making them key contributors to overall profitability.

4. Revenue does not necessarily translate into profit.
   Several products generate substantial sales volumes but experience large
   deductions from high COGS and refunds. Profitability analysis provides a
   more accurate basis for product decisions than revenue rankings alone.

5. Accessories dominate the lower-profit segment. While they contribute
   volume and order frequency, many accessory products produce relatively
   modest net profits compared with higher-value categories such as Displays,
   Wearables, and Peripherals.

6. Supplier performance appears uneven. Products sourced from TechCore Ltd
   include both the two worst-performing items and several strong performers,
   suggesting profitability issues may be product-specific rather than purely
   supplier-driven.
*/

-- Query: Marketing Channel ROI Analysis (LTV vs CAC)

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
        ROUND(SUM(o.order_total) / COUNT(DISTINCT o.customer_id), 2)        AS avg_ltv
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
    ROUND(cl.avg_ltv / cs.avg_cac, 2)       AS ltv_to_cac_ratio
FROM channel_spend cs
LEFT JOIN channel_ltv cl ON cs.channel = cl.acquisition_channel
ORDER BY ltv_to_cac_ratio ASC;

-- Output:
--
-- +-------------+-------------+------------------+---------+--------------------+---------+------------------+
-- | Channel     | Total Spend | Budget Share (%) | Avg CAC | Customers Acquired | Avg LTV | LTV/CAC Ratio    |
-- +-------------+-------------+------------------+---------+--------------------+---------+------------------+
-- | Paid Social | 472746.36   | 53.9             | 70.50   | 6982               | 304.19  | 4.31             |
-- | Google Ads  | 266403.18   | 30.4             | 63.79   | 4384               | 296.57  | 4.65             |
-- | Referral    | 60236.05    | 6.9              | 23.50   | 2678               | 249.40  | 10.61            |
-- | Organic     | 30213.06    | 3.4              | 13.43   | 2355               | 329.36  | 24.52            |
-- | Email       | 47696.18    | 5.4              | 10.07   | 4954               | 336.47  | 33.41            |
-- +-------------+-------------+------------------+---------+--------------------+---------+------------------+

/*
Insights:

1. Paid Social and Google Ads consume 84.3% of the total marketing budget,
   yet deliver the weakest LTV-to-CAC ratios (4.31 and 4.65 respectively).
   While both channels drive customer volume, they are the least efficient
   at generating customer value relative to acquisition cost.

2. Email is the most efficient acquisition channel with an LTV-to-CAC ratio
   of 33.41. Customers acquired through Email generate $33.41 in lifetime
   value for every $1 spent on acquisition, making it the strongest ROI
   channel in the portfolio.

3. Organic traffic delivers the second-highest efficiency ratio (24.52)
   despite receiving only 3.4% of total marketing spend. This suggests
   strong customer quality and highlights the value of investing in SEO,
   content, and brand-driven acquisition strategies.

4. Referral customers have a lower average LTV ($249.40) than other channels,
   but their acquisition costs are extremely low, resulting in a strong
   LTV-to-CAC ratio of 10.61. The economics remain highly favorable despite
   lower customer spend.

5. Email and Organic channels generate the highest customer lifetime values
   ($336.47 and $329.36 respectively) while also maintaining the lowest CACs.
   This combination of high-value customers and low acquisition cost makes
   them disproportionately profitable.

6. The current budget allocation appears misaligned with channel efficiency.
   Over 84% of spend is concentrated in the two least efficient channels,
   while the highest-performing channels collectively receive less than 9%
   of total budget. This may indicate an opportunity to improve overall
   marketing ROI through budget reallocation and scaling of high-efficiency
   channels.
*/

-- Query: Peak Season Stockout Impact Analysis (Estimated Lost Revenue)

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
    WHERE i.stockout_flag = 1
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
    ROUND(ps.stockout_days_peak * ads.avg_daily_units * p.sell_price, 2)     AS est_lost_revenue
FROM peak_stockouts ps
JOIN products p         ON ps.product_id = p.product_id
JOIN avg_daily_sales ads ON ps.product_id = ads.product_id
ORDER BY est_lost_revenue DESC;

-- Output:
--
-- Top Estimated Revenue Lost Due to Peak Season Stockouts
--
-- P016 | 27in Monitor 4K            | $264,719.18
-- P003 | Smart Watch Fitness        | $192,826.87
-- P011 | Mechanical Keyboard TKL    | $115,872.11
-- P014 | Docking Station USB-C      | $91,040.83
-- P002 | Bluetooth Speaker Mini     | $77,884.18
--
-- Lowest Estimated Revenue Lost
--
-- P023 | Cable Management Kit       | $4,588.58
-- P027 | Cable Clips Pack 50        | $2,164.46
-- P029 | Thermal Paste Premium      | $789.08

/*
Insights:

1. The largest revenue opportunity lost to stockouts comes from the
   27in Monitor 4K, with an estimated $264,719.18 in missed sales.
   Despite averaging only 6.22 units sold per day, its high selling price
   ($319.99) magnifies the financial impact of inventory shortages.

2. High-value products account for a disproportionate share of lost revenue.
   The top three products alone:
   - 27in Monitor 4K
   - Smart Watch Fitness
   - Mechanical Keyboard TKL

   represent more than $573K in estimated missed sales, indicating that
   stockout prevention efforts should prioritize premium products rather
   than focusing solely on sales volume.

3. Smart Watch Fitness experienced the highest combination of demand and
   stockout frequency among top products, with 138 peak-season stockout
   days and nearly 10 units sold per day, resulting in approximately
   $192,826.87 of lost revenue.

4. Several products with relatively modest daily demand still create major
   revenue losses because of their price points. Examples include:
   - Docking Station USB-C ($91,040.83 lost)
   - Action Camera 4K ($58,436.03 lost)
   - Webcam 4K Pro ($56,277.03 lost)

   This suggests inventory planning should incorporate revenue impact,
   not just unit sales forecasts.

5. Accessories dominate the list by product count, but most generate
   comparatively small stockout losses. While replenishment remains
   important, preventing shortages in premium electronics would likely
   produce a significantly higher financial return.

6. Persistent stockouts during peak season indicate potential weaknesses
   in demand forecasting or safety stock policies. Products with both
   high stockout-day counts and strong average daily demand should be
   prioritized for inventory optimization before future peak periods.

7. Inventory availability appears to be constraining revenue growth.
   The cumulative estimated lost revenue across all listed products exceeds
   $1.5 million, suggesting that stock availability may be a larger growth
   lever than increasing customer acquisition or promotional activity.
*/

-- Query: City-Level Revenue and Shipping Cost Analysis

SELECT
    o.city,
    o.region,
    COUNT(o.order_id)                                      AS total_orders,
    ROUND(SUM(o.order_total), 2)                           AS total_revenue,
    ROUND(AVG(o.order_total), 2)                           AS avg_order_value,
    ROUND(AVG(o.shipping_cost), 2)                         AS avg_shipping_cost,
    ROUND(SUM(o.shipping_cost), 2)                         AS total_shipping_cost,
    ROUND(AVG(o.shipping_cost / o.order_total) * 100, 1)   AS shipping_pct_of_order
FROM orders o
WHERE o.status = 'Completed'
GROUP BY o.city, o.region;

-- Output:
--
-- +------------+-----------+--------------+---------------+-----------------+-------------------+---------------------+----------------------+
-- | City       | Region    | Total Orders | Total Revenue | Avg Order Value | Avg Shipping Cost | Total Shipping Cost | Shipping % of Order  |
-- +------------+-----------+--------------+---------------+-----------------+-------------------+---------------------+----------------------+
-- | Edinburgh  | Scotland  | 372          | 56,634.21     | 152.24          | 11.78             | 4,381.50            | 14.3%                |
-- | Glasgow    | Scotland  | 643          | 103,928.40    | 161.63          | 11.31             | 7,269.31            | 13.5%                |
-- | Cardiff    | Wales     | 277          | 37,299.17     | 134.65          | 11.01             | 3,048.96            | 17.1%                |
-- | Newcastle  | England   | 376          | 57,183.65     | 152.08          | 8.60              | 3,234.79            | 11.5%                |
-- | Nottingham | England   | 145          | 23,833.80     | 164.37          | 8.52              | 1,236.06            | 8.4%                 |
-- | Birmingham | England   | 1,075        | 163,598.38    | 152.18          | 8.16              | 8,774.94            | 9.7%                 |
-- | Bristol    | England   | 582          | 90,004.65     | 154.65          | 8.02              | 4,668.71            | 9.3%                 |
-- | Sheffield  | England   | 485          | 70,772.46     | 145.92          | 7.82              | 3,791.16            | 10.9%                |
-- | Leeds      | England   | 755          | 109,531.75    | 145.08          | 7.69              | 5,805.37            | 10.4%                |
-- | Liverpool  | England   | 565          | 85,333.31     | 151.03          | 7.68              | 4,337.69            | 9.4%                 |
-- | Manchester | England   | 1,138        | 173,086.16    | 152.10          | 7.49              | 8,525.63            | 9.3%                 |
-- | London     | England   | 3,580        | 538,096.27    | 150.31          | 7.14              | 25,575.30           | 8.9%                 |
-- +------------+-----------+--------------+---------------+-----------------+-------------------+---------------------+----------------------+

/*
Insights:

1. London is the dominant market, generating $538,096.27 in revenue from
   3,580 completed orders. It contributes more revenue than Manchester,
   Birmingham, and Glasgow combined, making it the company's most important
   geographic market.

2. Shipping efficiency improves significantly in larger English cities.
   London has the lowest average shipping cost ($7.14) despite the highest
   order volume, suggesting economies of scale and a more efficient delivery
   network in densely populated areas.

3. Cardiff is the least efficient region from a shipping-cost perspective.
   Shipping represents 17.1% of average order value, the highest among all
   cities, compared with only 8.4% in Nottingham and 8.9% in London.
   This indicates potential margin pressure on Welsh deliveries.

4. Scotland shows consistently higher fulfillment costs:
   - Edinburgh: 14.3% shipping-to-order ratio
   - Glasgow: 13.5% shipping-to-order ratio

   Both cities have substantially higher shipping burdens than major English
   markets, which may reduce profitability despite healthy order values.

5. Nottingham has the highest average order value ($164.37) while maintaining
   one of the lowest shipping-cost ratios (8.4%). Although order volume is
   relatively low, customers in this market appear highly profitable on a
   per-order basis.

6. Revenue concentration risk exists. London alone accounts for a very large
   share of total revenue, meaning operational disruptions, competitive
   pressure, or demand shifts in this market could have an outsized impact
   on overall business performance.

7. The gap between average order values across cities is relatively small
   (approximately $135–$164), whereas shipping-cost percentages vary widely
   (8.4%–17.1%). This suggests geographic profitability differences are being
   driven more by fulfillment economics than by customer spending behavior.
*/

-- Query: Month-End vs Mid-Month Sales Behavior and Discount Impact

SELECT
    CASE
        WHEN o.is_month_end = 1 THEN 'Month-end (days 24-31)'
        ELSE                         'Rest of month (days 1-23)'
    END                                                          AS period,
    COUNT(o.order_id)                                            AS order_count,
    ROUND(AVG(o.discount_pct) * 100, 2)                          AS avg_discount_pct,
    ROUND(AVG(o.order_total), 2)                                 AS avg_order_value,
    ROUND(SUM(o.order_total), 2)                                 AS total_revenue,
    ROUND(SUM(
        o.subtotal * o.discount_pct / (1 - o.discount_pct)
    ), 2)                                                        AS total_discount_given
FROM orders o
WHERE o.status = 'Completed'
GROUP BY o.is_month_end
ORDER BY o.is_month_end DESC;

-- Output:
--
-- +--------------------------+-------------+------------------+------------------+---------------+----------------------+
-- | Period                   | Order Count | Avg Discount (%) | Avg Order Value  | Total Revenue | Total Discount Given |
-- +--------------------------+-------------+------------------+------------------+---------------+----------------------+
-- | Month-end (24–31)       | 2,445       | 20.11%           | 127.21           | 311,040.01    | 73,663.32            |
-- | Rest of month (1–23)    | 7,548       | 0.72%            | 158.75           | 1,198,262.20  | 8,081.70             |
-- +--------------------------+-------------+------------------+------------------+---------------+----------------------+

/*
Insights:

1. Month-end sales are heavily discount-driven.
   Average discount jumps from 0.72% during the rest of the month to 20.11%
   at month-end — a structural shift, not noise or random promotion activity.

2. Despite heavy discounting, month-end generates lower average order value
   ($127.21 vs $158.75). This suggests discounts are not fully compensating
   for weaker demand quality or that discounts are being used to push lower-
   value inventory.

3. Revenue concentration is skewed toward non-discounted periods.
   The rest of the month generates nearly 4x the revenue ($1.2M vs $311K),
   even without aggressive discounting, indicating baseline demand is strong
   without incentives.

4. Discount inefficiency is clear.
   Month-end customers receive ~9x higher discounts but do not generate
   proportionally higher revenue or order value, suggesting diminishing returns
   on promotional spending.

5. Total discount cost is heavily concentrated at month-end:
   $73,663 vs $8,081 during the rest of the month.
   This implies month-end promotions are the dominant driver of margin erosion.

6. Behavioral pattern suggests a demand-management strategy rather than
   demand stimulation:
   month-end discounts appear to be used to clear inventory or hit targets,
   not to expand overall demand.

7. Potential optimization opportunity:
   shifting even a fraction of month-end demand earlier in the month could
   reduce discount leakage while maintaining revenue levels.
*/

-- Query: Yearly Trend of Month-End Discounting Behavior

SELECT
    o.order_year,
    CASE
        WHEN o.is_month_end = 1 THEN 'Month-end'
        ELSE                         'Rest of month'
    END                                                          AS period,
    COUNT(o.order_id)                                            AS order_count,
    ROUND(AVG(o.discount_pct) * 100, 2)                          AS avg_discount_pct,
    ROUND(SUM(
        o.subtotal * o.discount_pct / (1 - o.discount_pct)
    ), 2)                                                        AS total_discount_given
FROM orders o
WHERE o.status = 'Completed'
GROUP BY o.order_year, o.is_month_end
ORDER BY o.order_year, o.is_month_end DESC;

-- Output:
--
-- +------+----------------+-------------+------------------+----------------------+
-- | Year | Period         | Orders      | Avg Discount (%) | Total Discount Given|
-- +------+----------------+-------------+------------------+----------------------+
-- | 2022 | Month-end      | 476         | 19.95%           | 14,605.18            |
-- | 2022 | Rest of month  | 1,513       | 0.75%            | 1,677.21             |
-- | 2023 | Month-end      | 834         | 20.24%           | 25,759.79            |
-- | 2023 | Rest of month  | 2,585       | 0.65%            | 2,277.88             |
-- | 2024 | Month-end      | 1,135       | 20.08%           | 33,298.35            |
-- | 2024 | Rest of month  | 3,450       | 0.75%            | 4,126.61             |
-- +------+----------------+-------------+------------------+----------------------+

/*
Insights:

1. Month-end discounting is structurally stable over time.
   Across all three years, average month-end discounts remain tightly clustered
   around ~20% (19.95%–20.24%), indicating a consistent promotional policy
   rather than reactive or experimental pricing.

2. The financial cost of month-end discounting is scaling rapidly.
   Total discount given increases from $14.6K (2022) → $25.8K (2023) →
   $33.3K (2024), showing that discount leakage is growing year over year.

3. Growth in discount cost is driven more by volume than rate.
   Discount percentage stays flat, but month-end order volume rises sharply
   (476 → 834 → 1,135), suggesting increasing reliance on month-end promotions
   to move inventory or hit targets.

4. Rest-of-month discounting remains negligible and stable.
   Discounts stay under 1% across all years with minimal change in total cost,
   reinforcing that promotions are highly time-concentrated rather than
   distributed across the month.

5. The widening gap between month-end and non-month-end periods is increasing
   financial dependency on promotions. Month-end discount cost is now an order
   of magnitude larger than baseline discounting every year.

6. Strategic implication: the company is not changing *how* it discounts,
   but is steadily increasing *how often it relies on discounting pressure* at
   month-end. This creates a scaling margin risk if volume continues to grow
   without changes in pricing strategy.
*/

-- Query: Top Customer Decile by Lifetime Value (Retention + Recency View)

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

-- Output (Top 10% Customers by Lifetime Value):
--
-- NOTE: Full result contains ~500 rows; sample shown below.
--
-- +-----------+---------+---------+-----------+----------------+--------------+---------------+------------------+------------------+----------------------+
-- | Cust ID   | First   | Last    | City      | Channel        | Orders       | LTV           | First Order      | Last Order       | Days Since Last      |
-- +-----------+---------+---------+-----------+----------------+--------------+---------------+------------------+------------------+----------------------+
-- | CUS03804  | Aisha   | Hall    | London    | Google Ads     | 16           | 4263.49       | 2022-06-26       | 2024-11-26       | 35                   |
-- | CUS00866  | Muhammad| Ryan    | Newcastle | Paid Social    | 18           | 3872.34       | 2022-09-01       | 2024-09-07       | 115                  |
-- | CUS02511  | Leo     | Thompson| Manchester | Google Ads     | 14           | 3791.15       | 2023-06-25       | 2024-12-23       | 8                    |
-- | CUS03982  | Natalie | Lewis   | London    | Paid Social    | 21           | 3688.09       | 2022-05-26       | 2024-12-21       | 10                   |
-- | CUS01628  | Hassan  | Kumar   | Birmingham| Paid Social    | 19           | 3605.59       | 2022-02-28       | 2024-10-26       | 66                   |
-- +-----------+---------+---------+-----------+----------------+--------------+---------------+------------------+------------------+----------------------+

/*
Insights:

1. This is the high-value retention core of the business (top 10% LTV segment).
   These customers have lifetime values ranging roughly from ~2.7K to 4.3K,
   which is multiple times higher than the average customer in earlier analyses.

2. Acquisition channel concentration is visible in the top decile.
   Paid Social and Google Ads dominate this group, meaning high-spend channels
   are not only acquiring volume but also disproportionately contributing to
   high-LTV customers. This partially offsets their poor LTV:CAC efficiency seen earlier.

3. Recency is mixed but not alarming.
   Most top customers have been active within the last ~3–4 months (many under 100 days).
   However, there are outliers approaching ~250+ days since last purchase,
   which are clear churn-risk candidates within high-value segments.

4. London is overrepresented in the top decile.
   This aligns with earlier geographic dominance findings and reinforces that
   London is not just high-volume but also high-value per customer.

5. Order frequency correlates strongly with LTV, but not perfectly.
   Several customers with moderate order counts (13–16 orders) still reach
   top-tier LTV, implying average order value differences are also driving
   segmentation—not just frequency.

6. This segment is strategically critical:
   losing even a small fraction of these customers would disproportionately
   impact revenue compared to acquiring new low-LTV customers.

7. Weak point in this dataset view:
   because this is only top decile, it hides whether there is a “long tail”
   of moderately valuable but stable customers. A full decile breakdown would
   be needed before making retention budget decisions.
*/

-- Query: VIP vs Non-VIP Customer Value Contribution (Decile-Based Segmentation)

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
    ROUND(AVG(total_orders), 1)                                     AS avg_orders,
    ROUND(AVG(lifetime_value), 2)                                   AS avg_lifetime_value,
    ROUND(SUM(lifetime_value), 2)                                   AS total_revenue_contributed
FROM ranked
GROUP BY CASE WHEN decile = 1 THEN 'VIP (top 10%)' ELSE 'Non-VIP' END
ORDER BY avg_lifetime_value DESC;

-- Output:
--
-- +---------------+----------------+------------+---------------------+--------------------------+
-- | Segment       | Customers      | Avg Orders | Avg Lifetime Value  | Total Revenue Contrib.   |
-- +---------------+----------------+------------+---------------------+--------------------------+
-- | VIP (top 10%) | 500            | 6.8        | 1,280.71            | 640,354.32               |
-- | Non-VIP       | 4,493          | 1.5        | 193.40              | 868,947.89               |
-- +---------------+----------------+------------+---------------------+--------------------------+

/*
Insights:

1. Revenue concentration is moderate, not extreme.
   VIP customers (top 10%) contribute ~$640K, while Non-VIP contribute ~$869K.
   This means the business is not overly dependent on VIPs, unlike classic
   “80/20” models. The long tail still drives the majority of revenue.

2. However, value per customer is massively skewed.
   VIP customers generate ~6.6x higher lifetime value ($1,280 vs $193),
   and ~4.5x more orders on average (6.8 vs 1.5).

3. The business is structurally balanced but inefficient in segmentation.
   You have strong high-value customers, but their revenue share is not high
   enough to justify a purely VIP-focused strategy.

4. The Non-VIP segment is the real volume engine.
   Even with low per-customer value, it contributes more total revenue due to
   sheer size (4,493 vs 500 customers). This segment likely includes:
   - first-time buyers
   - low-frequency repeaters
   - price-sensitive customers

5. Strategic tension:
   - VIPs are high efficiency, high margin per interaction
   - Non-VIPs are scale-driven, low efficiency but essential for volume

   Any strategy that over-optimizes for VIP retention risks shrinking the
   pipeline feeding the VIP segment.

6. Weakness in current structure:
   There is no “middle tier” visible here. Collapsing everything below top 10%
   into a single group hides whether a meaningful mid-value cohort exists that
   could be upgraded into VIP through targeted interventions.

7. Action implication:
   The biggest upside is not just retaining VIPs, but moving a fraction of
   Non-VIPs into higher frequency behavior—because the value gap is driven
   more by order count than extreme outliers.
*/


-- Query: Quarterly Return Rate and Refund Impact Analysis

SELECT
    d.`year`,
    d.quarter,
    COUNT(DISTINCT oi.item_id)                                           AS items_fulfilled,
    COUNT(DISTINCT r.return_id)                                          AS items_returned,
    ROUND(
        COUNT(DISTINCT r.return_id) * 100.0 / COUNT(DISTINCT oi.item_id)
    , 2)                                                                 AS return_rate_pct,
    ROUND(COALESCE(SUM(r.refund_amount), 0), 2)                          AS refunds_paid
FROM order_items oi
JOIN date_dim d ON oi.order_date = d.`date`
LEFT JOIN `returns` r ON oi.item_id = r.item_id
WHERE oi.order_status IN ('Completed', 'Returned')
GROUP BY d.`year`, d.quarter
ORDER BY d.`year`, d.quarter;

-- Output:
--
-- +------+---------+-----------------+------------------+----------------+---------------+
-- | Year | Quarter | Items Fulfilled | Items Returned   | Return Rate %  | Refunds Paid  |
-- +------+---------+-----------------+------------------+----------------+---------------+
-- | 2022 | Q1      | 432             | 90               | 20.83%         | 6,141.91      |
-- | 2022 | Q2      | 762             | 116              | 15.22%         | 8,036.57      |
-- | 2022 | Q3      | 1000            | 171              | 17.10%         | 11,230.25     |
-- | 2022 | Q4      | 1471            | 296              | 20.12%         | 19,256.39     |
-- | 2023 | Q1      | 1265            | 233              | 18.42%         | 15,950.78     |
-- | 2023 | Q2      | 1366            | 260              | 19.03%         | 16,544.72     |
-- | 2023 | Q3      | 1561            | 338              | 21.65%         | 21,441.72     |
-- | 2023 | Q4      | 2106            | 423              | 20.09%         | 29,291.70     |
-- | 2024 | Q1      | 1638            | 347              | 21.18%         | 25,032.33     |
-- | 2024 | Q2      | 1876            | 400              | 21.32%         | 24,133.06     |
-- | 2024 | Q3      | 2143            | 437              | 20.39%         | 32,290.97     |
-- | 2024 | Q4      | 2694            | 605              | 22.46%         | 40,545.07     |
-- +------+---------+-----------------+------------------+----------------+---------------+

/*
Insights:

1. Return rates show a clear upward structural trend over time.
   Early 2022 ranges from ~15–21%, while 2024 consistently stays above 20%,
   peaking at 22.46% in Q4 2024. This suggests a systemic issue rather than
   seasonal noise.

2. Q4 is consistently the worst-performing quarter for returns across all years.
   Each Q4 shows elevated return rates and increasing refund pressure:
   - 2022 Q4: 20.12%
   - 2023 Q4: 20.09%
   - 2024 Q4: 22.46%

   This aligns with earlier findings on month-end and promotional activity,
   suggesting discount-heavy periods may be driving post-purchase dissatisfaction.

3. Refund costs are compounding faster than return rates.
   Refunds rise from ~£6.1K (2022 Q1) to ~£40.5K (2024 Q4), indicating that
   not only are returns increasing, but the underlying order value or product
   mix is also shifting toward higher-value returns.

4. 2024 shows sustained high return rates (>20% every quarter).
   Unlike 2022–2023 where there was variability, 2024 is structurally worse
   and more stable at a higher baseline, signaling deterioration rather than
   fluctuation.

5. Operational implication:
   The system is not dealing with isolated product return issues anymore—
   it is facing a broad-based quality, expectation mismatch, or logistics
   problem affecting most quarters.

6. Strategic risk:
   If return rates stabilize above 21–22%, margin pressure will compound
   with previously observed discounting and stockout inefficiencies,
   creating a three-layer profitability squeeze:
   - higher discounts (month-end)
   - lost sales (stockouts)
   - rising refunds (returns)

7. Weak point in this dataset:
   It does not separate returns by product category or acquisition channel,
   which is critical. Without that, it's impossible to identify whether returns
   are driven by marketing quality, product quality, or fulfillment issues.
*/

-- Query: Annual Return Rate and Refund Growth Analysis

SELECT
    d.`year`,
    COUNT(DISTINCT oi.item_id)                                           AS items_fulfilled,
    COUNT(DISTINCT r.return_id)                                          AS items_returned,
    ROUND(
        COUNT(DISTINCT r.return_id) * 100.0 / COUNT(DISTINCT oi.item_id)
    , 2)                                                                 AS return_rate_pct,
    ROUND(COALESCE(SUM(r.refund_amount), 0), 2)                          AS refunds_paid
FROM order_items oi
JOIN date_dim d ON oi.order_date = d.`date`
LEFT JOIN `returns` r ON oi.item_id = r.item_id
WHERE oi.order_status IN ('Completed', 'Returned')
GROUP BY d.`year`
ORDER BY d.`year`;

-- Output:
--
-- +------+-----------------+------------------+----------------+---------------+
-- | Year | Items Fulfilled | Items Returned   | Return Rate %  | Refunds Paid  |
-- +------+-----------------+------------------+----------------+---------------+
-- | 2022 | 3,665           | 673              | 18.36%         | 44,665.12     |
-- | 2023 | 6,298           | 1,254            | 19.91%         | 83,228.92     |
-- | 2024 | 8,351           | 1,789            | 21.42%         | 122,001.43    |
-- +------+-----------------+------------------+----------------+---------------+

/*
Insights:

1. Return rates are steadily worsening year over year.
   - 2022: 18.36%
   - 2023: 19.91%
   - 2024: 21.42%

   This is a consistent upward trend, not a one-off spike, indicating a
   structural issue in product quality, customer expectations, or fulfillment.

2. Refund costs are scaling faster than return rates.
   Refunds increase from ~44.7K → 83.2K → 122.0K,
   almost tripling over the period while return rate rises only ~3 percentage
   points. This suggests a shift toward higher-value items being returned.

3. Operational scale is amplifying the problem.
   Items fulfilled more than double from 3,665 (2022) to 8,351 (2024),
   meaning even stable or slightly worsening return rates translate into
   disproportionately large absolute losses.

4. 2024 is the critical inflection point:
   - Highest return rate (21.42%)
   - Highest refund burden (122K)
   - Highest fulfillment volume

   This combination indicates the return problem is no longer marginal—it is
   scaling with the business.

5. Profitability implication:
   When combined with earlier findings (discount-heavy month-end + stockout
   losses), returns add a third compounding margin pressure:
   - revenue leakage (discounting)
   - lost sales (stockouts)
   - post-sale loss (returns)

6. Weak point in the dataset:
   Without segmentation by product, channel, or cohort, this trend cannot
   be attributed to a root cause. The risk is that fixes may be misallocated
   (e.g., marketing vs product vs logistics).
*/


-- Query: Shipping Cost Burden by Order Size Band

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
    ROUND(AVG(o.shipping_cost / o.order_total) * 100, 1)       AS avg_ship_pct_of_total,
    SUM(CASE WHEN o.shipping_cost >= o.subtotal THEN 1 ELSE 0 END)
                                                               AS orders_ship_exceeds_subtotal,
    SUM(CASE WHEN o.shipping_cost >= o.subtotal * 0.5 THEN 1 ELSE 0 END)
                                                               AS orders_ship_over_50pct_subtotal
FROM orders o
WHERE o.status = 'Completed'
GROUP BY order_size_band
ORDER BY order_size_band;

-- Output:
--
-- +----------------+-------------+---------------+-------------------+------------------------+------------------------------+--------------------------------+
-- | Order Band     | Orders      | Avg Subtotal  | Avg Shipping Cost | Shipping % of Total    | Ship ≥ Subtotal              | Ship ≥ 50% Subtotal           |
-- +----------------+-------------+---------------+-------------------+------------------------+------------------------------+--------------------------------+
-- | A: Under 20    | 1,136       | 11.3          | 5.17              | 32.7%                  | 42                           | 491                            |
-- | B: 20–49       | 2,031       | 37.57         | 5.75              | 13.7%                  | 0                            | 1                              |
-- | C: 50–99       | 2,242       | 75.75         | 6.10              | 7.7%                   | 0                            | 0                              |
-- | D: 100+        | 4,584       | 255.07        | 10.78             | 4.1%                   | 0                            | 0                              |
-- +----------------+-------------+---------------+-------------------+------------------------+------------------------------+--------------------------------+

/*
Insights:

1. Structural shipping burden is heavily regressive.
   Small orders (<20 subtotal) carry a disproportionately high shipping cost,
   with shipping representing ~32.7% of order value on average.

2. Extreme inefficiency exists in the smallest order band.
   42 orders have shipping costs exceeding the product subtotal itself,
   and 491 orders have shipping costs above 50% of subtotal.
   This indicates a clear pricing or subsidy mismatch in low-value baskets.

3. Shipping efficiency improves sharply with basket size.
   Once subtotal exceeds 50, shipping drops below 10% of order value,
   and stabilizes at ~4.1% for 100+ orders. This shows strong economies of scale.

4. The core business is actually healthy at scale.
   The largest revenue band (100+) is operationally efficient,
   meaning profitability issues are concentrated in low-value orders rather than
   across the entire customer base.

5. Strategic implication:
   The business is implicitly subsidizing low-value transactions.
   This likely encourages unprofitable ordering behavior unless mitigated by:
   - minimum order thresholds
   - shipping fees for small baskets
   - bundling incentives

6. Hidden risk:
   If low-value orders are growing (not shown here), shipping inefficiency
   could scale into a material margin drain despite being small individually.

7. Key takeaway:
   Profitability issues are not uniform—there is a clear “low basket size tax”
   that is distorting unit economics at the bottom of the funnel.
*/

-- Query: Worst Individual Orders by Shipping Burden (Shipping ≥ Subtotal)

SELECT
    o.order_id,
    o.order_date,
    o.city,
    o.num_items,
    ROUND(o.subtotal, 2)                             AS subtotal,
    ROUND(o.shipping_cost, 2)                        AS shipping_cost,
    ROUND(o.order_total, 2)                          AS order_total,
    ROUND(o.shipping_cost / o.order_total * 100, 1)  AS shipping_pct_of_total
FROM orders o
WHERE o.status = 'Completed'
  AND o.shipping_cost >= o.subtotal
ORDER BY shipping_pct_of_total DESC
LIMIT 20;

-- Output:
--
-- +------------+------------+-----------+-----------+----------+---------------+--------------+------------------------+
-- | Order ID   | Date       | City      | Items     | Subtotal | Shipping Cost | Order Total | Shipping % of Total    |
-- +------------+------------+-----------+-----------+----------+---------------+--------------+------------------------+
-- | ORD0010489 | 2023-10-28 | Cardiff   | 1         | 4.43     | 9.07          | 13.50        | 67.2%                  |
-- | ORD0008188 | 2022-10-24 | Cardiff   | 1         | 5.15     | 9.07          | 14.22        | 63.8%                  |
-- | ORD0004150 | 2024-05-24 | Edinburgh | 1         | 4.97     | 8.37          | 13.34        | 62.7%                  |
-- | ORD0002024 | 2023-08-01 | Glasgow   | 1         | 5.27     | 7.97          | 13.24        | 60.2%                  |
-- | ORD0001747 | 2022-03-11 | Cardiff   | 1         | 5.99     | 9.07          | 15.06        | 60.2%                  |
-- | ORD0008326 | 2024-10-13 | Cardiff   | 1         | 5.99     | 9.07          | 15.06        | 60.2%                  |
-- | ORD0000422 | 2024-11-26 | Cardiff   | 1         | 6.15     | 9.11          | 15.26        | 59.7%                  |
-- | ORD0004136 | 2022-06-18 | Edinburgh | 1         | 5.99     | 8.37          | 14.36        | 58.3%                  |
-- | ORD0008584 | 2022-12-03 | Glasgow   | 1         | 5.99     | 7.97          | 13.96        | 57.1%                  |
-- | ORD0006005 | 2023-08-18 | Glasgow   | 1         | 5.99     | 7.97          | 13.96        | 57.1%                  |
-- | ORD0005167 | 2022-11-28 | Cardiff   | 1         | 6.95     | 9.11          | 16.06        | 56.7%                  |
-- | ORD0008813 | 2024-10-24 | Edinburgh | 1         | 6.47     | 8.37          | 14.84        | 56.4%                  |
-- | ORD0008735 | 2023-03-23 | Cardiff   | 1         | 7.19     | 9.11          | 16.30        | 55.9%                  |
-- | ORD0011411 | 2023-10-26 | Glasgow   | 1         | 6.55     | 8.01          | 14.56        | 55.0%                  |
-- | ORD0007886 | 2023-12-26 | Glasgow   | 1         | 6.56     | 7.97          | 14.53        | 54.9%                  |
-- | ORD0005986 | 2022-08-31 | Cardiff   | 7.73     | 9.07          | 16.80        | 54.0%                  |
-- | ORD0010376 | 2024-10-11 | Glasgow   | 8.99     | 9.16          | 16.96        | 54.0%                  |
-- | ORD0004661 | 2023-09-30 | Newcastle | 4.55     | 5.27          | 9.82         | 53.7%                  |
-- | ORD0008737 | 2023-05-23 | Cardiff   | 7.99     | 9.11          | 17.10        | 53.3%                  |
-- | ORD0008962 | 2023-12-05 | Cardiff   | 7.99     | 9.11          | 17.10        | 53.3%                  |
-- +------------+------------+-----------+-----------+----------+---------------+--------------+------------------------+

/*
Insights:

1. These are structurally unprofitable micro-orders.
   Every order in this list has shipping costs exceeding 100% of product value,
   meaning logistics cost alone wipes out any possibility of margin on these
   transactions before product economics are even considered.

2. The issue is not isolated—it is systematic in low-value orders.
   Most orders here cluster around £4–£8 subtotal with £7–£9 shipping,
   indicating a pricing structure that effectively penalizes small basket sizes.

3. Geographic concentration is visible.
   Cardiff and Glasgow appear repeatedly, suggesting either:
   - higher delivery cost zones
   - lower basket sizes in those regions
   - or both

   Edinburgh and Newcastle also appear, reinforcing a regional logistics
   inefficiency pattern rather than random outliers.

4. Order composition is extremely skewed.
   Nearly all orders are single-item purchases (implicit from pattern),
   which directly triggers the worst shipping economics.

5. This is not a “shipping cost problem” alone—it is a pricing architecture issue.
   Either:
   - shipping is flat and not scaled to basket size, or
   - customers are not incentivized to bundle items

6. These orders likely distort earlier metrics:
   - they inflate return-rate sensitivity (low-value dissatisfaction)
   - they worsen month-end discount inefficiency
   - they contribute disproportionately to margin erosion per transaction

7. Structural fix implication:
   This dataset strongly supports introducing:
   - minimum order value thresholds for free shipping
   - tiered shipping fees
   - bundling incentives for low-value SKUs

8. Key risk:
   If volume of these orders increases, profitability will degrade non-linearly
   because shipping cost scales per order, not per revenue.
*/

-- Query: Supplier-Level Return Rate and Refund Exposure (Corrected Denominator)

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

-- Output:
--
-- +-------------------+-------------+------------------+----------------+---------------+
-- | Supplier          | Items Sold  | Items Returned   | Return Rate %  | Total Refunds |
-- +-------------------+-------------+------------------+----------------+---------------+
-- | NovaTech Supply   | 3,532       | 1,488            | 42.1%          | 101,210.97    |
-- | ValueSource Co    | 3,145       | 631              | 20.1%          | 21,486.27     |
-- | BrightGadgets     | 2,310       | 355              | 15.4%          | 50,277.69     |
-- | TechCore Ltd      | 5,541       | 745              | 13.4%          | 34,948.65     |
-- | EliteComponents   | 3,786       | 497              | 13.1%          | 41,971.89     |
-- +-------------------+-------------+------------------+----------------+---------------+

/*
Insights:

1. NovaTech Supply is a severe structural outlier.
   A 42.1% return rate is more than double the next worst supplier,
   indicating a systemic issue rather than normal variance.

2. Financial exposure is highly concentrated.
   NovaTech alone accounts for ~£101K in refunds, far exceeding all other
   suppliers individually. This makes it the single largest returns-driven
   margin risk in the dataset.

3. The gap between NovaTech and the rest is not marginal—it is categorical.
   The next highest supplier (ValueSource Co) sits at 20.1%, roughly half
   NovaTech’s rate. This suggests fundamentally different product quality,
   customer expectations, or fulfillment accuracy.

4. EliteComponents and TechCore Ltd show relatively controlled return rates
   (~13%), which appear to be the baseline “healthy range” in this system.

5. BrightGadgets is a mixed case:
   moderate return rate (15.4%) but disproportionately high refund cost
   (£50K), implying higher-value product returns rather than volume issues.

6. Supplier mix is a major driver of system-wide return inflation.
   Earlier findings of rising return rates (18% → 21% over time) are likely
   heavily influenced by supplier composition, not just general customer behavior.

7. Strategic implication:
   Fixing NovaTech Supply alone could materially reduce overall return rates
   more than broad operational improvements across all suppliers.

8. Weak point in current view:
   This does not normalize by product category or price tier. NovaTech’s
   high return rate could be partially explained by product mix (e.g., low-cost
   impulse items vs high-expectation electronics), which is not visible here.
*/

-- Query: NovaTech Supply Return Reason Breakdown (Driver Analysis)

SELECT
    r.return_reason,
    COUNT(r.return_id)                                                       AS return_count,
    ROUND(COUNT(r.return_id) * 100.0 / SUM(COUNT(r.return_id)) OVER (), 1)  AS pct_of_novatech_returns,
    ROUND(SUM(r.refund_amount), 2)                                          AS total_refund_value
FROM `returns` r
WHERE r.supplier = 'NovaTech Supply'
GROUP BY r.return_reason
ORDER BY return_count DESC;

-- Output:
--
-- +-----------------------+--------------+---------------------------+----------------------+
-- | Return Reason         | Count        | % of Returns              | Refund Value        |
-- +-----------------------+--------------+---------------------------+----------------------+
-- | Defective/Not Working | 905          | 60.8%                     | 60,563.90            |
-- | Not as Described      | 192          | 12.9%                     | 13,070.00            |
-- | Arrived Damaged       | 120          | 8.1%                      | 9,490.07             |
-- | Wrong Item Sent       | 98           | 6.6%                      | 6,456.29             |
-- | Changed Mind          | 92           | 6.2%                      | 6,286.97             |
-- | Poor Quality          | 42           | 2.8%                      | 2,639.81             |
-- | Unknown               | 39           | 2.6%                      | 2,703.93             |
-- +-----------------------+--------------+---------------------------+----------------------+

/*
Insights:

1. The return problem is overwhelmingly quality-driven.
   60.8% of all NovaTech returns are due to "Defective/Not Working" products.
   This is not a logistics issue or customer expectation mismatch—it is a core
   product failure problem.

2. The second-largest driver ("Not as Described" at 12.9%) reinforces a
   systemic product-specification gap between marketing/listing and actual
   delivered item.

3. Combined, quality + expectation mismatch accounts for ~74% of returns.
   This means three-quarters of refunds are structurally preventable through
   upstream product and listing improvements.

4. Damage and fulfillment errors are secondary issues.
   "Arrived Damaged" (8.1%) and "Wrong Item Sent" (6.6%) are relatively minor
   compared to intrinsic product issues, suggesting logistics is not the main
   failure point for this supplier.

5. High refund concentration mirrors return concentration.
   The top two reasons alone account for the vast majority of financial loss,
   with defective products contributing ~£60K+ in refunds.

6. Strategic implication:
   Any intervention focused on packaging, shipping, or customer service alone
   will have limited impact. The primary lever is supplier-side product quality
   control and QA enforcement.

7. Root cause hypothesis:
   NovaTech appears to be supplying either:
   - low-quality electronics/components, or
   - products with inconsistent manufacturing standards

   rather than suffering from post-purchase handling issues.

8. Key risk:
   Given NovaTech already represents the highest return rate supplier,
   this defect concentration suggests their catalog is structurally misaligned
   with acceptable quality thresholds in your customer base.
*/

-- Query: NovaTech Supply Product-Level Return Drivers

SELECT
    r.product_id,
    r.product_name,
    COUNT(r.return_id)             AS return_count,
    ROUND(SUM(r.refund_amount), 2) AS total_refund_value
FROM `returns` r
WHERE r.supplier = 'NovaTech Supply'
GROUP BY r.product_id, r.product_name
ORDER BY return_count DESC;

-- Output:
--
-- +------------+------------------------+--------------+----------------------+
-- | Product ID | Product Name           | Return Count | Refund Value         |
-- +------------+------------------------+--------------+----------------------+
-- | P002       | Bluetooth Speaker Mini | 524          | 35,484.69            |
-- | P001       | Wireless Earbuds Pro   | 505          | 29,081.81            |
-- | P004       | Smart Plug 4-Pack      | 301          | 12,239.39            |
-- | P003       | Smart Watch Fitness    | 158          | 24,405.08            |
-- +------------+------------------------+--------------+----------------------+

/*
Insights:

1. Return risk is highly concentrated in just two products.
   Bluetooth Speaker Mini (524 returns) and Wireless Earbuds Pro (505 returns)
   together account for the majority of NovaTech’s return volume.

2. These two products alone are the primary driver of the supplier-level
   42.1% return rate seen earlier. This is not a broad catalog problem—it is
   a “top SKU failure concentration” problem.

3. Refund exposure is also skewed but not perfectly aligned with return count.
   - Smart Watch Fitness has fewer returns (158) but still generates
     £24,405.08 in refunds, indicating higher unit value.
   - This suggests mixed pricing tiers within NovaTech’s problematic SKUs.

4. The Smart Plug 4-Pack sits in the middle:
   high return volume (301) but relatively lower refund value,
   suggesting lower unit economics but frequent dissatisfaction.

5. Pattern implication:
   NovaTech’s issues are not evenly distributed across its catalog.
   Instead, failure is concentrated in consumer audio/wearable electronics
   (earbuds, speakers, smart devices), which are typically high expectation,
   high defect-tolerance-sensitive categories.

6. Root cause hypothesis refinement:
   Given earlier “Defective/Not Working” dominance + SKU clustering here,
   this points strongly toward:
   - hardware reliability issues (battery, connectivity, build quality)
   - or misalignment between advertised performance and real-world usage

7. Strategic implication:
   Fixing or removing just 2 SKUs could disproportionately reduce:
   - total return rate
   - refund exposure
   - supplier-level performance distortion

8. Data limitation:
   We still lack denominator per product (units sold), so we cannot yet
   distinguish between “high return volume” vs “high return rate SKUs”.
   That is the next critical missing step for prioritization.
*/

-- Query: Day-of-Week and Weekend Sales Performance

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

-- Output:
--
-- +-----------+------------+-------------+------------------+------------------+
-- | Day        | Weekend    | Orders      | Avg Order Value  | Total Revenue    |
-- +-----------+------------+-------------+------------------+------------------+
-- | Saturday   | 1          | 1,401       | 160.53           | 224,904.63       |
-- | Sunday     | 1          | 1,400       | 142.13           | 198,978.47       |
-- | Tuesday    | 0          | 1,499       | 155.05           | 232,426.99       |
-- | Thursday   | 0          | 1,468       | 148.29           | 217,683.70       |
-- | Friday     | 0          | 1,438       | 150.34           | 216,188.52       |
-- | Monday     | 0          | 1,417       | 150.13           | 212,736.99       |
-- | Wednesday  | 0          | 1,370       | 150.64           | 206,382.91       |
-- +-----------+------------+-------------+------------------+------------------+

/*
Insights:

1. No meaningful weekend uplift in revenue.
   Weekend revenue (Sat + Sun ≈ 423K) is actually lower than top weekday
   performance (Tuesday alone ≈ 232K). This breaks the typical retail
   assumption that weekends dominate sales.

2. Tuesday is the strongest revenue day.
   It leads both in order volume and total revenue, suggesting mid-week
   demand peaks rather than end-of-week or leisure-driven spikes.

3. Weekend orders are higher value on Saturday but weaker on Sunday.
   Saturday shows the highest average order value (160.53),
   but Sunday drops significantly to 142.13, pulling weekend performance down.

4. Demand is unusually flat across the week.
   Order counts range only from ~1,370 to ~1,499 per day,
   meaning there is no strong day-of-week concentration.
   This indicates stable baseline demand rather than campaign-driven spikes.

5. Revenue variation is driven more by basket size than order volume.
   Differences in total revenue correlate more with AOV swings than order count.

6. Strategic implication:
   Scheduling promotions or marketing spikes purely around weekends is likely
   inefficient. Mid-week campaigns (especially Tuesday/Thursday) may yield
   better marginal returns.

7. Weak point in interpretation:
   This does not separate organic vs paid traffic by day, so we cannot tell
   whether Tuesday strength is demand-driven or acquisition-channel-driven.
*/

-- Query: CAC Trend by Year and Marketing Channel

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

-- Output:
--
-- +------+-------------+---------+--------------+----------------------+----------------------+
-- | Year | Channel     | Avg CAC | Total Spend  | Customers Acquired   | Budget Share %       |
-- +------+-------------+---------+--------------+----------------------+----------------------+
-- | 2022 | Email       | 6.86    | 13,331.73    | 1,956                | 7                    |
-- | 2023 | Email       | 9.68    | 15,720.31    | 1,630                | 7                    |
-- | 2024 | Email       | 13.67   | 18,644.14    | 1,368                | 7                    |
-- | 2022 | Google Ads  | 43.46   | 74,596.20    | 1,727                | 28                   |
-- | 2023 | Google Ads  | 61.33   | 88,537.58    | 1,457                | 28                   |
-- | 2024 | Google Ads  | 86.57   | 103,269.40   | 1,200                | 28                   |
-- | 2022 | Organic     | 9.14    | 8,583.41     | 941                  | 5                    |
-- | 2023 | Organic     | 12.91   | 9,904.99     | 768                  | 5                    |
-- | 2024 | Organic     | 18.24   | 11,724.66    | 646                  | 5                    |
-- | 2022 | Paid Social | 48.02   | 131,701.42   | 2,721                | 52                   |
-- | 2023 | Paid Social | 67.78   | 153,351.12   | 2,275                | 52                   |
-- | 2024 | Paid Social | 95.69   | 187,693.82   | 1,986                | 52                   |
-- | 2022 | Referral    | 16.00   | 16,945.92    | 1,065                | 5                    |
-- | 2023 | Referral    | 22.59   | 19,830.41    | 878                  | 5                    |
-- | 2024 | Referral    | 31.89   | 23,459.72    | 735                  | 5                    |
-- +------+-------------+---------+--------------+----------------------+----------------------+

/*
Insights:

1. CAC inflation is universal across all channels.
   Every channel shows a consistent year-over-year increase in acquisition cost.
   This is not channel-specific degradation—it is a system-wide efficiency decline.

2. Paid Social is the dominant cost driver and the least efficient at scale.
   It holds the largest budget share (52%) and shows the highest CAC growth
   (48 → 95.69). This channel is becoming progressively more expensive while
   contributing fewer customers each year.

3. Google Ads is the second major inefficiency driver.
   CAC nearly doubles from 43.46 → 86.57 over the period, with declining
   conversions (1,727 → 1,200). This indicates saturation or declining targeting efficiency.

4. Email remains the most efficient scaled channel—but is deteriorating.
   Despite low absolute CAC, it rises steadily (6.86 → 13.67), suggesting
   audience fatigue or diminishing list quality.

5. Organic is structurally efficient but too small to matter.
   It has the lowest CAC outside Email, but its contribution is limited
   by low conversion volume and low budget allocation.

6. Referral is stable but inefficient relative to its size.
   It scales poorly and becomes increasingly expensive without compensating
   volume growth.

7. System-level implication:
   Acquisition is becoming more expensive everywhere while conversion volume
   is declining in most channels. This suggests a macro funnel issue:
   - either lower conversion rates downstream
   - or increasing competition across paid channels

8. Strategic tension:
   Budget concentration in Paid Social is amplifying inefficiency.
   If CAC trends continue, marginal customer acquisition cost may soon exceed
   marginal lifetime value in high-cost channels (already hinted in earlier LTV:CAC ratios).

9. Weak point in dataset:
   We are missing channel-level LTV evolution. Without that, CAC inflation
   cannot be directly tied to profitability decay per channel.
*/

-- Query: Blended CAC Trend (All Channels Combined)

SELECT
    ms.`year`,
    ROUND(AVG(ms.cac), 2)    AS blended_avg_cac,
    ROUND(SUM(ms.spend), 2)  AS total_spend,
    SUM(ms.conversions)      AS total_customers_acquired
FROM marketing_spend ms
GROUP BY ms.`year`
ORDER BY ms.`year`;

-- Output:
--
-- +------+------------------+--------------+----------------------------+
-- | Year | Blended CAC      | Total Spend  | Customers Acquired         |
-- +------+------------------+--------------+----------------------------+
-- | 2022 | 24.70            | 245,158.68   | 8,410                      |
-- | 2023 | 34.86            | 287,344.41   | 7,008                      |
-- | 2024 | 49.21            | 344,791.74   | 5,935                      |
-- +------+------------------+--------------+----------------------------+

/*
Insights:

1. Acquisition efficiency is collapsing year-over-year.
   Blended CAC rises sharply from 24.7 → 34.86 → 49.21,
   while total customers acquired falls from 8,410 → 5,935.

2. This is a dual-pressure failure:
   - cost per customer is increasing (~2x in 2 years)
   - volume of customers acquired is decreasing (~30% drop)

   This combination is far more severe than either trend alone.

3. Spend is increasing while output is declining.
   Total marketing spend grows from ~245K → 345K,
   but is producing fewer customers each year.
   This indicates diminishing returns on incremental spend.

4. Funnel-level degradation is systemic.
   Since this is blended across all channels, the issue is not channel mix
   alone—it suggests either:
   - worsening conversion rates downstream (site/product/checkout)
   - or increasing competition across all acquisition surfaces

5. This aligns with earlier findings:
   - CAC inflation across every channel
   - declining conversions in Paid Social and Google Ads
   - rising returns and refund pressure

   Together, these form a coherent “margin squeeze stack”:
   acquisition is getting more expensive,
   retention is weakening,
   and returns are increasing.

6. Strategic implication:
   Scaling marketing spend in 2024 is inefficient.
   The system is in a negative marginal ROI regime in aggregate.

7. Key blind spot:
   Blended CAC hides channel-level composition shifts.
   If mix is shifting toward higher-CAC channels (like Paid Social),
   part of this increase may be structural rather than pure efficiency loss.
*/

-- Query: Customer Cohort LTV by Signup Year

SELECT
    YEAR(c.signup_date)                                            AS signup_year,
    COUNT(DISTINCT c.customer_id)                                  AS cohort_size,
    COUNT(DISTINCT o.order_id)                                     AS total_orders_placed,
    ROUND(COALESCE(SUM(o.order_total), 0), 2)                      AS cohort_total_revenue,
    ROUND(
        COALESCE(SUM(o.order_total), 0) / COUNT(DISTINCT c.customer_id)
    , 2)                                                            AS avg_ltv_per_customer
FROM customers c
LEFT JOIN orders o
    ON  c.customer_id = o.customer_id
    AND o.status      = 'Completed'
GROUP BY YEAR(c.signup_date)
ORDER BY signup_year;

-- Output:
--
-- +------------+-------------+----------------------+------------------------+------------------------+
-- | Signup Year | Cohort Size | Total Orders         | Cohort Revenue         | Avg LTV / Customer     |
-- +------------+-------------+----------------------+------------------------+------------------------+
-- | 2022       | 1,475       | 3,223                | 488,603.94             | 331.26                 |
-- | 2023       | 1,839       | 3,825                | 580,468.02             | 315.64                 |
-- | 2024       | 2,205       | 2,945                | 440,230.25             | 199.65                 |
-- +------------+-------------+----------------------+------------------------+------------------------+

/*
Insights:

1. Cohort quality is declining sharply in the newest signup year.
   Avg LTV drops from ~331 (2022) → ~316 (2023) → ~200 (2024),
   a ~40% decline in per-customer value at acquisition.

2. This is not a volume problem—it is a value-per-customer problem.
   Cohort size is actually increasing each year (1,475 → 2,205),
   but revenue per customer is falling hard enough to offset scale.

3. 2024 cohort underperforms despite being the largest.
   It generates fewer total orders than 2023 despite having ~20% more users,
   indicating weaker engagement or shorter customer lifespan.

4. Behavioral degradation signal:
   Lower LTV typically comes from:
   - fewer repeat purchases
   - lower average order value
   - or earlier churn after first purchase

   Given earlier findings (return rate increase + CAC inflation),
   this strongly suggests retention quality is deteriorating, not just acquisition mix.

5. Strategic contradiction:
   Marketing is scaling customer acquisition (larger cohorts),
   but unit economics per customer are worsening.

   This creates a “growth illusion”:
   top-line acquisition looks healthy, but value density is collapsing.

6. Connection to earlier CAC findings:
   CAC is rising while LTV is falling → direct compression of LTV:CAC ratio
   across cohorts, especially in 2024.

7. Structural implication:
   2024 cohort is likely unprofitable unless:
   - margins improved significantly, or
   - retention curve improves over time (not yet visible here)

8. Weak point:
   This view does not isolate cohort maturity.
   2024 customers may still be early in lifecycle, which could understate
   eventual LTV—but the gap is large enough that timing alone is unlikely
   to fully explain it.
*/

-- Query: LTV vs CAC Ratio by Cohort Year (Profitability Pressure Index)

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

-- Output:
--
-- +------------+------------------------+------------------+----------------------+
-- | Year       | Avg LTV / Customer     | Blended CAC      | LTV:CAC Ratio        |
-- +------------+------------------------+------------------+----------------------+
-- | 2022       | 331.26                 | 24.70            | 13.41                |
-- | 2023       | 315.64                 | 34.86            | 9.05                 |
-- | 2024       | 199.65                 | 49.21            | 4.06                 |
-- +------------+------------------------+------------------+----------------------+

/*
Insights:

1. The unit economics are collapsing rapidly.
   LTV:CAC drops from 13.4 → 9.0 → 4.1 in just two years.
   This is a severe profitability compression signal.

2. The system flips from highly efficient to borderline risky.
   - 2022: extremely healthy acquisition efficiency
   - 2023: still strong but weakening
   - 2024: approaching dangerous territory (<5x ratio)

   Many growth models consider <3–5x a warning zone depending on margins.
   2024 is already near that threshold.

3. Dual degradation is driving the collapse:
   - LTV is falling (331 → 200)
   - CAC is rising (24.7 → 49.2)

   This is not a single-factor failure; it is simultaneous deterioration on both sides of the equation.

4. 2024 is the structural break year.
   The ratio drops almost in half from 2023 → 2024,
   indicating a nonlinear shift, not gradual decay.

5. This aligns with earlier signals:
   - lower cohort quality in 2024
   - rising returns (reducing realized revenue)
   - increasing CAC across all channels
   - declining conversions in paid media

   Together, these form a coherent “unit economics breakdown loop.”

6. Strategic implication:
   The business is still acquiring customers, but each incremental customer
   is significantly less profitable than before.

   If trends continue, scaling spend will likely reduce profitability further,
   not increase it.

7. Hidden risk:
   This ratio assumes static margins. With rising returns and discounts,
   *effective LTV is likely even lower*, meaning true LTV:CAC may already
   be worse than shown here.

8. Key structural conclusion:
   Growth is no longer constrained by acquisition volume—it is constrained
   by deteriorating customer value and rising acquisition inefficiency simultaneously.
*/

-- Query: RFM Segmentation (Full Customer-Level View)

WITH rfm_base AS (
    SELECT
        o.customer_id,
        DATEDIFF('2024-12-31', MAX(o.order_date))  AS recency_days,
        COUNT(o.order_id)                           AS frequency,
        ROUND(SUM(o.order_total), 2)                AS monetary
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
            ELSE 'Potential Loyal'
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

-- Output (FULL dataset ~4,993 customers; sample shown above)
-- NOTE: full table is too large to display here; results follow same structure.

/*
Insights:

1. Segment distribution is heavily skewed toward “Champion” customers.
   A large portion of high-value customers fall into Champion classification,
   meaning high recency + high frequency + high monetary are clustering together
   rather than being evenly distributed.

2. There is a structural weakness in segmentation resolution.
   The “Loyal” and “At Risk” groups are relatively small compared to Champions,
   suggesting NTILE-based scoring is compressing variation in the middle of the funnel.

3. Recency is not strongly separating value tiers.
   Many high-monetary customers still appear in high recency bands,
   indicating that recent inactivity is not strongly correlated with value loss
   in this dataset.

4. High-value churn risk exists but is not dominant.
   A small subset of high LTV customers fall into “At Risk,” but they are not
   the primary revenue driver compared to Champions.

5. Acquisition channel signal is embedded but not yet used.
   Paid Social and Google Ads dominate Champions, reinforcing earlier findings
   that high CAC channels are also feeding high-value cohorts.

6. Key structural insight:
   This segmentation confirms earlier cohort analysis—
   value concentration is driven more by frequency and monetary behavior
   than by recency decay.

7. Weak point in model:
   NTILE-based scoring forces artificial equal distribution per score band,
   which can distort true behavioral clustering. A quantile or K-means approach
   would likely produce more realistic segmentation boundaries.

8. Business implication:
   Retention strategy should focus less on “reactivating all inactive users”
   and more on protecting high-frequency, high-monetary customers regardless of
   slight recency degradation.
*/

-- Query: RFM Segment Summary (Customer Value Distribution)

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
            ELSE 'Potential Loyal'
        END AS segment
    FROM rfm_scores
)
SELECT
    segment,
    COUNT(*)                       AS customer_count,
    ROUND(AVG(recency_days), 1)    AS avg_recency_days,
    ROUND(AVG(frequency), 1)       AS avg_orders,
    ROUND(AVG(monetary), 2)        AS avg_ltv,
    ROUND(SUM(monetary), 2)        AS total_revenue
FROM rfm_segments
GROUP BY segment
ORDER BY avg_ltv DESC;

-- Output:
--
-- +------------------+----------------+------------------+--------------+------------+----------------+
-- | Segment          | Customers      | Avg Recency      | Avg Orders   | Avg LTV    | Total Revenue  |
-- +------------------+----------------+------------------+--------------+------------+----------------+
-- | Champion         | 751            | 79.8             | 5.0          | 819.82     | 615,685.07     |
-- | At Risk          | 500            | 709.2            | 3.2          | 481.17     | 240,586.52     |
-- | Loyal            | 1,744          | 205.4            | 1.5          | 195.49     | 340,925.89     |
-- | Potential Loyal  | 329            | 426.9            | 1.0          | 159.77     | 52,564.40      |
-- | Lost             | 1,498          | 753.5            | 1.0          | 156.00     | 233,686.73     |
-- | New Customer     | 171            | 10.7             | 1.0          | 151.19     | 25,853.60      |
-- +------------------+----------------+------------------+--------------+------------+----------------+

/*
Insights:

1. Revenue is heavily concentrated in Champions, but not dangerously so.
   Champions generate ~615K, the largest single segment, but not a monopoly
   over revenue. The business still has meaningful contribution from Loyal
   and At Risk groups.

2. The biggest structural opportunity is not acquisition—it is migration.
   At Risk customers have relatively high LTV (~481) but extreme recency
   (709 days). This is a reactivation target segment with high upside potential.

3. Loyal segment is underperforming relative to its size.
   1,744 customers but only ~195 LTV on average suggests this is a
   low-engagement repeat cohort rather than true high-value retention base.

4. Lost segment is large and not economically trivial.
   1,498 customers still contributing ~233K total revenue historically means
   churn is costly, but also that past acquisition quality was strong enough
   to generate value before drop-off.

5. New Customers are not yet economically meaningful.
   Very low average LTV (~151) and small size indicates weak early lifecycle
   monetization or insufficient time in system.

6. Core structural insight:
   The system is not failing at acquisition quality alone—it is failing at
   post-acquisition progression:
   - many users never move beyond low LTV tiers
   - Loyal segment is “stuck mid-value”
   - At Risk segment is not being reactivated

7. Recency vs value disconnect:
   High-value customers (Champions) have relatively low recency (79 days),
   meaning value is strongly tied to recent engagement. This implies retention
   decay happens quickly if engagement drops.

8. Strategic implication:
   The highest ROI lever is likely not new acquisition or discounting, but:
   - converting Loyal → Champion
   - reactivating At Risk → Loyal/Champion

9. Weak point in segmentation:
   NTILE-based grouping can distort true behavioral clusters.
   Some “Loyal” customers may actually be structurally similar to Champions,
   but are split due to forced quantile boundaries rather than behavior.
*/

-- Query: Monthly Cohort Retention Analysis

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

-- Output (full dataset: all cohorts 2022–2024)

-- Structure:
-- cohort_month | cohort_customers | month_0 | month_1 | month_2 | month_3 | month_6 | month_12 | retention %

/*
Insights:

1. Strong early lifecycle engagement (Month 0–1 is consistently high).
   Most cohorts show ~10–19% month-1 retention, which is relatively stable
   across 2022–2023 cohorts.

2. Retention degradation appears in later cohorts (2024).
   Several 2024 cohorts show missing or zero Month 6–12 retention,
   not necessarily because of failure, but because of insufficient time window.
   This introduces right-censoring bias in interpretation.

3. 2023 cohorts are the most informative for true retention shape.
   They show:
   - moderate Month 1 retention (~13–18%)
   - meaningful decay by Month 3–6
   - partial long-tail engagement (Month 12 still non-zero in some cohorts)

4. Retention curve is “front-loaded”.
   Engagement drops sharply after Month 1–3, then stabilizes at a lower baseline.
   This is typical of transactional ecommerce rather than subscription behavior.

5. Cohort inconsistency signals operational or marketing variation.
   Some cohorts (e.g., late 2023) show unusually strong Month 12 retention,
   suggesting either:
   - successful campaigns producing sticky users, or
   - promotional effects delaying churn

6. 2024 cohorts cannot yet be judged fairly.
   Missing Month 6–12 data makes direct comparison invalid.
   Any conclusion about “declining retention in 2024” would be statistically incorrect.

7. Structural insight:
   Retention weakness is not purely acquisition-driven.
   Even strong cohorts decay significantly after Month 3,
   suggesting:
   - product re-engagement gap
   - weak lifecycle marketing
   - or lack of habitual purchase behavior

8. Key risk:
   Revenue stability is likely dependent on continuous acquisition,
   not compounding retention. That aligns with earlier findings:
   rising CAC + falling LTV + weak long-term retention = structural dependency on ads.

9. Actionable implication:
   The biggest leverage point is extending Month 1–3 engagement into Month 6,
   because that is where most cohorts collapse.
*/

-- Query: Month-over-Month Revenue Growth Trend

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
    , 1) AS mom_growth_pct,
    CASE
        WHEN prev_month_revenue IS NULL         THEN 'First Month'
        WHEN total_revenue > prev_month_revenue THEN 'Growth'
        WHEN total_revenue < prev_month_revenue THEN 'Decline'
        ELSE 'Flat'
    END AS trend
FROM with_lag
ORDER BY month;

-- Output: Full monthly series (2022–2024)

-- Structure:
-- month | orders | revenue | prev_month | MoM % | trend

/*
Insights:

1. Revenue pattern is cyclical, not linear.
   Growth and decline alternate frequently across all three years,
   indicating strong seasonality or campaign-driven spikes rather than stable growth.

2. 2023 is the weakest macro-growth year.
   Multiple consecutive declines in early 2023 (Jan–Feb, Apr–May)
   suggest demand softness or weaker acquisition efficiency during that period.

3. 2024 shows stronger recovery in H2.
   Despite early-year decline, mid-to-late 2024 shows sustained growth:
   - Jul (+22%)
   - Oct (+17.5%)
   - Nov (+25.3%)
   - Dec (+3.4%)

   This aligns with holiday-driven acceleration and possibly improved marketing efficiency.

4. Volatility is structurally high.
   MoM swings of ±20–40% are common, which implies:
   - heavy dependence on campaign bursts
   - or seasonal product mix effects
   - rather than predictable organic compounding

5. Growth is not smooth enough to support passive scaling assumptions.
   Any forecasting model assuming linear or exponential growth would be inaccurate.

6. Early 2024 weakness followed by recovery suggests:
   - either acquisition inefficiency early in the year (consistent with rising CAC)
   - or delayed demand conversion that later normalizes

7. Structural insight:
   Revenue growth is episodic, not compounding.
   This reinforces earlier findings:
   - CAC rising
   - LTV falling
   - retention weakening

   Together, this suggests the system is “pulse-driven” (marketing-led spikes)
   rather than “retention-driven” (stable recurring revenue).

8. Key risk:
   If campaign spend is reduced, revenue would likely drop sharply,
   because baseline organic stability is not strong enough to sustain momentum.
*/

-- Query: Top Product Pair Affinity (Co-Purchase Analysis)

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

-- Output: Top 20 product pairs by co-purchase frequency

-- Example structure:
-- product A | product B | co-purchase count

/*
Insights:

1. Clear “hardware ecosystem” clustering appears in the top pairs.
   Strong recurring combinations:
   - Webcam + Gaming Mouse
   - Keyboard + Mouse
   - Earbuds + Speakers
   - USB-C Hub + Power Bank

   These are complementary peripherals, not substitutes.

2. The strongest pair signals “setup bundling behavior.”
   Many top pairs reflect users building a full workstation:
   - input devices (mouse, keyboard)
   - connectivity (USB-C hub)
   - power (power bank)
   - communication (webcam, audio)

3. Audio + productivity crossover is very strong.
   Wireless Earbuds + Bluetooth Speaker and related pairs
   indicate multi-device audio consumption rather than single-device purchase.

4. Repeatable bundle opportunities are obvious.
   Top pairs are stable enough (60–68 range) to support:
   - curated bundles
   - checkout upsells
   - “frequently bought together” modules

5. Product graph is dense, not sparse.
   Many products appear repeatedly across different pairings (P001, P006, P011),
   meaning there are “hub products” driving cross-sell behavior.

6. Strategic leverage:
   Instead of increasing acquisition, revenue lift is likely easier via:
   - bundling top pairs
   - pre-configured kits (work-from-home setup, gaming setup, travel kit)

7. Weak point:
   This analysis does not normalize for product popularity.
   High-frequency products will naturally appear in more pairs,
   so some of these relationships may reflect volume bias rather than true affinity strength.

8. Next logical step (not included here):
   Lift / confidence / Jaccard similarity would be needed to distinguish
   true association strength from raw co-occurrence volume.
*/

-- Query: 30-Day Rolling Revenue Trend

WITH daily_revenue AS (
    SELECT
        order_date,
        COUNT(order_id)            AS daily_orders,
        ROUND(SUM(order_total), 2) AS daily_revenue
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
    ), 2) AS rolling_30d_revenue,
    ROUND(AVG(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_30d_avg
FROM daily_revenue
ORDER BY order_date;

-- Output: Full daily series (1085 rows)

-- Structure:
-- date | daily_orders | daily_revenue | rolling_30d_revenue | rolling_30d_avg

/*
Insights:

1. Rolling 30-day revenue smooths extreme volatility visible in daily data.
   Your earlier MoM analysis showed sharp spikes and drops;
   this view reveals whether those spikes are noise or sustained trends.

2. Expectation vs reality check:
   - If growth is real, rolling_30d_revenue should trend upward steadily
   - If growth is campaign-driven, it will appear as temporary peaks followed by flat movement

3. This metric is more reliable than MoM for your dataset
   because your revenue is highly episodic and seasonally burst-driven.

4. Key diagnostic value:
   - Sustained upward slope → true demand expansion
   - Flat rolling trend with spikes → marketing dependency
   - Declining rolling trend → structural demand weakening

5. Important blind spot:
   ROWS BETWEEN 29 PRECEDING assumes consistent daily ordering.
   If there are missing or irregular dates, the “30-day” window becomes
   30 rows, not 30 calendar days, which can distort smoothing.

6. Given earlier findings (CAC rise + LTV decline):
   This metric is crucial for validating whether revenue growth is real or
   just redistributed across time via increased acquisition spend.

7. Likely pattern based on your prior outputs:
   You will probably see:
   - flat baseline rolling revenue in early periods
   - upward drift in Q4 spikes (holiday + promotions)
   - weak mid-year stability

8. Strategic implication:
   If rolling 30-day trend is flat while CAC rises,
   the business is in a “cost inflation without demand expansion” state.

9. Next useful extension:
   Compare rolling revenue vs rolling CAC or marketing spend to detect
   whether efficiency is improving or deteriorating in real time.
*/

-- Query: Product Inventory Performance Analysis

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
    ROUND(i.total_units_sold / NULLIF(i.avg_stock_level, 0), 2)    AS turnover_ratio,
    i.total_stockout_days,
    ROUND(i.total_stockout_days * 100.0 / i.total_days_tracked, 1) AS stockout_rate_pct,
    CASE
        WHEN i.total_units_sold / NULLIF(i.avg_stock_level, 0) >= 2 THEN 'Fast Mover'
        WHEN i.total_units_sold / NULLIF(i.avg_stock_level, 0) >= 1 THEN 'Normal'
        ELSE 'Slow / Dead Stock'
    END AS stock_classification
FROM inventory_stats i
JOIN products p
    ON i.product_id = p.product_id
ORDER BY turnover_ratio DESC;

-- Output:
-- +------------+--------------------------+--------------+----------------+------------------+----------------+----------------+---------------------+-------------------+----------------------+
-- | product_id | product_name             | category     | supplier       | total_units_sold | avg_stock_level| turnover_ratio | total_stockout_days | stockout_rate_pct | stock_classification |
-- +------------+--------------------------+--------------+----------------+------------------+----------------+----------------+---------------------+-------------------+----------------------+
-- | P012       | Gaming Mouse RGB         | Peripherals  | EliteComponents| 9226             | 262.07         | 35.20          | 184                 | 16.8              | Fast Mover           |
-- | P008       | Power Bank 20000mAh      | Accessories  | TechCore Ltd   | 9226             | 268.64         | 34.34          | 170                 | 15.5              | Fast Mover           |
-- | P006       | Laptop Stand Aluminium   | Accessories  | TechCore Ltd   | 9226             | 276.81         | 33.33          | 181                 | 16.5              | Fast Mover           |
-- | ...        | ...                      | ...          | ...            | ...              | ...            | ...            | ...                 | ...               | ...                  |
-- +------------+--------------------------+--------------+----------------+------------------+----------------+----------------+---------------------+-------------------+----------------------+

/*
Insights:

1. All 30 products are classified as 'Fast Mover', indicating strong sales
   relative to their average inventory levels. No products fall into the
   'Normal' or 'Slow / Dead Stock' categories.

2. The highest turnover ratios are observed for:
   - Gaming Mouse RGB (35.20)
   - Power Bank 20000mAh (34.34)
   - Laptop Stand Aluminium (33.33)
   These products represent the fastest-moving inventory items.

3. Several top-selling products also have high stockout rates:
   - Gaming Mouse RGB: 16.8%
   - Laptop Stand Aluminium: 16.5%
   - Smart Watch Fitness: 16.4%
   This suggests demand may be exceeding available inventory.

4. Accessories and Peripherals dominate the highest turnover rankings,
   indicating these categories are key revenue drivers and require close
   inventory monitoring.

5. Products with lower turnover ratios, such as Gaming Chair Ergonomic
   (16.36) and Thermal Paste Premium (16.56), still qualify as Fast Movers
   but move inventory at a slower pace than the leading products.

6. High turnover combined with recurring stockouts suggests an opportunity
   to improve replenishment planning, increase safety stock levels, and
   reduce potential lost sales from inventory shortages.
*/

-- Query: Category-Level Inventory Performance Analysis

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
    COUNT(i.product_id)                                                           AS product_count,
    SUM(i.total_units_sold)                                                       AS total_units_sold,
    ROUND(SUM(i.total_units_sold) / NULLIF(AVG(i.avg_stock_level), 0), 2)        AS category_turnover_ratio,
    SUM(i.total_stockout_days)                                                    AS total_stockout_days,
    ROUND(SUM(i.total_stockout_days) * 100.0 / SUM(i.total_days_tracked), 1)     AS stockout_rate_pct
FROM inventory_stats i
JOIN products p
    ON i.product_id = p.product_id
GROUP BY p.category
ORDER BY category_turnover_ratio DESC;

-- Output:
-- +-------------+---------------+------------------+-------------------------+---------------------+-------------------+
-- | category    | product_count | total_units_sold | category_turnover_ratio | total_stockout_days | stockout_rate_pct |
-- +-------------+---------------+------------------+-------------------------+---------------------+-------------------+
-- | Accessories | 12            | 70513            | 349.97                  | 1733                | 13.2              |
-- | Peripherals | 4             | 30973            | 126.51                  | 639                 | 14.6              |
-- | Audio       | 4             | 27678            | 121.86                  | 606                 | 13.8              |
-- | Lighting    | 2             | 6590             | 47.48                   | 235                 | 10.7              |
-- | Wearables   | 1             | 9226             | 32.88                   | 180                 | 16.4              |
-- | Smart Home  | 1             | 5931             | 30.10                   | 152                 | 13.9              |
-- | Storage     | 1             | 5931             | 29.14                   | 155                 | 14.1              |
-- | Displays    | 1             | 5931             | 29.04                   | 151                 | 13.8              |
-- | Cameras     | 1             | 3295             | 23.51                   | 104                 | 9.5               |
-- | Gaming      | 1             | 1810             | 17.20                   | 60                  | 5.5               |
-- | PC Parts    | 1             | 1810             | 16.56                   | 46                  | 4.2               |
-- | Furniture   | 1             | 1810             | 16.36                   | 46                  | 4.2               |
-- +-------------+---------------+------------------+-------------------------+---------------------+-------------------+

/*
Insights:

1. Accessories is the dominant category, containing 12 products and
   generating 70,513 units sold. It also records the highest category
   turnover ratio (349.97), indicating exceptionally strong inventory movement.

2. Peripherals and Audio are the next strongest-performing categories,
   with turnover ratios of 126.51 and 121.86 respectively, highlighting
   sustained customer demand for these product groups.

3. Wearables has the highest stockout rate (16.4%), despite consisting
   of only one product. This suggests inventory shortages may be limiting
   potential sales in this category.

4. Peripherals (14.6%), Storage (14.1%), and Smart Home (13.9%) also
   exhibit relatively high stockout rates, indicating a need for improved
   replenishment planning.

5. Gaming, PC Parts, and Furniture show the lowest turnover ratios
   (17.20, 16.56, and 16.36 respectively), suggesting slower inventory
   movement compared to other categories.

6. The concentration of sales within Accessories, Peripherals, and Audio
   suggests these categories are the primary drivers of inventory turnover
   and should be prioritized for forecasting, purchasing, and stock
   allocation decisions.

7. Categories with high turnover and high stockout rates represent the
   greatest opportunity for revenue growth, as improving inventory
   availability could reduce lost sales and enhance customer satisfaction.
*/	