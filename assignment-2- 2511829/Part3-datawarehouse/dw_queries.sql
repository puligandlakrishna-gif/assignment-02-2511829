-- =============================================================================
-- RETAIL DATA WAREHOUSE — ANALYTICAL BI QUERIES
-- File   : part3-datawarehouse/queries.sql
-- Depends: star_schema.sql  (retail_dw schema must exist and be loaded)
-- =============================================================================

SET search_path TO retail_dw;   -- PostgreSQL; for MySQL use: USE retail_dw;


-- =============================================================================
-- Q1: Total sales revenue by product category for each month
-- =============================================================================
--
-- Pattern : fact_sales → dim_date (time slicing)
--                      → dim_product (category grouping)
-- Output  : One row per (year, month, category) combination, ordered
--           chronologically so trends are immediately readable.
-- =============================================================================

SELECT
    d.year,
    d.month_num,
    d.month_name,
    p.category,
    COUNT(*)                    AS transactions,
    SUM(f.units_sold)           AS total_units_sold,
    SUM(f.gross_revenue)        AS total_revenue,
    ROUND(AVG(f.gross_revenue), 2) AS avg_revenue_per_txn
FROM      fact_sales   f
JOIN      dim_date     d  ON f.date_key    = d.date_key
JOIN      dim_product  p  ON f.product_key = p.product_key
GROUP BY
    d.year,
    d.month_num,
    d.month_name,
    p.category
ORDER BY
    d.year      ASC,
    d.month_num ASC,
    total_revenue DESC;


-- =============================================================================
-- Q2: Top 2 performing stores by total revenue
-- =============================================================================
--
-- Pattern : fact_sales → dim_store (store attributes)
-- Technique: RANK() window function over total_revenue so tied stores are
--            handled correctly (both would appear if revenue is equal).
--            Outer WHERE filters to rank <= 2.
-- Output  : Store name, city, total revenue, units sold, transaction count,
--           and share of overall revenue for context.
-- =============================================================================

WITH store_revenue AS (
    SELECT
        s.store_key,
        s.store_name,
        s.city,
        s.region,
        COUNT(*)             AS transactions,
        SUM(f.units_sold)    AS total_units_sold,
        SUM(f.gross_revenue) AS total_revenue
    FROM      fact_sales  f
    JOIN      dim_store   s  ON f.store_key = s.store_key
    GROUP BY
        s.store_key,
        s.store_name,
        s.city,
        s.region
),
ranked AS (
    SELECT
        *,
        RANK() OVER (ORDER BY total_revenue DESC)           AS revenue_rank,
        ROUND(
            100.0 * total_revenue / SUM(total_revenue) OVER (),
            1
        )                                                   AS pct_of_total
    FROM store_revenue
)
SELECT
    revenue_rank,
    store_name,
    city,
    region,
    transactions,
    total_units_sold,
    total_revenue,
    pct_of_total     AS revenue_share_pct
FROM  ranked
WHERE revenue_rank <= 2
ORDER BY revenue_rank;


-- =============================================================================
-- Q3: Month-over-month sales trend across all stores
-- =============================================================================
--
-- Pattern : fact_sales → dim_date (monthly aggregation)
-- Technique: LAG() window function to pull the prior month's revenue into the
--            current row, enabling MoM change and percentage growth calculation.
--            NULLIF guards against division-by-zero when prior month is zero.
-- Output  : Each month's revenue alongside the previous month's, the absolute
--           change, and the percentage growth — ready for a line chart.
-- =============================================================================

WITH monthly_revenue AS (
    SELECT
        d.year,
        d.month_num,
        d.month_name,
        COUNT(*)             AS transactions,
        SUM(f.units_sold)    AS total_units_sold,
        SUM(f.gross_revenue) AS total_revenue
    FROM      fact_sales  f
    JOIN      dim_date    d  ON f.date_key = d.date_key
    GROUP BY
        d.year,
        d.month_num,
        d.month_name
)
SELECT
    year,
    month_num,
    month_name,
    transactions,
    total_units_sold,
    total_revenue,
    LAG(total_revenue) OVER (
        ORDER BY year, month_num
    )                                                           AS prior_month_revenue,
    total_revenue - LAG(total_revenue) OVER (
        ORDER BY year, month_num
    )                                                           AS mom_change,
    ROUND(
        100.0 * (
            total_revenue - LAG(total_revenue) OVER (ORDER BY year, month_num)
        )
        / NULLIF(
            LAG(total_revenue) OVER (ORDER BY year, month_num),
            0
        ),
        1
    )                                                           AS mom_growth_pct
FROM  monthly_revenue
ORDER BY year, month_num;
