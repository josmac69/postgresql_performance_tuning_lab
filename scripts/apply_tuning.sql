-- apply_tuning.sql
-- Optimizations to solve the bottlenecks found by pg_stat_statements.

\echo 'Applying indexes and performance tuning...'

-- 1. Index foreign key user_id on orders
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);

-- 2. Index foreign keys on order_items
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);

-- 3. Composite index on orders(user_id, total_amount) to accelerate customer spend reports
CREATE INDEX IF NOT EXISTS idx_orders_user_total ON orders(user_id, total_amount);

-- 4. Trigram GIN index on products.description to accelerate LIKE '%pattern%' queries
-- (Requires pg_trgm extension which was enabled in 01_init.sql)
CREATE INDEX IF NOT EXISTS idx_products_desc_trgm ON products USING gin (description gin_trgm_ops);

-- 5. Force update of planner statistics
\echo 'Updating planner statistics with ANALYZE...'
ANALYZE users;
ANALYZE products;
ANALYZE orders;
ANALYZE order_items;

\echo 'Optimizations applied successfully!'
