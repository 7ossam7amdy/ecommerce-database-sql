-- =====================================================
-- E-Commerce Database (SQL Server / T-SQL)
-- Normalized to 3NF
-- =====================================================

USE master;
GO

IF DB_ID('ecommerce_db') IS NOT NULL
BEGIN
    ALTER DATABASE ecommerce_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ecommerce_db;
END
GO

CREATE DATABASE ecommerce_db;
GO

USE ecommerce_db;
GO

-- ---------- 1) TABLES ----------

CREATE TABLE categories (
    category_id   INT IDENTITY(1,1) PRIMARY KEY,
    category_name NVARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE customers (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,
    full_name   NVARCHAR(100) NOT NULL,
    email       NVARCHAR(150) NOT NULL UNIQUE,
    phone       VARCHAR(20),
    city        NVARCHAR(80),
    created_at  DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE products (
    product_id     INT IDENTITY(1,1) PRIMARY KEY,
    category_id    INT NOT NULL,
    product_name   NVARCHAR(150) NOT NULL,
    price          DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    stock_quantity INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

CREATE TABLE orders (
    order_id     INT IDENTITY(1,1) PRIMARY KEY,
    customer_id  INT NOT NULL,
    order_date   DATE NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','shipped','delivered','cancelled')),
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_item_id INT IDENTITY(1,1) PRIMARY KEY,
    order_id      INT NOT NULL,
    product_id    INT NOT NULL,
    quantity      INT NOT NULL CHECK (quantity > 0),
    unit_price    DECIMAL(10,2) NOT NULL,   -- price at time of purchase
    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_items_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT uq_order_product UNIQUE (order_id, product_id)
);

CREATE TABLE payments (
    payment_id     INT IDENTITY(1,1) PRIMARY KEY,
    order_id       INT NOT NULL,
    payment_date   DATE NOT NULL,
    amount         DECIMAL(12,2) NOT NULL,
    payment_method VARCHAR(20) NOT NULL
                   CHECK (payment_method IN ('cash','credit_card','wallet','bank_transfer')),
    payment_status VARCHAR(20) NOT NULL DEFAULT 'pending'
                   CHECK (payment_status IN ('pending','paid','failed')),
    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);
GO

-- ---------- 2) INDEXES ----------

CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_orders_customer   ON orders(customer_id);
CREATE INDEX idx_orders_date       ON orders(order_date);
CREATE INDEX idx_items_product     ON order_items(product_id);
CREATE INDEX idx_payments_order    ON payments(order_id);
GO

-- ---------- 3) SAMPLE DATA ----------

INSERT INTO categories (category_name) VALUES
('Electronics'), ('Clothing'), ('Home Appliances'), ('Books');

INSERT INTO customers (full_name, email, phone, city) VALUES
('Ahmed Hassan',   'ahmed.hassan@example.com',   '01012345678', 'Cairo'),
('Sara Mohamed',   'sara.mohamed@example.com',   '01123456789', 'Mansoura'),
('Omar Khaled',    'omar.khaled@example.com',    '01234567890', 'Alexandria'),
('Mona Ali',       'mona.ali@example.com',       '01555555555', 'Giza'),
('Youssef Adel',   'youssef.adel@example.com',   '01099999999', 'Cairo'),
('Nour Ibrahim',   'nour.ibrahim@example.com',   '01188888888', 'Tanta'),
('Hana Samir',     'hana.samir@example.com',     '01277777777', 'Mansoura'),
('Karim Mostafa',  'karim.mostafa@example.com',  '01066666666', 'Aswan');

INSERT INTO products (category_id, product_name, price, stock_quantity) VALUES
(1, 'Lenovo Laptop 15"',     15000.00, 20),
(1, 'Samsung Smartphone',     9000.00, 35),
(1, 'Wireless Headphones',     800.00, 100),
(2, 'Cotton T-Shirt',          250.00, 200),
(2, 'Slim Fit Jeans',          600.00, 120),
(2, 'Running Sneakers',       1200.00, 60),
(3, 'Coffee Maker',           1500.00, 40),
(3, 'Blender',                 900.00, 50),
(4, 'SQL Mastery Book',        350.00, 80),
(4, 'Python for Data Book',    300.00, 90);

INSERT INTO orders (customer_id, order_date, status) VALUES
(1, '2025-01-10', 'delivered'),
(2, '2025-01-15', 'delivered'),
(3, '2025-02-03', 'delivered'),
(1, '2025-02-20', 'delivered'),
(4, '2025-03-05', 'shipped'),
(5, '2025-03-18', 'delivered'),
(2, '2025-04-02', 'cancelled'),
(6, '2025-04-12', 'delivered'),
(7, '2025-05-01', 'pending'),
(3, '2025-05-09', 'delivered');

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
(1, 2, 1, 9000.00), (1, 3, 1, 800.00),
(2, 4, 3, 250.00),  (2, 5, 1, 600.00),
(3, 1, 1, 15000.00),
(4, 9, 2, 350.00),  (4, 10, 1, 300.00),
(5, 6, 1, 1200.00), (5, 4, 2, 250.00),
(6, 7, 1, 1500.00), (6, 8, 1, 900.00),
(7, 3, 1, 800.00),
(8, 2, 1, 9000.00),
(9, 10, 2, 300.00),
(10, 3, 2, 800.00), (10, 9, 1, 350.00);
GO

-- Calculate order totals from items
UPDATE o
SET o.total_amount = x.total
FROM orders o
JOIN (
    SELECT order_id, SUM(quantity * unit_price) AS total
    FROM order_items
    GROUP BY order_id
) x ON x.order_id = o.order_id;

INSERT INTO payments (order_id, payment_date, amount, payment_method, payment_status)
SELECT order_id, order_date, total_amount,
       CHOOSE(1 + (order_id % 4), 'cash', 'credit_card', 'wallet', 'bank_transfer'),
       'paid'
FROM orders
WHERE status IN ('delivered', 'shipped');

INSERT INTO payments (order_id, payment_date, amount, payment_method, payment_status)
SELECT order_id, order_date, total_amount, 'wallet', 'pending'
FROM orders
WHERE status = 'pending';
GO

-- ---------- 4) REPORT QUERIES ----------
-- شغّل كل استعلام لوحده (حدده واضغط Execute) وصوّر النتيجة

-- Q1: Monthly sales (excluding cancelled orders)
SELECT FORMAT(order_date, 'yyyy-MM') AS [month],
       COUNT(*)                      AS orders_count,
       SUM(total_amount)             AS total_sales
FROM orders
WHERE status <> 'cancelled'
GROUP BY FORMAT(order_date, 'yyyy-MM')
ORDER BY [month];

-- Q2: Top 5 best-selling products
SELECT TOP 5
       p.product_name,
       SUM(oi.quantity)                 AS units_sold,
       SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o   ON o.order_id   = oi.order_id
WHERE o.status <> 'cancelled'
GROUP BY p.product_id, p.product_name
ORDER BY revenue DESC;

-- Q3: Top customers by spending
SELECT c.full_name, c.city,
       COUNT(o.order_id)   AS orders_count,
       SUM(o.total_amount) AS total_spent
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.status <> 'cancelled'
GROUP BY c.customer_id, c.full_name, c.city
ORDER BY total_spent DESC;

-- Q4: Revenue by category
SELECT cat.category_name,
       SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN products p     ON p.product_id = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
JOIN orders o       ON o.order_id = oi.order_id
WHERE o.status <> 'cancelled'
GROUP BY cat.category_id, cat.category_name
ORDER BY revenue DESC;

-- Q5: Full order details
SELECT o.order_id, c.full_name, o.order_date, o.status,
       p.product_name, oi.quantity, oi.unit_price,
       (oi.quantity * oi.unit_price) AS line_total
FROM orders o
JOIN customers c    ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
ORDER BY o.order_id;

-- Q6: Customers who never ordered
SELECT c.customer_id, c.full_name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- Q7: Low stock products
SELECT product_name, stock_quantity
FROM products
WHERE stock_quantity < 30
ORDER BY stock_quantity;
