/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Никитина Полина

*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
SELECT 
	COUNT (id) AS count_id,
	SUM (payer) AS sum_payer,
	ROUND(AVG(payer),4) AS part_payer
	FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:

	SELECT 
	race,
	COUNT (id) AS count_id,
	SUM (payer) AS sum_payer,
	ROUND(AVG(payer),4) AS part_payer
FROM fantasy.users AS u
LEFT JOIN fantasy.race AS r 
	ON u.race_id=r.race_id
GROUP BY race
ORDER BY part_payer DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

SELECT 
	COUNT(transaction_id) AS count_id,
	SUM(AMOUNT) AS total_amount,
	MIN(amount) AS min_amount,
	MAX(amount) AS max_amount,
	AVG(amount)::NUMERIC(10,2) AS avg_amount,
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana,
	STDDEV(amount) AS stand_dev
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:

WITH 
	part1 AS 
	(SELECT
		COUNT(transaction_id) AS count_amount0
	FROM fantasy.events
	WHERE amount=0),
	part2 AS
	(SELECT 
		COUNT (*) AS count_amount
	FROM fantasy.events)
SELECT 
	p2.count_amount,
	p1.count_amount0,
	p1.count_amount0::REAL/p2.count_amount AS part_amount0
FROM part1 AS p1
	JOIN part2 AS p2 
	ON 1=1;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
	--анализ неплатящих пользователей
	WITH -- считаем количество пользователей
total_users AS 
	(SELECT
	payer,
	COUNT (id) AS count_id
	FROM fantasy.users 
	GROUP BY payer),
total_transaction AS -- считаем количество транзакций
	(SELECT 
	payer,
	COUNT(transaction_id) AS count_orders
	FROM fantasy.users AS u 
	JOIN fantasy.events AS e
	ON u.id=e.id
	WHERE amount > 0
	GROUP BY payer),
amount AS -- считаем среднюю стоимость
	(SELECT 
	payer,
	ROUND(AVG(amount)::NUMERIC,2) AS avg_amount
	FROM fantasy.users AS u 
	JOIN fantasy.events AS e
	ON u.id=e.id
	WHERE amount > 0
	GROUP BY payer)
SELECT 
	CASE 
		WHEN tu.payer =1 THEN 'платящие'
		WHEN tt.payer =0 THEN 'неплатящие'
	END AS payer ,
	count_id,
	count_orders/count_id AS avg_buy,
	avg_amount
FROM total_users AS tu
JOIN total_transaction AS tt ON tu.payer=tt.payer
JOIN amount ON tt.payer=amount.payer;


-- 2.4: Популярные эпические предметы: 
-- Напишите ваш запрос здесь
SELECT 
	game_items,
	COUNT (transaction_id ) AS count_tr,
	ROUND(COUNT (transaction_id)::numeric/(SELECT 
		COUNT(transaction_id) 
	FROM fantasy.events
	WHERE amount >0),4) AS part_transaction,
	ROUND(COUNT (DISTINCT e.id)::NUMERIC/(SELECT count(DISTINCT id) FROM fantasy.events WHERE amount >0)::NUMERIC,2) AS part_users_buy
FROM fantasy.items AS i 
JOIN fantasy.events AS e
	ON i.item_code=e.item_code
WHERE amount > 0
GROUP BY game_items
ORDER BY count_tr DESC;


-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персоонажа:
WITH -- общее кол-во играков
part1 AS
	( SELECT  
		race,
		COUNT (u.id) AS total_users,--кол-во пользователей
		SUM(payer) AS users_payers--платящие пользователи
	FROM fantasy.users AS u
	LEFT JOIN fantasy.race AS r 
	ON u.race_id=r.race_id 
	GROUP BY race),
part2 AS
	(SELECT 
	race,
	COUNT(DISTINCT e.id) AS count_buy_u, -- кол-во пользователей с покупками
	COUNT(e.transaction_id) AS total_transaction, -- кол-во покупок
	ROUND(SUM(amount ::NUMERIC),2) AS sum_amount, -- сумма покупок
	ROUND(AVG(amount::NUMERIC),2) AS avg_amount -- средняя стоимость
FROM fantasy.users AS u
LEFT JOIN fantasy.events AS e
	ON u.id=e.id
LEFT JOIN fantasy.race AS r 
	ON u.race_id=r.race_id 
WHERE amount > 0
GROUP BY r.race )
SELECT 
	part1.race,
	total_users,
	count_buy_u,
	ROUND((count_buy_u::NUMERIC/total_users)::NUMERIC,2) AS part_users_buy,
	ROUND((users_payers::NUMERIC/count_buy_u)::NUMERIC,2) AS part_users_payer,
	ROUND((total_transaction::NUMERIC/count_buy_u)::NUMERIC,2) AS avg_transaction,
	avg_amount,
	ROUND((sum_amount::NUMERIC/count_buy_u)::NUMERIC,2) AS avg_sum_amount
FROM part1
LEFT JOIN part2
		ON part1.race=part2.race
ORDER BY avg_amount DESC;
-- Задача 2: Частота покупок
-- разделение на ранги

WITH 
first_last_dt AS -- посчитала дни между покупками
	(SELECT 
		payer,
		u.id,
		transaction_id,
     	LEAD(e.date) OVER (PARTITION BY e.id ORDER BY e.date )::DATE - e.date::date AS interv
       FROM fantasy.events AS e 
	LEFT JOIN fantasy.users AS u
	ON u.id=e.id
	WHERE amount > 0),
users AS -- данные в разрезе пользователя
	(SELECT
		CASE
			WHEN payer =0 THEN 'неплатящий'
			WHEN payer =1 THEN 'платящий'
		END AS status,
	  	COUNT(transaction_id) AS total_buy,
	  	ROUND(avg(interv)::NUMERIC,0) AS interv
	  	FROM first_last_dt
	  GROUP BY id,payer
	 ),
	 a AS -- присвоила имя рангам
	(SELECT 
		CASE 
			WHEN NTILE(3) OVER(ORDER BY interv DESC) ='3'
			THEN 'высокая частота'
			WHEN NTILE(3) OVER(ORDER BY interv DESC) ='2'
			THEN 'умеренная частота'
			WHEN NTILE(3) OVER(ORDER BY interv DESC) ='1'
			THEN 'низкая частота'
		END AS rang, *
FROM users
WHERE 	total_buy > 24)

SELECT rang,
(SELECT count(status) FROM a WHERE status ='платящий')::numeric/count (status) AS part_payer,
ROUND(AVG (total_buy)::NUMERIC,2) avg_buy,
ROUND(avg (interv)::NUMERIC,2) AS avg_day
FROM a
GROUP BY rang;

