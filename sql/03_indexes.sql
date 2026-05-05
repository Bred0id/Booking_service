-- Используется индекс типа B-tree,
-- так как в проекте активно применяются операции сравнения по времени, а также сортировка.
-- Hash-индексы не используются, так как они эффективны только для равенства (=)
-- и не подходят для диапазонных запросов.


-- 1. Индекс для поиска бронирований студии по времени.
CREATE INDEX idx_bookings_studio_time
ON music_studio.bookings (studio_id, start_time, end_time);


-- 2. Индекс для получения истории бронирований пользователя.
CREATE INDEX idx_bookings_user_time
ON music_studio.bookings (user_id, start_time);


-- 3. Частичный индекс для поиска проблемного оборудования.
CREATE INDEX idx_equipment_problem_status
ON music_studio.equipment (status)
WHERE status IN ('maintenance', 'broken');