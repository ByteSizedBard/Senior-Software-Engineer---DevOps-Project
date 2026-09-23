-- 002_add_indexes.sql
-- Optimizes:
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- Why this index:
--   - `city` and `created_at` are the WHERE-clause filter columns, so they
--     lead the index: city first because it is the equality predicate,
--     created_at second because it is the range predicate (not because
--     city is assumed to be more selective - that depends on the data).
--   - `org_id`, `status`, and `amount` are added via INCLUDE rather than as
--     extra key columns. They aren't used for filtering/sorting, so they
--     don't need to be part of the B-tree key - but including them makes
--     an index-only scan (no heap fetch) possible for the GROUP BY / COUNT /
--     SUM, when the planner decides it's the cheaper plan.
CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
