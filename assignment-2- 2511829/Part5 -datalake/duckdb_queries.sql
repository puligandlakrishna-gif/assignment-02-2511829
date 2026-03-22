-- =============================================================================
-- CROSS-FORMAT QUERIES — DuckDB
-- File  : datalake/duckdb_queries.sql
--
-- Files read directly (no pre-loading):
--   customers.csv      → customer_id, name, city, signup_date, email
--   orders.json        → order_id, customer_id, order_date, status,
--                        total_amount, num_items
--   products.parquet   → line_item_id, order_id, product_id, product_name,
--                        category, quantity, unit_price, total_price
--                        (order line-items table; joins to orders via order_id)
--
-- Run:  duckdb < datalake/duckdb_queries.sql
--       or paste into a DuckDB session / Jupyter cell.
-- =============================================================================


-- =============================================================================
-- Q1: List all customers along with the total number of orders they have placed
-- =============================================================================
--
-- Join: customers.csv  ←→  orders.json  on customer_id
-- All 50 customers are returned (LEFT JOIN preserves customers with 0 orders).
-- Results ordered alphabetically so the list is easy to scan.
-- =============================================================================

SELECT
    c.customer_id,
    c.name                          AS customer_name,
    c.city,
    COUNT(o.order_id)               AS total_orders
FROM
    read_csv_auto('customers.csv')  AS c
    LEFT JOIN read_json_auto('orders.json') AS o
        ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.name,
    c.city
ORDER BY
    c.name ASC;


-- =============================================================================
-- Q2: Find the top 3 customers by total order value
-- =============================================================================
--
-- Join: customers.csv  ←→  orders.json  on customer_id
-- Aggregates total_amount (order-level spend) per customer.
-- LIMIT 3 after descending sort gives the highest spenders.
-- Ties are broken by customer name for determinism.
-- =============================================================================

SELECT
    c.customer_id,
    c.name                          AS customer_name,
    c.city,
    COUNT(o.order_id)               AS total_orders,
    SUM(o.total_amount)             AS total_order_value
FROM
    read_csv_auto('customers.csv')  AS c
    JOIN read_json_auto('orders.json') AS o
        ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.name,
    c.city
ORDER BY
    total_order_value DESC,
    c.name            ASC
LIMIT 3;


-- =============================================================================
-- Q3: List all products purchased by customers from Bangalore
-- =============================================================================
--
-- Join chain: customers.csv  →  orders.json  →  products.parquet
--             (filter city = 'Bangalore' before joining to minimise scan)
-- DISTINCT ensures each product appears once even if bought multiple times
-- by different Bangalore customers.
-- =============================================================================

SELECT DISTINCT
    p.product_id,
    p.product_name,
    p.category
FROM
    read_csv_auto('customers.csv')          AS c
    JOIN read_json_auto('orders.json')      AS o
        ON c.customer_id = o.customer_id
    JOIN read_parquet('products.parquet')   AS p
        ON o.order_id    = p.order_id
WHERE
    c.city = 'Bangalore'
ORDER BY
    p.category,
    p.product_name;


-- =============================================================================
-- Q4: Join all three files — customer name, order date, product name, quantity
-- =============================================================================
--
-- Full three-way join across all formats:
--   CSV  ←→  JSON      on customer_id
--   JSON ←→  Parquet   on order_id
-- One row per line item (a single order can have multiple products).
-- Ordered by order_date descending so the most recent purchases appear first.
-- =============================================================================

SELECT
    c.name                          AS customer_name,
    c.city,
    o.order_id,
    CAST(o.order_date AS DATE)      AS order_date,
    o.status                        AS order_status,
    p.product_name,
    p.category,
    p.quantity,
    p.unit_price,
    p.total_price
FROM
    read_csv_auto('customers.csv')          AS c
    JOIN read_json_auto('orders.json')      AS o
        ON c.customer_id = o.customer_id
    JOIN read_parquet('products.parquet')   AS p
        ON o.order_id    = p.order_id
ORDER BY
    order_date   DESC,
    c.name       ASC,
    p.product_name ASC;
