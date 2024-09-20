-- Генерация данных за последние 14 календарных дней, включая выходные.
WITH RECURSIVE dates AS (
    SELECT CURDATE() - INTERVAL 13 DAY AS trading_date
    UNION ALL
    SELECT trading_date + INTERVAL 1 DAY
    FROM dates
    WHERE trading_date + INTERVAL 1 DAY <= CURDATE()
),

-- Получение списка всех облигаций
bonds AS (
    SELECT DISTINCT bond_id
    FROM exch_quotes_archive
),

-- Создание всех возможных комбинаций облигаций и дат
bond_dates AS (
    SELECT bond_id, trading_date
    FROM bonds CROSS JOIN dates
)

-- Расчет средних цен для каждой пары облигация-дата
SELECT bd.bond_id,
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
ORDER BY
    bd.bond_id,
    bd.trading_date;
