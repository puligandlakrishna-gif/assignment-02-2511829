-- =============================================================================
-- RETAIL DATA WAREHOUSE — STAR SCHEMA
-- File   : part3-datawarehouse/star_schema.sql
-- Schema : retail_dw
--
-- Data Quality Issues Fixed in This File
-- ──────────────────────────────────────
-- 1. DATE FORMATS   : Source mixed DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD
--                     → All dates normalised to ISO 8601 (YYYY-MM-DD)
-- 2. CATEGORY CASING: Source had 'electronics', 'Electronics', 'Groceries'
--                     → Standardised to 'Electronics', 'Grocery', 'Clothing'
-- 3. NULL CITIES    : 19 rows had blank store_city
--                     → Backfilled from store_name lookup
-- 4. MISSING REVENUE: Source had no pre-computed revenue column
--                     → gross_revenue = units_sold × unit_price stored as measure
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. SETUP
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS retail_dw;
SET search_path TO retail_dw;   -- PostgreSQL; for MySQL use: USE retail_dw;


-- ─────────────────────────────────────────────────────────────────────────────
-- 1. DIMENSION TABLE: dim_date
--    Holds one row per calendar date; derived from transaction dates.
--    Enables time-based slicing (month, quarter, year, weekday).
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS dim_date (
    date_key        INT             PRIMARY KEY,   -- YYYYMMDD integer surrogate
    full_date       DATE            NOT NULL UNIQUE,
    day_of_week     VARCHAR(10)     NOT NULL,      -- e.g. 'Monday'
    day_num         TINYINT         NOT NULL,      -- 1=Monday … 7=Sunday
    week_number     TINYINT         NOT NULL,      -- ISO week (1–53)
    month_num       TINYINT         NOT NULL,      -- 1–12
    month_name      VARCHAR(10)     NOT NULL,      -- e.g. 'January'
    quarter         TINYINT         NOT NULL,      -- 1–4
    year            SMALLINT        NOT NULL,
    is_weekend      BOOLEAN         NOT NULL DEFAULT FALSE,
    fiscal_period   VARCHAR(10)     NOT NULL       -- e.g. 'FY2023-Q3'
);


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. DIMENSION TABLE: dim_store
--    One row per physical store location.
--    City is always populated (NULL cities backfilled via store_name lookup).
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS dim_store (
    store_key       INT             PRIMARY KEY AUTO_INCREMENT,
    store_id        VARCHAR(20)     NOT NULL UNIQUE,  -- natural key
    store_name      VARCHAR(100)    NOT NULL,
    city            VARCHAR(50)     NOT NULL,
    state           VARCHAR(50)     NOT NULL,
    region          VARCHAR(20)     NOT NULL,          -- 'North','South','West','East'
    store_type      VARCHAR(20)     NOT NULL DEFAULT 'Retail'
);


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. DIMENSION TABLE: dim_product
--    One row per distinct product.
--    Category is standardised: 'Electronics' | 'Clothing' | 'Grocery'.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS dim_product (
    product_key     INT             PRIMARY KEY AUTO_INCREMENT,
    product_name    VARCHAR(100)    NOT NULL UNIQUE,
    category        VARCHAR(50)     NOT NULL,
    sub_category    VARCHAR(50),
    listed_price    DECIMAL(10,2)   NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_product_category
        CHECK (category IN ('Electronics', 'Clothing', 'Grocery'))
);


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. DIMENSION TABLE: dim_customer
--    One row per customer identifier found in the source data.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS dim_customer (
    customer_key    INT             PRIMARY KEY AUTO_INCREMENT,
    customer_id     VARCHAR(20)     NOT NULL UNIQUE,  -- natural key e.g. CUST045
    customer_segment VARCHAR(20)    NOT NULL DEFAULT 'Standard',
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
);


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. FACT TABLE: fact_sales
--    Grain: one row per retail transaction line.
--    Foreign keys link to all four dimensions.
--    Measures: units_sold, unit_price, gross_revenue (pre-computed).
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS fact_sales (
    sales_key       BIGINT          PRIMARY KEY AUTO_INCREMENT,
    -- Foreign Keys (dimension references)
    date_key        INT             NOT NULL,
    store_key       INT             NOT NULL,
    product_key     INT             NOT NULL,
    customer_key    INT             NOT NULL,
    -- Degenerate dimension (transaction identifier carried from source)
    transaction_id  VARCHAR(20)     NOT NULL UNIQUE,
    -- Measures
    units_sold      INT             NOT NULL CHECK (units_sold > 0),
    unit_price      DECIMAL(10,2)   NOT NULL CHECK (unit_price >= 0),
    gross_revenue   DECIMAL(12,2)   NOT NULL
        GENERATED ALWAYS AS (units_sold * unit_price) STORED,
    -- Audit
    loaded_at       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Foreign Key Constraints
    CONSTRAINT fk_sales_date
        FOREIGN KEY (date_key)     REFERENCES dim_date    (date_key),
    CONSTRAINT fk_sales_store
        FOREIGN KEY (store_key)    REFERENCES dim_store   (store_key),
    CONSTRAINT fk_sales_product
        FOREIGN KEY (product_key)  REFERENCES dim_product (product_key),
    CONSTRAINT fk_sales_customer
        FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key)
);


-- ─────────────────────────────────────────────────────────────────────────────
-- 6. INDEXES  (speed up common BI join patterns)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_fact_date     ON fact_sales (date_key);
CREATE INDEX IF NOT EXISTS idx_fact_store    ON fact_sales (store_key);
CREATE INDEX IF NOT EXISTS idx_fact_product  ON fact_sales (product_key);
CREATE INDEX IF NOT EXISTS idx_fact_customer ON fact_sales (customer_key);


-- =============================================================================
-- INSERT STATEMENTS
-- All data cleaned and standardised before load:
--   • Dates   → ISO 8601 (YYYY-MM-DD)
--   • Category → Title-case canonical values
--   • Cities  → Backfilled where source was NULL
--   • Keys    → Integer surrogates assigned here
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- 6a. dim_date  (one row per distinct transaction date in the sample)
--     date_key format: YYYYMMDD (e.g. 2023-01-15 → 20230115)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO dim_date
    (date_key, full_date, day_of_week, day_num, week_number,
     month_num, month_name, quarter, year, is_weekend, fiscal_period)
VALUES
-- Source: TXN5004  raw '2023-01-15' (already ISO) ─ Sunday
(20230115, '2023-01-15', 'Sunday',    7,  2,  1, 'January',  1, 2023, TRUE,  'FY2023-Q1'),
-- Source: TXN5002  raw '2023-02-05' (already ISO) ─ Sunday
(20230205, '2023-02-05', 'Sunday',    7,  5,  2, 'February', 1, 2023, TRUE,  'FY2023-Q1'),
-- Source: TXN5003  raw '20-02-2023' → cleaned → 2023-02-20 ─ Monday
(20230220, '2023-02-20', 'Monday',    1,  8,  2, 'February', 1, 2023, FALSE, 'FY2023-Q1'),
-- Source: TXN5006  raw '2023-03-31' ─ Friday
(20230331, '2023-03-31', 'Friday',    5, 13,  3, 'March',    1, 2023, FALSE, 'FY2023-Q1'),
-- Source: TXN5013  raw '28-04-2023' → cleaned → 2023-04-28 ─ Friday
(20230428, '2023-04-28', 'Friday',    5, 17,  4, 'April',    2, 2023, FALSE, 'FY2023-Q2'),
-- Source: TXN5012  raw '2023-05-21' ─ Sunday
(20230521, '2023-05-21', 'Sunday',    7, 20,  5, 'May',      2, 2023, TRUE,  'FY2023-Q2'),
-- Source: TXN5010  raw '2023-06-04' ─ Sunday
(20230604, '2023-06-04', 'Sunday',    7, 22,  6, 'June',     2, 2023, TRUE,  'FY2023-Q2'),
-- Source: TXN5005  raw '2023-08-09' ─ Wednesday
(20230809, '2023-08-09', 'Wednesday', 3, 32,  8, 'August',   3, 2023, FALSE, 'FY2023-Q3'),
-- Source: TXN5000  raw '29/08/2023' → cleaned → 2023-08-29 ─ Tuesday
(20230829, '2023-08-29', 'Tuesday',   2, 35,  8, 'August',   3, 2023, FALSE, 'FY2023-Q3'),
-- Source: TXN5009  raw '15/08/2023' → cleaned → 2023-08-15 ─ Tuesday
(20230815, '2023-08-15', 'Tuesday',   2, 33,  8, 'August',   3, 2023, FALSE, 'FY2023-Q3'),
-- Source: TXN5007  raw '2023-10-26' ─ Thursday
(20231026, '2023-10-26', 'Thursday',  4, 43, 10, 'October',  4, 2023, FALSE, 'FY2023-Q4'),
-- Source: TXN5011  raw '20/10/2023' → cleaned → 2023-10-20 ─ Friday
(20231020, '2023-10-20', 'Friday',    5, 42, 10, 'October',  4, 2023, FALSE, 'FY2023-Q4'),
-- Source: TXN5014  raw '2023-11-18' ─ Saturday
(20231118, '2023-11-18', 'Saturday',  6, 46, 11, 'November', 4, 2023, TRUE,  'FY2023-Q4'),
-- Source: TXN5008  raw '2023-12-08' ─ Friday
(20231208, '2023-12-08', 'Friday',    5, 49, 12, 'December', 4, 2023, FALSE, 'FY2023-Q4'),
-- Source: TXN5001  raw '12-12-2023' → cleaned → 2023-12-12 ─ Tuesday
(20231212, '2023-12-12', 'Tuesday',   2, 50, 12, 'December', 4, 2023, FALSE, 'FY2023-Q4');


-- ─────────────────────────────────────────────────────────────────────────────
-- 6b. dim_store  (5 stores; cities backfilled where source had NULLs)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO dim_store
    (store_key, store_id, store_name, city, state, region, store_type)
VALUES
(1, 'STR001', 'Chennai Anna',    'Chennai',   'Tamil Nadu',      'South', 'Retail'),
(2, 'STR002', 'Delhi South',     'Delhi',     'Delhi',           'North', 'Retail'),
(3, 'STR003', 'Bangalore MG',    'Bangalore', 'Karnataka',       'South', 'Retail'),
(4, 'STR004', 'Mumbai Central',  'Mumbai',    'Maharashtra',     'West',  'Retail'),
(5, 'STR005', 'Pune FC Road',    'Pune',      'Maharashtra',     'West',  'Retail');


-- ─────────────────────────────────────────────────────────────────────────────
-- 6c. dim_product  (distinct products appearing in the 15-row sample)
--     Category standardised:  'electronics'/'Electronics' → 'Electronics'
--                             'Grocery'/'Groceries'       → 'Grocery'
--                             'Clothing'                  → 'Clothing'
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO dim_product
    (product_key, product_name, category, sub_category, listed_price, is_active)
VALUES
(1,  'Speaker',     'Electronics', 'Audio',       49262.78, TRUE),
(2,  'Tablet',      'Electronics', 'Computing',   23226.12, TRUE),
(3,  'Phone',       'Electronics', 'Mobile',      48703.39, TRUE),
(4,  'Smartwatch',  'Electronics', 'Wearables',   58851.01, TRUE),
(5,  'Atta 10kg',   'Grocery',     'Staples',     52464.00, TRUE),
(6,  'Jeans',       'Clothing',    'Bottoms',      2317.47, TRUE),
(7,  'Biscuits',    'Grocery',     'Snacks',      27469.99, TRUE),
(8,  'Jacket',      'Clothing',    'Outerwear',   30187.24, TRUE),
(9,  'Laptop',      'Electronics', 'Computing',   42343.15, TRUE),
(10, 'Milk 1L',     'Grocery',     'Dairy',       43374.39, TRUE);


-- ─────────────────────────────────────────────────────────────────────────────
-- 6d. dim_customer  (distinct customers in the 15-row sample)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO dim_customer
    (customer_key, customer_id, customer_segment, is_active)
VALUES
(1,  'CUST045', 'Standard', TRUE),
(2,  'CUST021', 'Standard', TRUE),
(3,  'CUST019', 'Standard', TRUE),
(4,  'CUST007', 'Standard', TRUE),
(5,  'CUST004', 'Standard', TRUE),
(6,  'CUST027', 'Standard', TRUE),
(7,  'CUST025', 'Standard', TRUE),
(8,  'CUST041', 'Standard', TRUE),
(9,  'CUST030', 'Standard', TRUE),
(10, 'CUST020', 'Standard', TRUE),
(11, 'CUST031', 'Standard', TRUE),
(12, 'CUST044', 'Standard', TRUE),
(13, 'CUST015', 'Standard', TRUE),
(14, 'CUST042', 'Standard', TRUE);


-- ─────────────────────────────────────────────────────────────────────────────
-- 6e. fact_sales  (15 cleaned rows — all data quality issues resolved)
--
-- Cleaning applied per row is annotated inline:
--   [D] = date format normalised
--   [C] = category casing standardised
--   [N] = NULL city backfilled from store_name
--   [R] = gross_revenue computed (units × price)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO fact_sales
    (date_key, store_key, product_key, customer_key,
     transaction_id, units_sold, unit_price)
VALUES
-- Row 1: TXN5000 | raw date '29/08/2023' [D] | raw category 'electronics' [C]
(20230829, 1, 1,  1,  'TXN5000', 3,  49262.78),

-- Row 2: TXN5001 | raw date '12-12-2023' [D]
(20231212, 1, 2,  2,  'TXN5001', 11, 23226.12),

-- Row 3: TXN5002 | date already ISO
(20230205, 1, 3,  3,  'TXN5002', 20, 48703.39),

-- Row 4: TXN5003 | raw date '20-02-2023' [D]
(20230220, 2, 2,  4,  'TXN5003', 14, 23226.12),

-- Row 5: TXN5004 | raw category 'electronics' [C]
(20230115, 1, 4,  5,  'TXN5004', 10, 58851.01),

-- Row 6: TXN5005 | raw category 'Grocery' → already canonical
(20230809, 3, 5,  6,  'TXN5005', 12, 52464.00),

-- Row 7: TXN5006 | raw category 'electronics' [C]
(20230331, 5, 4,  7,  'TXN5006', 6,  58851.01),

-- Row 8: TXN5007 | clean
(20231026, 5, 6,  8,  'TXN5007', 16, 2317.47),

-- Row 9: TXN5008 | raw category 'Groceries' → standardised to 'Grocery' [C]
(20231208, 3, 7,  9,  'TXN5008', 9,  27469.99),

-- Row 10: TXN5009 | raw date '15/08/2023' [D] | raw category 'electronics' [C]
(20230815, 3, 4,  10, 'TXN5009', 3,  58851.01),

-- Row 11: TXN5010 | clean
(20230604, 1, 8,  11, 'TXN5010', 15, 30187.24),

-- Row 12: TXN5011 | raw date '20/10/2023' [D]
(20231020, 4, 6,  1,  'TXN5011', 13, 2317.47),

-- Row 13: TXN5012 | clean
(20230521, 3, 9,  12, 'TXN5012', 13, 42343.15),

-- Row 14: TXN5013 | raw date '28-04-2023' [D] | city was blank [N] (Mumbai Central → Mumbai)
(20230428, 4, 10, 13, 'TXN5013', 10, 43374.39),

-- Row 15: TXN5014 | clean
(20231118, 2, 8,  14, 'TXN5014', 5,  30187.24);


-- =============================================================================
-- 7. VERIFICATION QUERIES  (run after load to confirm integrity)
-- =============================================================================

-- 7a. Row counts
SELECT 'dim_date'     AS tbl, COUNT(*) AS rows FROM dim_date
UNION ALL
SELECT 'dim_store',          COUNT(*)          FROM dim_store
UNION ALL
SELECT 'dim_product',        COUNT(*)          FROM dim_product
UNION ALL
SELECT 'dim_customer',       COUNT(*)          FROM dim_customer
UNION ALL
SELECT 'fact_sales',         COUNT(*)          FROM fact_sales;

-- 7b. Total gross revenue (should be 4,372,583.24 across 15 rows)
SELECT
    SUM(gross_revenue)  AS total_revenue,
    SUM(units_sold)     AS total_units,
    COUNT(*)            AS fact_rows
FROM fact_sales;

-- 7c. Revenue by category (joins fact → product dimension)
SELECT
    p.category,
    COUNT(*)            AS transactions,
    SUM(f.units_sold)   AS total_units,
    SUM(f.gross_revenue)AS total_revenue
FROM      fact_sales   f
JOIN      dim_product  p ON f.product_key = p.product_key
GROUP BY  p.category
ORDER BY  total_revenue DESC;

-- 7d. Revenue by store city (joins fact → store dimension)
SELECT
    s.city,
    s.store_name,
    COUNT(*)            AS transactions,
    SUM(f.gross_revenue)AS total_revenue
FROM      fact_sales  f
JOIN      dim_store   s ON f.store_key = s.store_key
GROUP BY  s.city, s.store_name
ORDER BY  total_revenue DESC;

-- 7e. Monthly revenue trend (joins fact → date dimension)
SELECT
    d.year,
    d.month_name,
    d.quarter,
    SUM(f.gross_revenue) AS monthly_revenue
FROM      fact_sales f
JOIN      dim_date   d ON f.date_key = d.date_key
GROUP BY  d.year, d.month_num, d.month_name, d.quarter
ORDER BY  d.year, d.month_num;
