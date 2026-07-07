-- unoptimized_workload.sql
-- Designed to be run via pgbench to simulate application traffic before tuning.
\set userid random(1, 50000)
\set productid random(1, 5000)
\set min_amount random(500, 1000)

-- Query 1: Fetch orders for a user (no index on orders.user_id)
SELECT * FROM orders WHERE user_id = :userid ORDER BY order_date DESC;

-- Query 2: Inefficient wildcard description search (no trigram index, full-table scan on products)
SELECT id, name, price FROM products WHERE description LIKE '%sleek%' OR description LIKE '%durability%';

-- Query 3: Aggregate product sales (no index on order_items.product_id, causes sequential scan on 400k rows)
SELECT p.name, SUM(oi.quantity) as total_sold, SUM(oi.quantity * oi.unit_price) as total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.id
WHERE oi.product_id = :productid
GROUP BY p.name;

-- Query 4: Find top spending customers above a limit (unindexed join)
SELECT u.username, COUNT(o.id) as order_count, SUM(o.total_amount) as total_spent
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE o.total_amount > :min_amount
GROUP BY u.username
ORDER BY total_spent DESC
LIMIT 10;

-- Query 5: Single user report with double correlated subqueries (scans 150k orders twice)
SELECT u.id, u.username, 
  (SELECT SUM(total_amount) FROM orders WHERE user_id = u.id) as total_spent,
  (SELECT COUNT(*) FROM orders WHERE user_id = u.id) as total_orders
FROM users u
WHERE u.id = :userid;
