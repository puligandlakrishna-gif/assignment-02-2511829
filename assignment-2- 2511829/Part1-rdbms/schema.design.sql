-- ============================================================
--  orders_flat.csv  →  3NF Normalized Schema
--  Tables: Customers, Products, Sales_Reps, Orders
--  Eliminates all Insert / Update / Delete anomalies
-- ============================================================


-- ============================================================
-- TABLE 1: Customers
--   Stores customer facts independently of any order.
--   Fixes INSERT anomaly: customers can be added without orders.
--   Fixes DELETE anomaly: deleting orders won't lose customer data.
-- ============================================================
CREATE TABLE Customers (
    customer_id   VARCHAR(10)  NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    customer_email VARCHAR(150) NOT NULL,
    customer_city  VARCHAR(100) NOT NULL,
    CONSTRAINT PK_Customers PRIMARY KEY (customer_id)
);

INSERT INTO Customers (customer_id, customer_name, customer_email, customer_city) VALUES
('C001', 'Rohan Mehta',  'rohan@gmail.com',  'Mumbai'),
('C002', 'Priya Sharma', 'priya@gmail.com',  'Delhi'),
('C003', 'Amit Verma',   'amit@gmail.com',   'Bangalore'),
('C004', 'Sneha Iyer',   'sneha@gmail.com',  'Chennai'),
('C005', 'Vikram Singh', 'vikram@gmail.com', 'Mumbai'),
('C006', 'Neha Gupta',   'neha@gmail.com',   'Delhi'),
('C007', 'Arjun Nair',   'arjun@gmail.com',  'Bangalore'),
('C008', 'Kavya Rao',    'kavya@gmail.com',  'Hyderabad');


-- ============================================================
-- TABLE 2: Products
--   Stores product facts independently of any order.
--   Fixes INSERT anomaly: new products (e.g. Projector P009)
--     can be added before anyone orders them.
--   Fixes DELETE anomaly: P008 Webcam won't vanish when
--     ORD1185 (the only webcam order) is deleted.
--   Fixes UPDATE anomaly: unit_price stored once — no risk
--     of partial updates across rows.
-- ============================================================
CREATE TABLE Products (
    product_id   VARCHAR(10)  NOT NULL,
    product_name VARCHAR(150) NOT NULL,
    category     VARCHAR(100) NOT NULL,
    unit_price   DECIMAL(10,2) NOT NULL CHECK (unit_price > 0),
    CONSTRAINT PK_Products PRIMARY KEY (product_id)
);

INSERT INTO Products (product_id, product_name, category, unit_price) VALUES
('P001', 'Laptop',        'Electronics', 55000.00),
('P002', 'Mouse',         'Electronics',   800.00),
('P003', 'Desk Chair',    'Furniture',    8500.00),
('P004', 'Notebook',      'Stationery',    120.00),
('P005', 'Headphones',    'Electronics',  3200.00),
('P006', 'Standing Desk', 'Furniture',   22000.00),
('P007', 'Pen Set',       'Stationery',    250.00),
('P008', 'Webcam',        'Electronics',  2100.00);


-- ============================================================
-- TABLE 3: Sales_Reps
--   Stores sales rep facts independently of any order.
--   Fixes INSERT anomaly: new reps can be onboarded before
--     placing any orders.
--   Fixes UPDATE anomaly: office_address stored ONCE per rep —
--     eliminates the "Nariman Pt" vs "Nariman Point" inconsistency
--     found in the flat file (SR01 had two different address strings).
--   Fixes DELETE anomaly: deleting all orders for a rep no
--     longer destroys their contact/office information.
-- ============================================================
CREATE TABLE Sales_Reps (
    sales_rep_id    VARCHAR(10)  NOT NULL,
    sales_rep_name  VARCHAR(100) NOT NULL,
    sales_rep_email VARCHAR(150) NOT NULL,
    office_address  VARCHAR(255) NOT NULL,
    CONSTRAINT PK_Sales_Reps PRIMARY KEY (sales_rep_id)
);

INSERT INTO Sales_Reps (sales_rep_id, sales_rep_name, sales_rep_email, office_address) VALUES
('SR01', 'Deepak Joshi', 'deepak@corp.com', 'Mumbai HQ, Nariman Point, Mumbai - 400021'),
('SR02', 'Anita Desai',  'anita@corp.com',  'Delhi Office, Connaught Place, New Delhi - 110001'),
('SR03', 'Ravi Kumar',   'ravi@corp.com',   'South Zone, MG Road, Bangalore - 560001');


-- ============================================================
-- TABLE 4: Orders
--   Records ONLY order-specific facts.
--   References Customers, Products, Sales_Reps via FKs —
--   each entity is owned by its own table.
--   Every non-key column (quantity, order_date) depends
--   solely on the PK (order_id) → satisfies 3NF.
-- ============================================================
CREATE TABLE Orders (
    order_id     VARCHAR(10)   NOT NULL,
    customer_id  VARCHAR(10)   NOT NULL,
    product_id   VARCHAR(10)   NOT NULL,
    sales_rep_id VARCHAR(10)   NOT NULL,
    quantity     INT           NOT NULL CHECK (quantity > 0),
    order_date   DATE          NOT NULL,
    CONSTRAINT PK_Orders     PRIMARY KEY (order_id),
    CONSTRAINT FK_Orders_Customer  FOREIGN KEY (customer_id)  REFERENCES Customers(customer_id),
    CONSTRAINT FK_Orders_Product   FOREIGN KEY (product_id)   REFERENCES Products(product_id),
    CONSTRAINT FK_Orders_SalesRep  FOREIGN KEY (sales_rep_id) REFERENCES Sales_Reps(sales_rep_id)
);

INSERT INTO Orders (order_id, customer_id, product_id, sales_rep_id, quantity, order_date) VALUES
('ORD1000', 'C002', 'P001', 'SR03', 2, '2023-05-21'),
('ORD1002', 'C002', 'P005', 'SR02', 1, '2023-01-17'),
('ORD1008', 'C002', 'P001', 'SR02', 3, '2023-02-19'),
('ORD1010', 'C002', 'P004', 'SR01', 3, '2023-10-10'),
('ORD1012', 'C001', 'P006', 'SR01', 1, '2023-05-29'),
('ORD1015', 'C006', 'P002', 'SR03', 1, '2023-05-17'),
('ORD1018', 'C004', 'P006', 'SR02', 2, '2023-01-29'),
('ORD1019', 'C001', 'P007', 'SR02', 3, '2023-07-25'),
('ORD1020', 'C002', 'P002', 'SR03', 2, '2023-06-11'),
('ORD1021', 'C008', 'P004', 'SR03', 2, '2023-08-23'),
('ORD1022', 'C005', 'P002', 'SR01', 5, '2023-10-15'),
('ORD1025', 'C008', 'P001', 'SR01', 2, '2023-02-26'),
('ORD1027', 'C002', 'P004', 'SR02', 4, '2023-11-02'),
('ORD1029', 'C005', 'P007', 'SR03', 1, '2023-06-24'),
('ORD1031', 'C005', 'P005', 'SR01', 1, '2023-09-17'),
('ORD1033', 'C004', 'P002', 'SR02', 5, '2023-03-24'),
('ORD1035', 'C002', 'P003', 'SR02', 1, '2023-05-03'),
('ORD1036', 'C004', 'P005', 'SR01', 4, '2023-02-13'),
('ORD1037', 'C002', 'P007', 'SR03', 2, '2023-03-06'),
('ORD1038', 'C008', 'P005', 'SR01', 5, '2023-05-16'),
('ORD1040', 'C005', 'P004', 'SR03', 3, '2023-11-29'),
('ORD1042', 'C004', 'P001', 'SR02', 5, '2023-01-11'),
('ORD1043', 'C004', 'P005', 'SR01', 1, '2023-01-04'),
('ORD1048', 'C002', 'P001', 'SR03', 3, '2023-08-09'),
('ORD1049', 'C007', 'P004', 'SR02', 1, '2023-01-28'),
('ORD1050', 'C001', 'P004', 'SR03', 1, '2023-06-23'),
('ORD1054', 'C002', 'P001', 'SR03', 1, '2023-10-04'),
('ORD1057', 'C003', 'P004', 'SR01', 3, '2023-07-19'),
('ORD1059', 'C008', 'P002', 'SR01', 2, '2023-06-01'),
('ORD1061', 'C006', 'P001', 'SR01', 4, '2023-10-27'),
('ORD1067', 'C004', 'P003', 'SR02', 3, '2023-03-09'),
('ORD1068', 'C008', 'P003', 'SR01', 4, '2023-01-05'),
('ORD1069', 'C002', 'P001', 'SR03', 5, '2023-04-20'),
('ORD1072', 'C005', 'P005', 'SR03', 1, '2023-09-28'),
('ORD1073', 'C005', 'P006', 'SR01', 3, '2023-03-10'),
('ORD1074', 'C002', 'P001', 'SR03', 2, '2023-10-11'),
('ORD1075', 'C005', 'P003', 'SR03', 3, '2023-04-18'),
('ORD1076', 'C004', 'P006', 'SR03', 5, '2023-05-16'),
('ORD1077', 'C008', 'P003', 'SR01', 4, '2023-02-17'),
('ORD1078', 'C005', 'P001', 'SR01', 2, '2023-06-20'),
('ORD1083', 'C006', 'P007', 'SR01', 2, '2023-07-03'),
('ORD1086', 'C003', 'P007', 'SR01', 1, '2023-07-31'),
('ORD1089', 'C001', 'P007', 'SR02', 2, '2023-04-24'),
('ORD1091', 'C001', 'P006', 'SR01', 3, '2023-07-24'),
('ORD1092', 'C005', 'P007', 'SR01', 3, '2023-05-23'),
('ORD1093', 'C007', 'P006', 'SR03', 1, '2023-06-19'),
('ORD1094', 'C002', 'P003', 'SR01', 3, '2023-10-25'),
('ORD1095', 'C001', 'P001', 'SR03', 3, '2023-08-11'),
('ORD1098', 'C007', 'P001', 'SR03', 2, '2023-10-03'),
('ORD1101', 'C005', 'P006', 'SR02', 4, '2023-06-17'),
('ORD1103', 'C007', 'P006', 'SR03', 5, '2023-03-31'),
('ORD1104', 'C005', 'P004', 'SR03', 3, '2023-01-01'),
('ORD1108', 'C005', 'P005', 'SR03', 5, '2023-11-21'),
('ORD1110', 'C004', 'P007', 'SR01', 1, '2023-03-17'),
('ORD1112', 'C008', 'P004', 'SR03', 2, '2023-10-22'),
('ORD1114', 'C001', 'P007', 'SR01', 2, '2023-08-06'),
('ORD1115', 'C003', 'P007', 'SR03', 4, '2023-09-23'),
('ORD1116', 'C001', 'P005', 'SR01', 4, '2023-03-04'),
('ORD1118', 'C006', 'P007', 'SR02', 5, '2023-11-10'),
('ORD1119', 'C007', 'P007', 'SR03', 2, '2023-08-17'),
('ORD1120', 'C008', 'P004', 'SR02', 3, '2023-05-07'),
('ORD1124', 'C003', 'P002', 'SR02', 2, '2023-12-22'),
('ORD1125', 'C004', 'P001', 'SR02', 3, '2023-07-28'),
('ORD1126', 'C008', 'P004', 'SR01', 4, '2023-04-16'),
('ORD1127', 'C007', 'P007', 'SR03', 1, '2023-12-23'),
('ORD1128', 'C007', 'P004', 'SR01', 3, '2023-06-30'),
('ORD1131', 'C008', 'P001', 'SR02', 4, '2023-06-22'),
('ORD1132', 'C003', 'P007', 'SR02', 5, '2023-03-07'),
('ORD1133', 'C001', 'P004', 'SR03', 1, '2023-10-16'),
('ORD1137', 'C005', 'P007', 'SR02', 1, '2023-05-10'),
('ORD1138', 'C008', 'P001', 'SR03', 1, '2023-10-04'),
('ORD1139', 'C006', 'P002', 'SR03', 1, '2023-02-05'),
('ORD1143', 'C003', 'P005', 'SR03', 2, '2023-02-28'),
('ORD1144', 'C005', 'P001', 'SR03', 3, '2023-01-14'),
('ORD1145', 'C007', 'P004', 'SR03', 1, '2023-04-12'),
('ORD1148', 'C007', 'P006', 'SR02', 5, '2023-02-05'),
('ORD1150', 'C007', 'P003', 'SR03', 2, '2023-08-24'),
('ORD1151', 'C007', 'P002', 'SR03', 3, '2023-09-25'),
('ORD1152', 'C008', 'P004', 'SR02', 3, '2023-10-31'),
('ORD1153', 'C006', 'P007', 'SR01', 3, '2023-02-14'),
('ORD1160', 'C008', 'P004', 'SR01', 3, '2023-02-17'),
('ORD1161', 'C004', 'P004', 'SR03', 3, '2023-05-05'),
('ORD1162', 'C006', 'P004', 'SR03', 3, '2023-09-29'),
('ORD1163', 'C007', 'P006', 'SR03', 3, '2023-06-19'),
('ORD1166', 'C003', 'P002', 'SR01', 3, '2023-09-05'),
('ORD1169', 'C003', 'P003', 'SR01', 5, '2023-01-28'),
('ORD1171', 'C008', 'P001', 'SR01', 3, '2023-01-07'),
('ORD1174', 'C008', 'P001', 'SR01', 2, '2023-02-03'),
('ORD1175', 'C008', 'P001', 'SR01', 3, '2023-10-23'),
('ORD1176', 'C001', 'P002', 'SR01', 3, '2023-03-18'),
('ORD1179', 'C004', 'P007', 'SR01', 2, '2023-09-25'),
('ORD1180', 'C008', 'P004', 'SR01', 3, '2023-06-02'),
('ORD1185', 'C003', 'P008', 'SR03', 1, '2023-06-15');

-- ============================================================
-- END OF SCRIPT
-- ============================================================
