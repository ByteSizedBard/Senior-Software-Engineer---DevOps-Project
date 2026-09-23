-- seed.sql
-- Seeds hotel_bookings with 200 rows spread across multiple cities,
-- organizations, and statuses, then adds booking_events for ~40% of them.
-- Safe to re-run: it wipes existing rows in both tables first.

TRUNCATE TABLE booking_events RESTART IDENTITY;
TRUNCATE TABLE hotel_bookings CASCADE;

-- Fixed pools, addressed by a per-row random index. Using array indexing
-- (not a `SELECT ... ORDER BY random() LIMIT 1` subquery) matters: an
-- uncorrelated subquery like that gets evaluated ONCE by the planner and
-- reused for every generated row, which silently produces only one
-- city/org/status for the whole seed. Array indexing is evaluated per row.
WITH pools AS (
    SELECT
        ARRAY[
            'a1111111-1111-1111-1111-111111111111',
            'a2222222-2222-2222-2222-222222222222',
            'a3333333-3333-3333-3333-333333333333',
            'a4444444-4444-4444-4444-444444444444',
            'a5555555-5555-5555-5555-555555555555'
        ]::uuid[] AS orgs,
        ARRAY['delhi', 'mumbai', 'bangalore', 'chennai', 'kolkata'] AS cities,
        ARRAY['confirmed', 'cancelled', 'completed', 'pending'] AS statuses
),
generated AS (
    SELECT
        gen_random_uuid()                                                   AS id,
        (p.orgs)[1 + floor(random() * array_length(p.orgs, 1))::int]        AS org_id,
        'hotel-' || (1 + floor(random() * 30))::int                         AS hotel_id,
        (p.cities)[1 + floor(random() * array_length(p.cities, 1))::int]    AS city,
        (p.statuses)[1 + floor(random() * array_length(p.statuses, 1))::int] AS status,
        -- created_at spread over the last 90 days, so ~1/3 of rows fall
        -- inside the query's 30-day window and the rest don't.
        NOW() - (random() * INTERVAL '90 days')                            AS created_at,
        (50 + random() * 450)::numeric(12, 2)                              AS amount,
        -- Computed ONCE here and reused below, so checkout is always
        -- strictly after checkin (two independent random() calls in the
        -- outer SELECT would occasionally put checkout before checkin).
        floor(random() * 20)::int                                          AS checkin_offset_days,
        (1 + floor(random() * 7))::int                                     AS stay_length_days,
        g                                                                    AS seq
    FROM generate_series(1, 200) AS g
    CROSS JOIN pools p
)
INSERT INTO hotel_bookings (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
SELECT
    id,
    org_id,
    hotel_id,
    city,
    (created_at::date + checkin_offset_days)                                    AS checkin_date,
    (created_at::date + checkin_offset_days + stay_length_days)                 AS checkout_date,
    amount,
    status,
    created_at
FROM generated;

-- booking_events for roughly 40% of bookings: a "created" event for all of
-- those, plus a follow-up "status_changed" event for about half of them.
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT
    b.id,
    'created',
    jsonb_build_object('source', 'seed', 'status', b.status),
    b.created_at
FROM hotel_bookings b
WHERE random() < 0.4;

INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT
    b.id,
    'status_changed',
    jsonb_build_object('new_status', b.status),
    b.created_at + INTERVAL '1 hour'
FROM hotel_bookings b
WHERE random() < 0.2;
