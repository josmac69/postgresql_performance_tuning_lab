-- optimized_workload.sql
-- Designed to be run via pgbench to simulate application traffic after tuning.
\set userid random(1, 50000)
\set productid random(1, 5000)
\set min_amount random(500, 1000)

-- Query 1: Fetch orders for a user (backed by index on orders.user_id)
SELECT * FROM orders WHERE user_id = :userid ORDER BY order_date DESC;

-- Query 2: Wildcard description search (backed by GIN pg_trgm index on products.description)
SELECT id, name, price FROM products WHERE description LIKE '%sleek%' OR description LIKE '%durability%';

-- Query 3: Aggregate product sales (backed by B-tree index on order_items.product_id)
SELECT p.name, SUM(oi.quantity) as total_sold, SUM(oi.quantity * oi.unit_price) as total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.id
WHERE oi.product_id = :productid
GROUP BY p.name;

-- Query 4: Find top spending customers (optimized with CTE to aggregate before join)
WITH top_users AS (
    SELECT user_id, COUNT(id) as order_count, SUM(total_amount) as total_spent
    FROM orders
    WHERE total_amount > :min_amount
    GROUP BY user_id
    ORDER BY total_spent DESC
    LIMIT 10
)
SELECT u.username, tu.order_count, tu.total_spent
FROM top_users tu
JOIN users u ON tu.user_id = u.id
ORDER BY tu.total_spent DESC;

-- Query 5: Rewritten single user report using JOIN (replaces the double correlated subquery pattern)
SELECT u.id, u.username, 
  COALESCE(SUM(o.total_amount), 0) as total_spent,
  COUNT(o.id) as total_orders
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE u.id = :userid
GROUP BY u.id, u.username;
