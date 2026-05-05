-- 1. Функция расчета стоимости бронирования.
CREATE OR REPLACE FUNCTION music_studio.calculate_booking_cost(
    p_studio_id INT,
    p_start_time TIMESTAMP,
    p_end_time TIMESTAMP
)
RETURNS NUMERIC(12, 2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_hourly_cost NUMERIC(10, 2);
    v_hours NUMERIC;
BEGIN
    IF p_end_time <= p_start_time THEN
        RAISE EXCEPTION 'End time must be greater than start time';
    END IF;

    SELECT hourly_cost
    INTO v_hourly_cost
    FROM music_studio.studios
    WHERE studio_id = p_studio_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Studio with id % does not exist', p_studio_id;
    END IF;

    v_hours := EXTRACT(EPOCH FROM (p_end_time - p_start_time)) / 3600;

    RETURN ROUND(v_hourly_cost * v_hours, 2);
END;
$$;


-- 2. Функция проверки доступности студии.
CREATE OR REPLACE FUNCTION music_studio.is_studio_available(
    p_studio_id INT,
    p_start_time TIMESTAMP,
    p_end_time TIMESTAMP,
    p_exclude_booking_id INT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_studio_status VARCHAR(20);
BEGIN
    IF p_end_time <= p_start_time THEN
        RAISE EXCEPTION 'End time must be greater than start time';
    END IF;

    SELECT status
    INTO v_studio_status
    FROM music_studio.studios
    WHERE studio_id = p_studio_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Studio with id % does not exist', p_studio_id;
    END IF;

    IF v_studio_status <> 'available' THEN
        RETURN FALSE;
    END IF;

    RETURN NOT EXISTS (
        SELECT 1
        FROM music_studio.bookings b
        WHERE b.studio_id = p_studio_id
          AND b.status IN ('created', 'confirmed')
          AND (p_exclude_booking_id IS NULL OR b.booking_id <> p_exclude_booking_id)
          AND b.start_time < p_end_time
          AND b.end_time > p_start_time
    );
END;
$$;


-- 3. Функция создания бронирования.
CREATE OR REPLACE FUNCTION music_studio.create_booking(
    p_user_id INT,
    p_studio_id INT,
    p_start_time TIMESTAMP,
    p_end_time TIMESTAMP,
    p_purpose VARCHAR(100)
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_booking_id INT;
BEGIN
    INSERT INTO music_studio.bookings (
        user_id, studio_id, start_time, end_time, purpose, status, total_cost
    ) VALUES (
        p_user_id, p_studio_id, p_start_time, p_end_time, p_purpose, 'created', 0
    )
    RETURNING booking_id INTO v_booking_id;

    RETURN v_booking_id;
END;
$$;

-- 4.Почасовое расписание студии на выбранный день. Возвращает каждый час дня и показывает,
-- свободен слот или пересекается с бронированием.
CREATE OR REPLACE FUNCTION music_studio.get_studio_hourly_schedule(
    p_studio_id INT,
    p_target_day DATE
)
RETURNS TABLE (
    studio_id INT,
    studio_name VARCHAR(100),
    slot_start TIMESTAMP,
    slot_end TIMESTAMP,
    slot_status VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM music_studio.studios s
        WHERE s.studio_id = p_studio_id
    ) THEN
        RAISE EXCEPTION 'Studio with id % does not exist', p_studio_id;
    END IF;

    RETURN QUERY
    WITH RECURSIVE time_slots AS (
        SELECT
            p_studio_id AS studio_id,
            CAST(p_target_day AS TIMESTAMP) AS slot_start,
            CAST(p_target_day AS TIMESTAMP) + INTERVAL '1 hour' AS slot_end

        UNION ALL

        SELECT
            ts.studio_id,
            ts.slot_end,
            ts.slot_end + INTERVAL '1 hour'
        FROM time_slots ts
        WHERE ts.slot_end < CAST(p_target_day AS TIMESTAMP) + INTERVAL '24 hour'
    )
    SELECT
        ts.studio_id,
        s.studio_name,
        ts.slot_start,
        ts.slot_end,
        CAST(
            CASE
                WHEN COUNT(b.booking_id) > 0 THEN 'booked'
                ELSE 'free'
            END
            AS VARCHAR(20)
        ) AS slot_status
    FROM time_slots ts
    JOIN music_studio.studios s
        ON s.studio_id = ts.studio_id
    LEFT JOIN music_studio.bookings b
        ON b.studio_id = ts.studio_id
        AND b.status IN ('created', 'confirmed', 'completed')
        AND b.start_time < ts.slot_end
        AND b.end_time > ts.slot_start
    GROUP BY
        ts.studio_id,
        s.studio_name,
        ts.slot_start,
        ts.slot_end
    ORDER BY ts.slot_start;
END;
$$;