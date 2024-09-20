-- Чтобы выполнить процедуру и заполнить таблицу, выполняем команду:
CALL populate_exch_quotes_archive(NULL);

-- Объединение Задания 2 и Задания 3 в один сценарий
WITH RECURSIVE dates AS (
    -- Генерация данных за последние 14 календарных дней, включая выходные
    SELECT CURDATE() - INTERVAL 13 DAY AS trading_date
    UNION ALL
    SELECT trading_date + INTERVAL 1 DAY
    FROM dates
    WHERE trading_date + INTERVAL 1 DAY <= CURDATE()
),
bonds AS (
    -- Получение списка всех облигаций
    SELECT DISTINCT bond_id FROM exch_quotes_archive
),
bond_dates AS (
    -- Создание всех возможных комбинаций облигаций и дат
    SELECT bond_id, trading_date
    FROM bonds CROSS JOIN dates
),
averages AS (
    -- Расчет средних цен для каждой пары облигация-дата
    SELECT
        bd.bond_id,
        bd.trading_date,
        AVG(eqa.bid) AS avg_bid,
        AVG(eqa.ask) AS avg_ask
    FROM bond_dates bd
    LEFT JOIN exch_quotes_archive eqa
        ON eqa.bond_id = bd.bond_id
        AND eqa.trading_date = bd.trading_date
    GROUP BY
        bd.bond_id,
        bd.trading_date
)
-- Расчет 7-дневной скользящей средней
SELECT
    a.bond_id,
    a.trading_date,
    a.avg_bid,
    a.avg_ask,
    -- Вычисление 7-дневного скользящего среднего для avg_bid
    AVG(a.avg_bid) OVER (
        PARTITION BY a.bond_id
        ORDER BY a.trading_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_bid,
    -- Вычисление 7-дневной скользящей средней для avg_ask
    AVG(a.avg_ask) OVER (
        PARTITION BY a.bond_id
        ORDER BY a.trading_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_ask
FROM averages a
ORDER BY
    a.bond_id,
    a.trading_date;
