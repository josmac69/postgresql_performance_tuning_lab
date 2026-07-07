-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_stat_monitor;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create Schema
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price NUMERIC(10,2) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL
);

-- Note: Intentionally no index on user_id to demonstrate missing index query bottlenecks
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    order_date TIMESTAMP NOT NULL,
    total_amount NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    status VARCHAR(20) NOT NULL
);

-- Note: Intentionally no index on order_id or product_id to demonstrate join inefficiencies
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL
);

-- 1. Seed Users (50,000 records)
INSERT INTO users (username, email, created_at)
SELECT 
    'user_' || i AS username,
    'user_' || i || '@example.com' AS email,
    NOW() - (random() * 365 * '1 day'::INTERVAL) AS created_at
FROM generate_series(1, 50000) s(i);

-- 2. Seed Products (5,000 records)
INSERT INTO products (name, category, price, description, status)
SELECT 
    'Product ' || i AS name,
    (ARRAY['Electronics', 'Apparel', 'Home', 'Books', 'Sports', 'Beauty'])[floor(random()*6)+1] AS category,
    (random() * 490 + 10)::NUMERIC(10,2) AS price,
    'This is a high quality ' || (ARRAY['gizmo', 'device', 'apparel item', 'novel', 'equipment', 'cosmetic product'])[floor(random()*6)+1] || 
    ' that you will love. Perfect for ' || (ARRAY['daily use', 'special occasions', 'gifts', 'outdoor activities', 'students'])[floor(random()*5)+1] || 
    '. Features include ' || (ARRAY['durability', 'high performance', 'sleek design', 'eco-friendly materials'])[floor(random()*4)+1] || '.' AS description,
    (ARRAY['in_stock', 'out_of_stock', 'discontinued'])[floor(random()*3)+1] AS status
FROM generate_series(1, 5000) s(i);

-- 3. Seed Orders (150,000 records)
INSERT INTO orders (user_id, order_date, total_amount, status)
SELECT 
    floor(random() * 50000 + 1)::INT AS user_id,
    NOW() - (random() * 180 * '1 day'::INTERVAL) AS order_date,
    0.00 AS total_amount,
    (ARRAY['completed', 'pending', 'cancelled', 'shipped'])[floor(random()*4)+1] AS status
FROM generate_series(1, 150000) s(i);

-- 4. Seed Order Items (400,000 records)
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT 
    floor(random() * 150000 + 1)::INT AS order_id,
    p.id AS product_id,
    floor(random() * 5 + 1)::INT AS quantity,
    p.price AS unit_price
FROM generate_series(1, 400000) s(i)
JOIN products p ON p.id = floor(random() * 5000 + 1)::INT;

-- 5. Update Order totals based on items
WITH order_totals AS (
    SELECT order_id, SUM(quantity * unit_price) AS total
    FROM order_items
    GROUP BY order_id
)
UPDATE orders o
SET total_amount = ot.total
FROM order_totals ot
WHERE o.id = ot.order_id;
