CREATE TABLE exch_quotes_archive (
     exchange_id INT NOT NULL,
     bond_id INT NOT NULL,
     trading_date DATE NOT NULL,
     bid DECIMAL(10,4) NULL,
     ask DECIMAL(10,4) NULL,
     PRIMARY KEY (exchange_id, bond_id, trading_date)
);

DELIMITER $$

CREATE PROCEDURE populate_exch_quotes_archive(IN anchor_date DATE)
BEGIN
    DECLARE bond_id_var INT DEFAULT 1;
    DECLARE date_counter INT DEFAULT 0;
    DECLARE curr_date DATE;
    
    IF anchor_date IS NULL THEN
        SET anchor_date = CURDATE();
    END IF;

    -- Удаление существующих данных в таблице (опционально)
    DELETE FROM exch_quotes_archive;

    -- Сброс временных таблиц, если они существуют
    DROP TEMPORARY TABLE IF EXISTS temp_exchanges;
    DROP TEMPORARY TABLE IF EXISTS temp_bonds;
    DROP TEMPORARY TABLE IF EXISTS temp_dates;
    DROP TEMPORARY TABLE IF EXISTS temp_bond_exclude;

    -- Создание временной таблицы temp_exchanges
    CREATE TEMPORARY TABLE temp_exchanges (exchange_id INT PRIMARY KEY);
    INSERT INTO temp_exchanges (exchange_id)
    VALUES (1), (4), (72), (99), (250), (399), (502), (600);

    -- Создание временной таблицы temp_bonds
    CREATE TEMPORARY TABLE temp_bonds (bond_id INT PRIMARY KEY);

    -- Заполнение temp_bonds от 1 до 200
    SET bond_id_var = 1;
    bond_loop: WHILE bond_id_var <= 200 DO
        INSERT INTO temp_bonds (bond_id) VALUES (bond_id_var);
        SET bond_id_var = bond_id_var + 1;
    END WHILE bond_loop;

    -- Создание временной таблицы temp_dates
    CREATE TEMPORARY TABLE temp_dates (trading_date DATE PRIMARY KEY);

    -- Заполнение temp_dates последними 62 рабочими днями (исключая субботы и воскресенья)
    SET date_counter = 0;
    SET curr_date = anchor_date;

    date_loop: WHILE (SELECT COUNT(*) FROM temp_dates) < 62 DO
        SET curr_date = DATE_SUB(curr_date, INTERVAL 1 DAY);
        IF DAYOFWEEK(curr_date) NOT IN (1, 7) THEN
            INSERT INTO temp_dates (trading_date) VALUES (curr_date);
        END IF;
        SET date_counter = date_counter + 1;
        IF date_counter > 100 THEN
            LEAVE date_loop;
        END IF;
    END WHILE date_loop;

    -- Удаление temp_bond_exclude, если существует
    DROP TEMPORARY TABLE IF EXISTS temp_bond_exclude;

    -- Создание временной таблицы temp_bond_exclude
    CREATE TEMPORARY TABLE temp_bond_exclude (
        bond_id INT PRIMARY KEY,
        exclude_exchange_id INT
    );

    -- Назначение случайного исключения из обмена для каждой облигации
    INSERT INTO temp_bond_exclude (bond_id, exclude_exchange_id)
    SELECT
        b.bond_id,
        (SELECT exchange_id FROM temp_exchanges ORDER BY RAND() LIMIT 1) AS exclude_exchange_id
    FROM temp_bonds b;

    -- Вставка случайных цен покупки и продажи в exch_quotes_archive
    INSERT INTO exch_quotes_archive (exchange_id, bond_id, trading_date, bid, ask)
    SELECT
        e.exchange_id,
        b.bond_id,
        d.trading_date,
        CASE WHEN RAND() < 0.1 THEN NULL ELSE ROUND(RAND() * 2 - 0.01, 4) END AS bid,
        CASE WHEN RAND() < 0.1 THEN NULL ELSE ROUND(RAND() * 2 - 0.01, 4) END AS ask
    FROM temp_bonds b
    JOIN temp_exchanges e ON e.exchange_id NOT IN (
        SELECT exclude_exchange_id FROM temp_bond_exclude WHERE bond_id = b.bond_id
    )
    CROSS JOIN temp_dates d;

    -- Убеждаемся, что бид и аск не равны NULL
    UPDATE exch_quotes_archive
    SET
        bid = CASE WHEN bid IS NULL AND ask IS NULL THEN ROUND(RAND() * 2 - 0.01, 4) ELSE bid END,
        ask = CASE WHEN bid IS NULL AND ask IS NULL THEN ROUND(RAND() * 2 - 0.01, 4) ELSE ask END
    WHERE bid IS NULL AND ask IS NULL;

    -- Удаляем временные таблицы
    DROP TEMPORARY TABLE IF EXISTS temp_exchanges;
        DROP TEMPORARY TABLE IF EXISTS temp_bonds;
        DROP TEMPORARY TABLE IF EXISTS temp_dates;
        DROP TEMPORARY TABLE IF EXISTS temp_bond_exclude;
END $$

DELIMITER ;

-- Чтобы выполнить процедуру и заполнить таблицу, выполняем команду:
CALL populate_exch_quotes_archive(NULL);
