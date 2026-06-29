-- Convert key columns to correct data types before applying constraints
ALTER TABLE orders
    MODIFY order_id VARCHAR(20) NOT NULL,
    MODIFY customer_id VARCHAR(20) NOT NULL,
    MODIFY order_date DATE NOT NULL;

-- Primary key for orders
ALTER TABLE orders
ADD PRIMARY KEY (order_id);

-- Index for faster date-based queries (important for analytics)
ALTER TABLE orders
ADD INDEX idx_order_date (order_date);

-- ============================================================
-- DATE DIMENSION CHECK
-- ============================================================

-- View structure of date dimension table
SHOW CREATE TABLE date_dim;

-- Ensure date column is properly typed and indexed as PK
ALTER TABLE date_dim
MODIFY date DATE NOT NULL;

ALTER TABLE date_dim
ADD PRIMARY KEY (date);

-- ============================================================
-- ORDERS → DATE DIMENSION RELATIONSHIP
-- ============================================================

ALTER TABLE orders
ADD CONSTRAINT fk_orders_date
FOREIGN KEY (order_date)
REFERENCES date_dim(date)
ON UPDATE CASCADE
ON DELETE RESTRICT;

-- ============================================================
-- PRODUCTS TABLE
-- ============================================================

-- Ensure product_id is correctly typed
ALTER TABLE products
MODIFY product_id VARCHAR(20) NOT NULL;

-- Primary key for products
ALTER TABLE products
ADD PRIMARY KEY (product_id);

-- ============================================================
-- ORDER ITEMS TABLE
-- ============================================================

-- Ensure consistent data types before FK creation
ALTER TABLE order_items
MODIFY product_id VARCHAR(20) NOT NULL;

ALTER TABLE order_items
MODIFY order_id VARCHAR(20) NOT NULL;

-- FK: order_items → products
ALTER TABLE order_items
ADD CONSTRAINT fk_items_product
FOREIGN KEY (product_id)
REFERENCES products(product_id);

-- Ensure item_id is valid key column
ALTER TABLE order_items
MODIFY item_id VARCHAR(20) NOT NULL;

-- Primary key for order_items
ALTER TABLE order_items
ADD PRIMARY KEY (item_id);

-- ============================================================
-- RETURNS TABLE
-- ============================================================

ALTER TABLE returns
MODIFY return_id VARCHAR(20) NOT NULL;

-- Primary key for returns
ALTER TABLE returns
ADD PRIMARY KEY (return_id);

-- ============================================================
-- INVENTORY TABLE (FACT TABLE)
-- ============================================================

-- Ensure correct types for composite key
ALTER TABLE inventory
MODIFY product_id VARCHAR(20) NOT NULL;

ALTER TABLE inventory
MODIFY date DATE NOT NULL;

-- Composite primary key (one row per product per date)
ALTER TABLE inventory
ADD PRIMARY KEY (product_id, date);

-- ============================================================
-- ORDER ITEMS → DATE DIMENSION
-- ============================================================

ALTER TABLE order_items
MODIFY order_date DATE NOT NULL;

ALTER TABLE date_dim
MODIFY date DATE NOT NULL;

ALTER TABLE date_dim
ADD PRIMARY KEY (date);

-- FK linking order_items to date dimension
ALTER TABLE order_items
ADD CONSTRAINT fk_items_date
FOREIGN KEY (order_date)
REFERENCES date_dim(date)
ON UPDATE CASCADE
ON DELETE RESTRICT;

-- ============================================================
-- RETURNS → ORDERS RELATIONSHIP
-- ============================================================

ALTER TABLE returns
MODIFY order_id VARCHAR(20) NOT NULL;

ALTER TABLE orders
MODIFY order_id VARCHAR(20) NOT NULL;

ALTER TABLE orders
ADD PRIMARY KEY (order_id);

ALTER TABLE returns
ADD CONSTRAINT fk_returns_order
FOREIGN KEY (order_id)
REFERENCES orders(order_id)
ON UPDATE CASCADE
ON DELETE RESTRICT;

-- ============================================================
-- RETURNS → ORDER ITEMS RELATIONSHIP
-- ============================================================

ALTER TABLE order_items
MODIFY item_id VARCHAR(20) NOT NULL;

ALTER TABLE returns
MODIFY item_id VARCHAR(20) NOT NULL;

ALTER TABLE order_items
ADD PRIMARY KEY (item_id);

ALTER TABLE returns
ADD CONSTRAINT fk_returns_item
FOREIGN KEY (item_id)
REFERENCES order_items(item_id)
ON UPDATE CASCADE
ON DELETE RESTRICT;

-- ============================================================
-- RETURNS → PRODUCTS RELATIONSHIP
-- ============================================================

ALTER TABLE returns
MODIFY product_id VARCHAR(20) NOT NULL;

ALTER TABLE products
MODIFY product_id VARCHAR(20) NOT NULL;

ALTER TABLE products
ADD PRIMARY KEY (product_id);

ALTER TABLE returns
ADD CONSTRAINT fk_returns_product
FOREIGN KEY (product_id)
REFERENCES products(product_id)
ON UPDATE CASCADE
ON DELETE RESTRICT;

-- ============================================================
-- RETURNS → DATE DIMENSION
-- ============================================================

ALTER TABLE returns
MODIFY return_date DATE NOT NULL;

ALTER TABLE date_dim
MODIFY date DATE NOT NULL;

ALTER TABLE date_dim
ADD PRIMARY KEY (date);

ALTER TABLE returns
ADD CONSTRAINT fk_returns_date
FOREIGN KEY (return_date)
REFERENCES date_dim(date)
ON UPDATE CASCADE
ON DELETE RESTRICT;

-- ============================================================
-- CUSTOMERS TABLE
-- ============================================================

ALTER TABLE customers
MODIFY signup_date DATE NOT NULL;

ALTER TABLE date_dim
MODIFY date DATE NOT NULL;

ALTER TABLE date_dim
ADD PRIMARY KEY (date);

ALTER TABLE customers
ADD CONSTRAINT fk_customers_signup
FOREIGN KEY (signup_date)
REFERENCES date_dim(date)
ON UPDATE CASCADE
ON DELETE RESTRICT;

-- ============================================================
-- CLEANUP / CONSTRAINT INSPECTION
-- ============================================================

-- Check if specific FK exists (used for debugging duplicates)
SELECT TABLE_NAME, CONSTRAINT_NAME
FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = DATABASE()
AND CONSTRAINT_NAME = 'fk_items_date';

-- Drop FK when needed (example cleanup step)
ALTER TABLE order_items
DROP FOREIGN KEY fk_items_date;

-- Show all FK relationships in schema
SELECT TABLE_NAME, CONSTRAINT_NAME, REFERENCED_TABLE_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = DATABASE()
AND REFERENCED_TABLE_NAME IS NOT NULL;

-- Find tables still referencing old dim_date (pre-rename cleanup)
SELECT TABLE_NAME, CONSTRAINT_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_NAME = 'dim_date';

-- Remove old FK references before rename
ALTER TABLE customers
DROP FOREIGN KEY fk_customers_signup;

ALTER TABLE marketing_spend
DROP FOREIGN KEY fk_marketing_date;

-- Rename date dimension table (standardization step)
RENAME TABLE dim_date TO date_dim;

-- Recreate FK after rename
ALTER TABLE customers
ADD CONSTRAINT fk_customers_signup
FOREIGN KEY (signup_date)
REFERENCES date_dim(date)
ON UPDATE CASCADE
ON DELETE RESTRICT;

ALTER TABLE marketing_spend
ADD CONSTRAINT fk_marketing_date
FOREIGN KEY (date)
REFERENCES date_dim(date)
ON UPDATE CASCADE
ON DELETE RESTRICT;

-- Final validation queries
SELECT TABLE_NAME, CONSTRAINT_NAME, REFERENCED_TABLE_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = DATABASE()
AND REFERENCED_TABLE_NAME IS NOT NULL;

-- Index verification
SHOW INDEX FROM customers;
SHOW INDEX FROM products;
SHOW INDEX FROM orders;
SHOW INDEX FROM order_items;
SHOW INDEX FROM returns;
SHOW INDEX FROM inventory;
SHOW INDEX FROM marketing_spend;

-- Schema inspection
SHOW TABLES LIKE '%date%';
SHOW CREATE TABLE inventory;