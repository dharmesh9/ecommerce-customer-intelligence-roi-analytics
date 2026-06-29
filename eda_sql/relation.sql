--  COMPLETE PK + FK SCRIPT
--  Exact column names taken from your DataFrame

-- ⚠️ Temporarily disables FK checks so you can modify structure freely
-- Risk: can allow invalid relationships temporarily
SET FOREIGN_KEY_CHECKS = 0;

-- STEP 1 — ADD PRIMARY KEYS
-- (skip any line if your table already has a PK)

-- Customers: ensures each customer is uniquely identified
ALTER TABLE customers
    ADD PRIMARY KEY (customer_id);

-- Products: unique product identifier
ALTER TABLE products
    ADD PRIMARY KEY (product_id);

-- Orders: one row per order
ALTER TABLE orders
    ADD PRIMARY KEY (order_id);

-- Order items: each item row is uniquely identified
ALTER TABLE order_items
    ADD PRIMARY KEY (item_id);

-- Returns: each return transaction is unique
ALTER TABLE returns
    ADD PRIMARY KEY (return_id);

-- Date dimension: single row per date (calendar table)
ALTER TABLE date_dim
    ADD PRIMARY KEY (date);

-- Inventory: composite key ensures one record per product per day
ALTER TABLE inventory
    ADD PRIMARY KEY (product_id, date);

-- Marketing: surrogate key added because no natural unique key exists
-- NOTE: this modifies table structure (adds new column)
ALTER TABLE marketing_spend
    ADD COLUMN id INT NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST;

-- STEP 2 — ADD ALL FOREIGN KEYS (12 total)

-- Orders → Customers (each order belongs to a customer)
ALTER TABLE orders
    ADD CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON UPDATE CASCADE ON DELETE RESTRICT;

-- Orders → Date dimension (order date mapping)
-- ⚠️ This requires order_date to be DATE type + indexed
ALTER TABLE orders
    ADD CONSTRAINT fk_orders_date
        FOREIGN KEY (order_date) REFERENCES date_dim (date)
        ON UPDATE CASCADE ON DELETE RESTRICT;

-- Order items → Orders (each item belongs to an order)
ALTER TABLE order_items
    ADD CONSTRAINT fk_items_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE ON DELETE RESTRICT;

-- Order items → Products (each item refers to a product)
ALTER TABLE order_items
    ADD CONSTRAINT fk_items_product
        FOREIGN KEY (product_id) REFERENCES products (product_id)
        ON UPDATE CASCADE ON DELETE RESTRICT;

-- Order items → Date dimension (item-level date tracking)
-- ⚠️ Often redundant because orders already has order_date
ALTER TABLE order_items
    ADD CONSTRAINT fk_items_date
        FOREIGN KEY (order_date)
        REFERENCES date_dim(date)
        ON UPDATE CASCADE
        ON DELETE RESTRICT;

-- Returns → Orders (return belongs to an order)
ALTER TABLE returns
    ADD CONSTRAINT fk_returns_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE ON DELETE RESTRICT;

-- Returns → Order items (return tied to specific item)
ALTER TABLE returns
    ADD CONSTRAINT fk_returns_item
        FOREIGN KEY (item_id) REFERENCES order_items (item_id)
        ON UPDATE CASCADE ON DELETE RESTRICT;

-- Returns → Products (direct product reference)
ALTER TABLE returns
    ADD CONSTRAINT fk_returns_product
        FOREIGN KEY (product_id) REFERENCES products (product_id)
        ON UPDATE CASCADE ON DELETE RESTRICT;

-- Returns → Date dimension (return date tracking)
ALTER TABLE returns
    ADD CONSTRAINT fk_returns_date
        FOREIGN KEY (return_date) REFERENCES date_dim (date)
        ON UPDATE CASCADE ON DELETE RESTRICT;

-- Inventory → Products (stock belongs to product)
ALTER TABLE inventory
    ADD CONSTRAINT fk_inventory_product
        FOREIGN KEY (product_id) REFERENCES products (product_id)
        ON UPDATE CASCADE ON DELETE RESTRICT;

-- Inventory → Date dimension (stock snapshot per date)
ALTER TABLE inventory
    ADD CONSTRAINT fk_inventory_date
        FOREIGN KEY (date) REFERENCES date_dim (date)
        ON UPDATE CASCADE
        ON DELETE RESTRICT;

-- Customers → Date dimension (customer signup tracking)
-- ⚠️ This assumes signup_date is meaningful for analytics
ALTER TABLE customers
    ADD CONSTRAINT fk_customers_signup
        FOREIGN KEY (signup_date) REFERENCES dim_date (date);


-- STEP 3 — MARKETING: needs a date column to connect
-- ⚠️ Marketing table is not relational-ready initially:
-- It stores month + year instead of real DATE type
-- So we derive a proper date field

-- Add derived date column (first day of month assumption)
ALTER TABLE marketing_spend
    ADD COLUMN date DATE AFTER quarter;

-- ⚠️ Safe update mode disabled to allow full table update
SET SQL_SAFE_UPDATES = 0;

-- Debug check: inspect raw data before transformation
SELECT month, year
FROM marketing_spend
LIMIT 20;

-- Convert "January + 2023" → "2023-01-01"
-- ⚠️ This assumes month is textual (Jan, February, etc.)
UPDATE marketing_spend
SET date = STR_TO_DATE(CONCAT(month, '-01'), '%Y-%m-%d');

-- Link marketing spend to date dimension
ALTER TABLE marketing_spend
    ADD CONSTRAINT fk_marketing_date
        FOREIGN KEY (date) REFERENCES dim_date (date)
        ON UPDATE CASCADE ON DELETE RESTRICT;

-- DONE — all 8 tables now connected


-- Re-enable FK checks after structure changes
SET FOREIGN_KEY_CHECKS = 1;

--  CHANGE LOG — what this script modifies per table
-- Customers:
--   - PK added
--   - FK: signup_date → dim_date.date
--
-- Products:
--   - PK added
--
-- Orders:
--   - PK added
--   - FK: customer_id → customers
--   - FK: order_date → dim_date
--
-- Order_items:
--   - PK added
--   - FK: order_id → orders
--   - FK: product_id → products
--   - FK: order_date → dim_date (potential redundancy)
--
-- Returns:
--   - PK added
--   - FK: order_id → orders
--   - FK: item_id → order_items
--   - FK: product_id → products
--   - FK: return_date → dim_date
--
-- Date dimension:
--   - PK added on date
--
-- Inventory:
--   - Composite PK (product_id, date)
--   - FK: product_id → products
--   - FK: date → dim_date
--
-- Marketing:
--   - Surrogate PK added (id)
--   - Derived date column created
--   - FK: date → dim_date