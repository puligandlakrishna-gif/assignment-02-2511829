-- ============================================================
--  Analytical Queries on 3NF Normalized Schema
--  Tables: Customers, Products, Sales_Reps, Orders
-- ============================================================


-- ============================================================
-- Query 1: List all customers from Mumbai along with their
--          total order value
-- ============================================================
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_email,
    SUM(p.unit_price * o.quantity)  AS total_order_value
FROM
    Customers c
    JOIN Orders   o ON c.customer_id  = o.customer_id
    JOIN Products p ON o.product_id   = p.product_id
WHERE
    c.customer_city = 'Mumbai'
GROUP BY
    c.customer_id,
    c.customer_name,
    c.customer_email
ORDER BY
    total_order_value DESC;


-- ============================================================
-- Query 2: Find the top 3 products by total quantity sold
-- ============================================================
SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(o.quantity)  AS total_qty_sold
FROM
    Products p
    JOIN Orders o ON p.product_id = o.product_id
GROUP BY
    p.product_id,
    p.product_name,
    p.category
ORDER BY
    total_qty_sold DESC
LIMIT 3;


-- ============================================================
-- Query 3: List all sales representatives and the number of
--          unique customers they have handled
-- ============================================================
SELECT
    sr.sales_rep_id,
    sr.sales_rep_name,
    sr.sales_rep_email,
    sr.office_address,
    COUNT(DISTINCT o.customer_id)  AS unique_customers_handled
FROM
    Sales_Reps sr
    LEFT JOIN Orders o ON sr.sales_rep_id = o.sales_rep_id
GROUP BY
    sr.sales_rep_id,
    sr.sales_rep_name,
    sr.sales_rep_email,
    sr.office_address
ORDER BY
    unique_customers_handled DESC;


-- ============================================================
-- Query 4: Find all orders where the total value exceeds
--          10,000, sorted by value descending
-- ============================================================
SELECT
    o.order_id,
    o.order_date,
    c.customer_name,
    c.customer_city,
    p.product_name,
    p.unit_price,
    o.quantity,
    (p.unit_price * o.quantity)  AS order_value,
    sr.sales_rep_name
FROM
    Orders    o
    JOIN Customers c  ON o.customer_id  = c.customer_id
    JOIN Products  p  ON o.product_id   = p.product_id
    JOIN Sales_Reps sr ON o.sales_rep_id = sr.sales_rep_id
WHERE
    (p.unit_price * o.quantity) > 10000
ORDER BY
    order_value DESC;


-- ============================================================
-- Query 5: Identify any products that have never been ordered
-- ============================================================
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.unit_price
FROM
    Products p
    LEFT JOIN Orders o ON p.product_id = o.product_id
WHERE
    o.order_id IS NULL
ORDER BY
    p.product_id;


-- ============================================================
-- END OF QUERIES
-- ============================================================
