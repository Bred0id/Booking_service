DROP SCHEMA IF EXISTS music_studio CASCADE;
CREATE SCHEMA music_studio;

CREATE TABLE music_studio.users (
    user_id SERIAL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    role VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT users_primary_key PRIMARY KEY (user_id),
    CONSTRAINT users_email_unique UNIQUE (email),
    CONSTRAINT users_phone_number_unique UNIQUE (phone_number),

    CONSTRAINT users_full_name_check
        CHECK (full_name ~ '^[А-ЯЁ][а-яё]+( [А-ЯЁ][а-яё]+){1,2}$'),

    CONSTRAINT users_email_check
        CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),

    CONSTRAINT users_phone_number_check
        CHECK (phone_number ~ '^(\+7\d{10}|8\d{10})$'),

    CONSTRAINT users_role_check
        CHECK (role IN ('student', 'teacher', 'admin', 'worker', 'external')),

    CONSTRAINT users_status_check
        CHECK (status IN ('active', 'inactive', 'blocked'))
);

CREATE TABLE music_studio.studios (
    studio_id SERIAL,
    studio_name VARCHAR(100) NOT NULL,
    capacity SMALLINT NOT NULL,
    description TEXT,
    hourly_cost NUMERIC(10, 2) NOT NULL,
    status VARCHAR(20) NOT NULL,

    CONSTRAINT studios_primary_key PRIMARY KEY (studio_id),
    CONSTRAINT studios_studio_name_unique UNIQUE (studio_name),

    CONSTRAINT studios_studio_name_check
        CHECK (studio_name ~ '^[А-ЯЁA-Z0-9][А-ЯЁA-Za-zа-яё0-9\s"«»(),.\-№]{1,99}$'),

    CONSTRAINT studios_capacity_check
        CHECK (capacity > 0),

    CONSTRAINT studios_hourly_cost_check
        CHECK (hourly_cost >= 0),

    CONSTRAINT studios_status_check
        CHECK (status IN ('available', 'occupied', 'maintenance', 'inactive'))
);

CREATE TABLE music_studio.equipment (
    equipment_id SERIAL,
    studio_id INT NOT NULL,
    equipment_name VARCHAR(100) NOT NULL,
    equipment_type VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL,
    description TEXT,

    CONSTRAINT equipment_primary_key PRIMARY KEY (equipment_id),

    CONSTRAINT equipment_studio_id_foreign_key
        FOREIGN KEY (studio_id)
        REFERENCES music_studio.studios (studio_id),

    CONSTRAINT equipment_name_check
        CHECK (equipment_name ~ '^[А-ЯЁA-Z0-9][А-ЯЁA-Za-zа-яё0-9\s"«»(),.\-№&/+]{1,99}$'),

    CONSTRAINT equipment_type_check
        CHECK (equipment_type ~ '^[А-ЯЁA-Z][А-ЯЁA-Za-zа-яё\s\-]{1,49}$'),

    CONSTRAINT equipment_status_check
        CHECK (status IN ('available', 'booked', 'maintenance', 'broken'))
);

CREATE TABLE music_studio.bookings (
    booking_id SERIAL,
    user_id INT NOT NULL,
    studio_id INT NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    purpose VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL,
    total_cost NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT bookings_primary_key PRIMARY KEY (booking_id),

    CONSTRAINT bookings_user_id_foreign_key
        FOREIGN KEY (user_id)
        REFERENCES music_studio.users (user_id),

    CONSTRAINT bookings_studio_id_foreign_key
        FOREIGN KEY (studio_id)
        REFERENCES music_studio.studios (studio_id),

    CONSTRAINT bookings_end_time_check
        CHECK (end_time > start_time),

    CONSTRAINT bookings_purpose_check
        CHECK (purpose ~ '^[А-ЯЁA-Z0-9][А-ЯЁA-Za-zа-яё0-9\s"«»(),.\-№]{1,99}$'),

    CONSTRAINT bookings_status_check
        CHECK (status IN ('created', 'confirmed', 'cancelled', 'completed')),

    CONSTRAINT bookings_total_cost_check
        CHECK (total_cost >= 0)
);

CREATE TABLE music_studio.payments (
    booking_id INT,
    amount NUMERIC(12, 2) NOT NULL,
    payment_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    payment_method VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,

    CONSTRAINT payments_primary_key PRIMARY KEY (booking_id),

    CONSTRAINT payments_booking_id_foreign_key
        FOREIGN KEY (booking_id)
        REFERENCES music_studio.bookings (booking_id),

    CONSTRAINT payments_amount_check
        CHECK (amount > 0),

    CONSTRAINT payments_payment_method_check
        CHECK (payment_method IN ('cash', 'card', 'transfer')),

    CONSTRAINT payments_status_check
        CHECK (status IN ('pending', 'paid', 'failed', 'refunded'))
);

CREATE TABLE music_studio.booking_equipment (
    booking_id INT,
    equipment_id INT,
    unit_price NUMERIC(10, 2) NOT NULL,

    CONSTRAINT booking_equipment_primary_key PRIMARY KEY (booking_id, equipment_id),

    CONSTRAINT booking_equipment_booking_id_foreign_key
        FOREIGN KEY (booking_id)
        REFERENCES music_studio.bookings (booking_id),

    CONSTRAINT booking_equipment_equipment_id_foreign_key
        FOREIGN KEY (equipment_id)
        REFERENCES music_studio.equipment (equipment_id),

    CONSTRAINT booking_equipment_unit_price_check
        CHECK (unit_price >= 0)
);

CREATE TABLE music_studio.equipment_maintenance (
    maintenance_id SERIAL,
    responsible_user_id INT NOT NULL,
    equipment_id INT NOT NULL,
    maintenance_date DATE NOT NULL,
    maintenance_type VARCHAR(50) NOT NULL,
    maintenance_cost NUMERIC(10, 2) NOT NULL,
    description TEXT,

    CONSTRAINT equipment_maintenance_primary_key PRIMARY KEY (maintenance_id),

    CONSTRAINT equipment_maintenance_responsible_user_id_foreign_key
        FOREIGN KEY (responsible_user_id)
        REFERENCES music_studio.users (user_id),

    CONSTRAINT equipment_maintenance_equipment_id_foreign_key
        FOREIGN KEY (equipment_id)
        REFERENCES music_studio.equipment (equipment_id),

    CONSTRAINT equipment_maintenance_cost_check
        CHECK (maintenance_cost >= 0)
);

CREATE TABLE music_studio.reviews (
    review_id SERIAL,
    studio_id INT NOT NULL,
    user_id INT NOT NULL,
    comment TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    studio_rating SMALLINT NOT NULL,

    CONSTRAINT reviews_primary_key PRIMARY KEY (review_id),

    CONSTRAINT reviews_studio_id_foreign_key
        FOREIGN KEY (studio_id)
        REFERENCES music_studio.studios (studio_id),

    CONSTRAINT reviews_user_id_foreign_key
        FOREIGN KEY (user_id)
        REFERENCES music_studio.users (user_id),

    CONSTRAINT reviews_studio_rating_check
        CHECK (studio_rating BETWEEN 1 AND 10)
);

CREATE TABLE music_studio.review_equipment (
    equipment_id INT,
    review_id INT,
    rating SMALLINT NOT NULL,
    comment TEXT,

    CONSTRAINT review_equipment_primary_key PRIMARY KEY (equipment_id, review_id),

    CONSTRAINT review_equipment_equipment_id_foreign_key
        FOREIGN KEY (equipment_id)
        REFERENCES music_studio.equipment (equipment_id),

    CONSTRAINT review_equipment_review_id_foreign_key
        FOREIGN KEY (review_id)
        REFERENCES music_studio.reviews (review_id),

    CONSTRAINT review_equipment_rating_check
        CHECK (rating BETWEEN 1 AND 10)
);
