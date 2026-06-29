-- Table: customers 
CREATE TABLE `customers` (
  `customer_id` varchar(20) NOT NULL,
  `first_name` text,
  `last_name` text,
  `email` text,
  `city` text,
  `region` text,
  `age` bigint DEFAULT NULL,
  `gender` text,
  `acquisition_channel` text,
  `signup_date` date NOT NULL,
  `cac` double DEFAULT NULL,

  PRIMARY KEY (`customer_id`),
  KEY `fk_customers_signup` (`signup_date`),

  CONSTRAINT `fk_customers_signup`
    FOREIGN KEY (`signup_date`)
    REFERENCES `date_dim` (`date`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;


-- Table: date_dim
-- Purpose: stores calendar/date attributes for analytics and reporting

CREATE TABLE `date_dim` (
  `date` date NOT NULL,
  `year` bigint DEFAULT NULL,
  `quarter` text,
  `month_num` bigint DEFAULT NULL,
  `month_name` text,
  `week_num` bigint DEFAULT NULL,
  `day_of_week` text,
  `is_weekend` tinyint(1) DEFAULT NULL,
  `is_month_end` tinyint(1) DEFAULT NULL,
  `is_peak_season` tinyint(1) DEFAULT NULL,
  `season` text,

  PRIMARY KEY (`date`)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- Table: inventory
-- Purpose: tracks product stock levels and sales over time (daily grain)

CREATE TABLE `inventory` (
  `product_id` varchar(20) NOT NULL,
  `date` date NOT NULL,
  `stock_level` bigint DEFAULT NULL,
  `units_sold` bigint DEFAULT NULL,
  `stockout_flag` bigint DEFAULT NULL,

  PRIMARY KEY (`product_id`, `date`),

  KEY `fk_inventory_date` (`date`),

  CONSTRAINT `fk_inventory_date`
    FOREIGN KEY (`date`)
    REFERENCES `date_dim` (`date`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,

  CONSTRAINT `fk_inventory_product`
    FOREIGN KEY (`product_id`)
    REFERENCES `products` (`product_id`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- Table: marketing_spend
-- Purpose: stores marketing performance and spend metrics by channel and time period

CREATE TABLE `marketing_spend` (
  `id` int NOT NULL AUTO_INCREMENT,
  `month` text,
  `year` bigint DEFAULT NULL,
  `quarter` text,
  `date` date DEFAULT NULL,
  `channel` text,
  `spend` double DEFAULT NULL,
  `impressions` double DEFAULT NULL,
  `clicks` double DEFAULT NULL,
  `conversions` bigint DEFAULT NULL,
  `cac` double DEFAULT NULL,
  `budget_share` double DEFAULT NULL,

  PRIMARY KEY (`id`),

  KEY `fk_marketing_date` (`date`),

  CONSTRAINT `fk_marketing_date`
    FOREIGN KEY (`date`)
    REFERENCES `date_dim` (`date`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB
AUTO_INCREMENT=181
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- Table: order_items
-- Purpose: stores line-level order details for products within each order

CREATE TABLE `order_items` (
  `item_id` varchar(20) NOT NULL,
  `order_id` varchar(20) NOT NULL,
  `product_id` varchar(20) NOT NULL,
  `product_name` text,
  `category` text,
  `supplier` text,
  `qty` bigint DEFAULT NULL,
  `unit_price` double DEFAULT NULL,
  `discount_pct` double DEFAULT NULL,
  `discounted_price` double DEFAULT NULL,
  `line_total` double DEFAULT NULL,
  `cost_price` double DEFAULT NULL,
  `weight_kg` double DEFAULT NULL,
  `order_date` date NOT NULL,
  `order_status` text,

  PRIMARY KEY (`item_id`),

  KEY `fk_items_product` (`product_id`),
  KEY `fk_items_order` (`order_id`),
  KEY `fk_items_date` (`order_date`),

  CONSTRAINT `fk_items_date`
    FOREIGN KEY (`order_date`)
    REFERENCES `date_dim` (`date`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,

  CONSTRAINT `fk_items_order`
    FOREIGN KEY (`order_id`)
    REFERENCES `orders` (`order_id`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,

  CONSTRAINT `fk_items_product`
    FOREIGN KEY (`product_id`)
    REFERENCES `products` (`product_id`)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- Table: orders
-- Purpose: stores order-level transaction data and customer order summaries

CREATE TABLE `orders` (
  `order_id` varchar(20) NOT NULL,
  `customer_id` varchar(20) NOT NULL,
  `order_date` date NOT NULL,
  `order_month` text,
  `order_year` bigint DEFAULT NULL,
  `order_quarter` text,
  `day_of_week` text,
  `is_weekend` tinyint(1) DEFAULT NULL,
  `is_month_end` tinyint(1) DEFAULT NULL,
  `city` text,
  `region` text,
  `acquisition_channel` text,
  `subtotal` double DEFAULT NULL,
  `shipping_cost` double DEFAULT NULL,
  `order_total` double DEFAULT NULL,
  `discount_pct` double DEFAULT NULL,
  `status` text,
  `num_items` bigint DEFAULT NULL,

  PRIMARY KEY (`order_id`),

  KEY `idx_order_date` (`order_date`),
  KEY `fk_orders_customer` (`customer_id`),

  CONSTRAINT `fk_orders_customer`
    FOREIGN KEY (`customer_id`)
    REFERENCES `customers` (`customer_id`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,

  CONSTRAINT `fk_orders_date`
    FOREIGN KEY (`order_date`)
    REFERENCES `date_dim` (`date`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- Table: products
-- Purpose: stores product master data including pricing, supplier, and product attributes

CREATE TABLE `products` (
  `product_id` varchar(20) NOT NULL,
  `product_name` text,
  `category` text,
  `supplier` text,
  `cost_price` double DEFAULT NULL,
  `sell_price` double DEFAULT NULL,
  `margin_pct` bigint DEFAULT NULL,
  `weight_kg` double DEFAULT NULL,
  `demand_rank` bigint DEFAULT NULL,

  PRIMARY KEY (`product_id`)
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;


-- Table: returns
-- Purpose: stores product return transactions linked to orders, items, and products

CREATE TABLE `returns` (
  `return_id` varchar(20) NOT NULL,
  `order_id` varchar(20) NOT NULL,
  `item_id` varchar(20) NOT NULL,
  `product_id` varchar(20) NOT NULL,
  `product_name` text,
  `supplier` text,
  `category` text,
  `return_date` date NOT NULL,
  `return_reason` text,
  `refund_amount` double DEFAULT NULL,
  `qty_returned` bigint DEFAULT NULL,

  PRIMARY KEY (`return_id`),

  KEY `fk_returns_order` (`order_id`),
  KEY `fk_returns_item` (`item_id`),
  KEY `fk_returns_product` (`product_id`),
  KEY `fk_returns_date` (`return_date`),

  CONSTRAINT `fk_returns_date`
    FOREIGN KEY (`return_date`)
    REFERENCES `date_dim` (`date`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,

  CONSTRAINT `fk_returns_item`
    FOREIGN KEY (`item_id`)
    REFERENCES `order_items` (`item_id`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,

  CONSTRAINT `fk_returns_order`
    FOREIGN KEY (`order_id`)
    REFERENCES `orders` (`order_id`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,

  CONSTRAINT `fk_returns_product`
    FOREIGN KEY (`product_id`)
    REFERENCES `products` (`product_id`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;



SHOW CREATE TABLE customers;
SHOW CREATE TABLE date_dim;
SHOW CREATE TABLE inventory;
SHOW CREATE TABLE marketing_spend;
SHOW CREATE TABLE order_items;
SHOW CREATE TABLE orders;
SHOW CREATE TABLE products;
SHOW CREATE TABLE returns;

