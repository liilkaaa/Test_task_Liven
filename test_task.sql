CREATE OR REPLACE TABLE users_sessions(
    id INT,
    id_user INT,
    action VARCHAR(5),
    date_action DATETIME
);


INSERT INTO users_sessions VALUES
    -- тільки 1 open
    (1, 101, 'open', '2026-02-17 11:30:33'),
    -- дуже довга сесія
    (2, 102, 'open', '2026-02-15 10:02:20'),
    (2, 102, 'close', '2026-02-20 18:30:12'),
    -- два рази Open
    (3, 103, 'open', '2026-02-18 18:23:56'),
    (3, 103, 'open', '2026-02-18 18:24:00'),
    (3, 103, 'close', '2026-02-18 19:24:00'),
    -- 3 рази close
    (4, 104, 'open', '2026-02-19 06:25:12'),
    (4, 104, 'close', '2026-02-19 07:00:45'),
    (4, 104, 'close', '2026-02-19 07:02:30'),
    (4, 104, 'close', '2026-02-19 07:03:50'),
    -- тільки 1 close
    (5, 105, 'close', '2026-02-20 14:45:10'),
    -- все ок
    (6, 106, 'open', '2026-02-20 15:08:59'),
    (6, 106, 'close', '2026-02-20 17:29:34'),
    -- все ок
    (7, 107, 'open', '2026-02-13 09:10:45'),
    (7, 107, 'close', '2026-02-13 10:00:54'),
    -- все ок
    (8, 107, 'open', '2026-02-14 14:24:18'),
    (8, 107, 'close', '2026-02-14 15:24:18'),
    -- ок
    (9, 107, 'open', '2026-02-15 20:00:11'),
    (9, 107, 'close', '2026-02-15 22:12:03'),
    -- ок
    (10, 108, 'open', '2026-02-20 02:23:12'),
    (10, 108, 'close', '2026-02-20 03:24:33'),
    -- action із NULL
    (11, 102, NULL, '2026-02-17 08:45:23'),
    -- ок
    (12, 107, 'open', '2026-02-17 09:00:12'),
    (12, 107, 'close', '2026-02-17 10:24:07'),
    -- нема дати
    (13, 103, 'open', NULL),
    --із 23 до ранку
    (14, 105, 'open', '2026-02-18 23:00:03'),
    (14, 105, 'close', '2026-02-19 01:01:22'),
    -- close раніше як open
    (15, 106, 'open', '2026-02-20 11:00:03'),
    (15, 106, 'close', '2026-02-20 09:23:00'),
    -- сесія почалась до періоду 10 днів
    (16, 109, 'open', '2026-02-10 10:56:00'),
    (16, 109, 'close', '2026-02-13 10:03:00'),
    -- дублювання сесії
    (17, 104, 'open', '2026-02-16 09:56:00'),
    (17, 104, 'close', '2026-02-16 10:40:56'),
    (17, 104, 'open', '2026-02-16 09:56:00'),
    (17, 104, 'close', '2026-02-16 10:40:56'),
    -- сесія відбулась до межі 10 днів
    (18, 103, 'open', '2026-02-09 10:00:56'),
    (18, 103, 'close', '2026-02-09 12:56:09');


SELECT * FROM users_sessions;


WITH cleaned_actions AS(
SELECT DISTINCT id, id_user, action, date_action
FROM users_sessions
WHERE
    id iS NOT NULL
    AND id_user IS NOT NULL
    AND action IS NOT NULL
    AND date_action IS NOT NULL
    AND action IN ('open', 'close')
),
sessions AS(
SELECT id,id_user,
    MIN(CASE WHEN action = 'open' THEN date_action END) as start_time,
    MAX(CASE WHEN action = 'close' THEN date_action END) as time_end
FROM cleaned_actions
GROUP BY id, id_user),
valid_sessions AS(
SELECT id, id_user,start_time,
    CASE WHEN time_end IS NULL THEN CAST(CURRENT_TIMESTAMP AS DATETIME) ELSE time_end END AS end_time
    FROM sessions
    WHERE start_time < end_time
    ),
ten_days AS (
SELECT
    id,
    id_user,
    GREATEST(start_time, (current_date - INTERVAL '9 days')::TIMESTAMP) AS start_time,
    LEAST(end_time, current_timestamp) AS end_time
FROM valid_sessions
WHERE end_time > (current_date - INTERVAL '9 days')
  AND start_time < current_timestamp
),
calendar AS (
  SELECT CAST(current_date - i * INTERVAL '1 day' AS DATE) AS day_date
  FROM range(0, 10) t(i)
),
session_parts AS (
SELECT
    c.day_date, s.id_user,
    GREATEST(s.start_time, c.day_date::TIMESTAMP) AS day_start,
    LEAST(s.end_time, (c.day_date + INTERVAL '1 day')::TIMESTAMP) AS day_end
FROM ten_days s
JOIN calendar c ON s.start_time < (c.day_date + INTERVAL '1 day')::TIMESTAMP AND s.end_time > c.day_date::TIMESTAMP
)
SELECT
    id_user,
    day_date,
    SUM(datediff('second', day_start, day_end)) / 3600.0 AS total_hours
FROM session_parts
GROUP BY id_user, day_date
ORDER BY day_date DESC, total_hours DESC;




