-- ============================================================
-- NYKAA BEAUTY & FASHION - CREATE + CSV IMPORT FILE
-- ============================================================

-- ============================================================
-- SECTION 1: DATABASE AND TABLE CREATION
-- ============================================================

CREATE DATABASE Nykaa_Analytics;
USE Nykaa_Analytics;

-- ============================================================
-- 1. CORE CUSTOMER / ORDER TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS System_Customers (
    customer_id INT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(15) UNIQUE,
    join_date DATE NOT NULL,
    membership_tier ENUM('Prive','Gold','Platinum','Regular') DEFAULT 'Regular'
);

select * from system_customers;


CREATE TABLE IF NOT EXISTS System_Coupons (
    coupon_id INT PRIMARY KEY,
    coupon_code VARCHAR(20) UNIQUE NOT NULL,
    discount_percentage DECIMAL(5,2) NOT NULL,
    min_order_value DECIMAL(10,2) NOT NULL,
    expiry_date DATE NOT NULL
);

select * from system_coupons;


CREATE TABLE IF NOT EXISTS System_Orders (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    coupon_id INT NULL,
    order_date DATETIME NOT NULL,
    payment_method ENUM('UPI','Credit Card','Debit Card','COD','NetBanking') NOT NULL,
    shipping_status ENUM('Pending','Shipped','Delivered','Cancelled') NOT NULL,
    subtotal_amount DECIMAL(12,2) NOT NULL,
    final_amount DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES System_Customers(customer_id),
    FOREIGN KEY (coupon_id) REFERENCES System_Coupons(coupon_id)
);

select * from system_orders;


-- ============================================================
-- 2. BEAUTY TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS Beauty_Brands (
    brand_id INT PRIMARY KEY,
    brand_name VARCHAR(100) NOT NULL UNIQUE,
    tier ENUM('Luxury','Premium','Mass','Indie') NOT NULL
);

select * from beauty_brands;

CREATE TABLE IF NOT EXISTS Beauty_Categories (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE
);

select * from beauty_categories;

CREATE TABLE IF NOT EXISTS Beauty_Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category_id INT,
    brand_id INT,
    shade_name VARCHAR(100),
    shade_hex_code VARCHAR(7),
    skin_type_tag ENUM('Oily','Dry','Combination','All') DEFAULT 'All',
    expiry_date DATE NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT NOT NULL,
    FOREIGN KEY (category_id) REFERENCES Beauty_Categories(category_id),
    FOREIGN KEY (brand_id) REFERENCES Beauty_Brands(brand_id)
);

select * from beauty_products;

CREATE TABLE IF NOT EXISTS Beauty_Order_Items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price_at_purchase DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES System_Orders(order_id),
    FOREIGN KEY (product_id) REFERENCES Beauty_Products(product_id)
);

select * from beauty_order_items;


-- ============================================================
-- 3. FASHION TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS Fashion_Brands (
    brand_id INT PRIMARY KEY,
    brand_name VARCHAR(100) NOT NULL UNIQUE,
    tier ENUM('Luxury','Premium','Mass','Indie') NOT NULL
);

select * from fashion_brands;

CREATE TABLE IF NOT EXISTS Fashion_Categories (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE
);

select * from fashion_categories;

CREATE TABLE IF NOT EXISTS Fashion_Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category_id INT,
    brand_id INT,
    size_tag ENUM('XS','S','M','L','XL','XXL','Free Size') NOT NULL,
    color VARCHAR(50) NOT NULL,
    material VARCHAR(100),
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT NOT NULL,
    FOREIGN KEY (category_id) REFERENCES Fashion_Categories(category_id),
    FOREIGN KEY (brand_id) REFERENCES Fashion_Brands(brand_id)
);

select * from fashion_products;

CREATE TABLE IF NOT EXISTS Fashion_Order_Items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price_at_purchase DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES System_Orders(order_id),
    FOREIGN KEY (product_id) REFERENCES Fashion_Products(product_id)
);

select * from fashion_order_items;

-- ============================================================
-- 4. CUSTOMER FEEDBACK + STOCK AUDIT
-- ============================================================

CREATE TABLE IF NOT EXISTS System_Product_Reviews (
    review_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    product_segment ENUM('Beauty','Fashion') NOT NULL,
    product_id INT NOT NULL,
    rating INT NOT NULL,
    comment_text VARCHAR(255),
    fit_feedback ENUM('Too Small','True To Size','Too Large','Not Applicable') DEFAULT 'Not Applicable',
    is_verified_buyer BOOLEAN DEFAULT TRUE,
    submission_date DATE NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES System_Customers(customer_id)
);

select * from system_product_reviews;

CREATE TABLE IF NOT EXISTS Stock_Audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    product_segment ENUM('Beauty','Fashion') NOT NULL,
    product_id INT NOT NULL,
    order_id INT NOT NULL,
    quantity_changed INT NOT NULL,
    action_type VARCHAR(30) NOT NULL,
    audit_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
 select * from stock_audit;


-- ============================================================
-- PROCEDURES
-- ============================================================

DELIMITER //

CREATE PROCEDURE GetCustomerPurchaseSummary(IN p_customer_id INT)
BEGIN
    SELECT c.customer_id,
           CONCAT(c.first_name,' ',c.last_name) AS customer_name,
           c.membership_tier,
           COUNT(o.order_id) AS total_orders,
           SUM(o.final_amount) AS total_spending,
           ROUND(AVG(o.final_amount), 2) AS average_order_value
    FROM System_Customers c
    LEFT JOIN System_Orders o
      ON c.customer_id = o.customer_id
     AND o.shipping_status = 'Delivered'
    WHERE c.customer_id = p_customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.membership_tier;
END //

DELIMITER //

CREATE PROCEDURE GetLowStockBeautyProducts()
BEGIN
    SELECT product_id, product_name, stock_quantity, price
    FROM Beauty_Products
    WHERE stock_quantity <= 30
    ORDER BY stock_quantity;
END //

-- ============================================================
-- TRIGGERS
-- ============================================================

DELIMITER //

CREATE TRIGGER trg_beauty_stock_after_sale
AFTER INSERT ON Beauty_Order_Items
FOR EACH ROW
BEGIN
    UPDATE Beauty_Products
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id;

    INSERT INTO Stock_Audit
        (product_segment, product_id, order_id, quantity_changed, action_type)
    VALUES
        ('Beauty', NEW.product_id, NEW.order_id, NEW.quantity, 'SALE');
END //

DELIMITER //

CREATE TRIGGER trg_fashion_stock_after_sale
AFTER INSERT ON Fashion_Order_Items
FOR EACH ROW
BEGIN
    UPDATE Fashion_Products
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id;

    INSERT INTO Stock_Audit
        (product_segment, product_id, order_id, quantity_changed, action_type)
    VALUES
        ('Fashion', NEW.product_id, NEW.order_id, NEW.quantity, 'SALE');
END //
