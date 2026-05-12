-- 1. Триггерная функция для проверки бронирования.
CREATE OR REPLACE FUNCTION music_studio.trg_check_booking()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_status VARCHAR(20);
    v_studio_status VARCHAR(20);
BEGIN
    SELECT status
    INTO v_user_status
    FROM music_studio.users
    WHERE user_id = NEW.user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User with id % does not exist', NEW.user_id;
    END IF;

    IF v_user_status = 'blocked' THEN
        RAISE EXCEPTION 'Blocked users cannot create bookings';
    END IF;

    SELECT status
    INTO v_studio_status
    FROM music_studio.studios
    WHERE studio_id = NEW.studio_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Studio with id % does not exist', NEW.studio_id;
    END IF;

    IF v_studio_status <> 'available' THEN
        RAISE EXCEPTION 'Studio is not available';
    END IF;

    IF NEW.status IN ('created', 'confirmed') THEN
        IF EXISTS (
            SELECT 1
            FROM music_studio.bookings b
            WHERE b.studio_id = NEW.studio_id
              AND b.booking_id <> COALESCE(NEW.booking_id, -1)
              AND b.status IN ('created', 'confirmed')
              AND b.start_time < NEW.end_time
              AND b.end_time > NEW.start_time
        ) THEN
            RAISE EXCEPTION 'Booking time overlaps with another booking';
        END IF;
    END IF;

    NEW.total_cost := music_studio.calculate_booking_cost(
        NEW.studio_id,
        NEW.start_time,
        NEW.end_time,
        v_user_status
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS check_booking_before_insert_update
ON music_studio.bookings;

CREATE TRIGGER check_booking_before_insert_update
BEFORE INSERT OR UPDATE OF user_id, studio_id, start_time, end_time
ON music_studio.bookings
FOR EACH ROW
EXECUTE FUNCTION music_studio.trg_check_booking();


-- 2. Триггерная функция для обработки платежа.
CREATE OR REPLACE FUNCTION music_studio.trg_process_payment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_cost NUMERIC(12, 2);
    v_booking_status VARCHAR(20);
BEGIN
    SELECT total_cost, status
    INTO v_total_cost, v_booking_status
    FROM music_studio.bookings
    WHERE booking_id = NEW.booking_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Booking with id % does not exist', NEW.booking_id;
    END IF;

    IF NEW.amount <> v_total_cost THEN
        RAISE EXCEPTION 'Payment amount must be equal to booking total cost';
    END IF;

    IF v_booking_status = 'cancelled' AND NEW.status <> 'refunded' THEN
        RAISE EXCEPTION 'Cannot create non-refund payment for cancelled booking';
    END IF;

    IF NEW.status = 'paid' THEN
        UPDATE music_studio.bookings
        SET status = 'confirmed'
        WHERE booking_id = NEW.booking_id;
    END IF;

    IF NEW.status = 'refunded' THEN
        UPDATE music_studio.bookings
        SET status = 'cancelled'
        WHERE booking_id = NEW.booking_id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS process_payment_before_insert_update
ON music_studio.payments;

CREATE TRIGGER process_payment_before_insert_update
BEFORE INSERT OR UPDATE OF amount, status
ON music_studio.payments
FOR EACH ROW
EXECUTE FUNCTION music_studio.trg_process_payment();