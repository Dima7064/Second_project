-- !!! Программа делает все те же пункты, что в Pandas. Но теперь решение через PostgreSQL !!!

/*
Задачи работы:

1. Медианный чек, средняя прибыль на заказ. Круговая диаграмма распределения продаж по подкатегориям
2. Топ-5 самых продаваемых и прибыльных товаров. Bar plot топ-5 товаров по продажам
3. Корреляция между количеством товаров, стоимостью и прибылью.

Информация про конкретную страну в 2018 году: Германия

1. Продажи и прибыль по городам. Выявление наиболее и наименее прибыльных городов
2. Топ-3 самые прибыльные подкатегории. Топ-5 самых прибыльных городов для каждой такой подкатегории (по 5 городов для каждой подкатегории)
3. Самые популярные города по каждому виду доставки (по два города)
4. Самый прибыльный месяц. Самый прибыльный город этого месяца и самая прибыльная подкатегория этого города
5. В каком сегменте покупателей наиболее распространена доставка типа "Economy"
6. Какие категории товаров дают самых ценных потребителей? Какие группы клиентов приносят наибольшую прибыль? 
7. Выводы работы
*/

/*
Пояснения к таблице:

Order ID -> ID заказа

Order Date -> Дата заказа

Customer Name -> Имя клиента

City -> Город

Country -> Страна

State -> Штат

Region -> Регион

Segment -> Сегмент потребителей

Category -> Категория

Ship Mode -> Режим отправки заказа

Sub-Category -> Подкатегория

Product Name -> Название продукта

Quantity -> Количество проданного товара

Cost -> Затраты на производство Quantity-товаров

Profit -> Прибыль с продажи Quantity-товаров (Sales - Cost)

Sales -> Выручка с продажи Quantity-товаров (Profit + Cost)
*/

-- 1. Медианный чек, средняя прибыль на заказ
-- Медианный чек
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY "Sales") AS median
FROM "Shop";

-- средняя прибыль на заказ
SELECT ROUND(AVG("Profit"), 2)
FROM "Shop";

-- 2. Топ-5 самых продаваемых и прибыльных товаров
-- Топ-5 самых продаваемых
SELECT "Sub-Category", SUM("Quantity") AS Quantity, SUM("Profit") AS Profit
FROM "Shop"
GROUP BY "Sub-Category"
ORDER BY Quantity DESC
LIMIT 5;

-- Топ-5 самых прибыльных
SELECT "Sub-Category", SUM("Quantity") AS Quantity, SUM("Profit") AS Profit
FROM "Shop"
GROUP BY "Sub-Category"
ORDER BY Profit DESC
LIMIT 5;

-- 3. Корреляция между количеством товаров, стоимостью и прибылью.
SELECT
	ROUND(CORR("Sales", "Cost")::numeric, 2) AS Quantity_Cost,
	ROUND(CORR("Sales", "Profit")::numeric, 2) AS Quantity_Profit,
	ROUND(CORR("Profit", "Cost")::numeric, 2) AS Profit_Cost
FROM "Shop";

/*
Вывод по корреляциям:

Общая стоимость и себестоимость: 0.85. Это означает, что с ростом выручки обычно увеличиваются и затраты. Чем больше продаёшь, тем больше тратишь на производство товаров.

Общая стоимость и прибыль: 0.82. Чем выше выручка, тем выше прибыль.

Себестоимость и прибыль: 0.38. Это говорит о том, что рост затрат не всегда ведёт к пропорциональному росту прибыли.

Возможные причины: 
1) Непостоянная наценка (например, в некоторых случаях высокая себестоимость съедает прибыль).

2) Разные категории товаров по маржинальности
*/




-- Информация про конкретную страну в 2018 году: Германия
-- 1. Продажи и прибыль по городам. Выявление наиболее и наименее прибыльных городов
-- Самые прибыльные
SELECT "City", SUM("Quantity") AS Quantity, SUM("Profit") AS Profit
FROM "Shop" s
WHERE "Country" = 'Germany' AND EXTRACT(YEAR FROM to_date("Order Date", 'MM/DD/YYYY')) = 2018
GROUP BY "City"
ORDER BY Profit DESC
LIMIT 5;

-- Менее прибыльные
SELECT "City", SUM("Quantity") AS Quantity, SUM("Profit") AS Profit
FROM "Shop"
WHERE "Country" = 'Germany' AND EXTRACT(YEAR FROM to_date("Order Date", 'MM/DD/YYYY')) = 2018
GROUP BY "City"
ORDER BY Profit
LIMIT 5;

-- 2. Топ-3 самые прибыльные подкатегории. Топ-5 самых прибыльных городов для каждой такой подкатегории (по 5 городов для каждой подкатегории)
WITH category AS(
	SELECT "Sub-Category", SUM("Profit") AS category_profit
	FROM "Shop"
	WHERE "Country" = 'Germany' AND EXTRACT(YEAR FROM to_date("Order Date", 'MM/DD/YYYY')) = 2018
	GROUP BY ("Sub-Category")
	ORDER BY category_profit DESC
	LIMIT 3
),
top_cities AS (
	SELECT s."Sub-Category", s."City", SUM(s."Profit") as city_profit, 
	ROW_NUMBER() OVER(PARTITION BY s."Sub-Category" ORDER BY SUM(s."Profit")) AS rn
	FROM "Shop" s
	JOIN category c ON s."Sub-Category" = c."Sub-Category"
	WHERE "Country" = 'Germany' AND EXTRACT(YEAR FROM to_date("Order Date", 'MM/DD/YYYY')) = 2018
	GROUP BY s."Sub-Category", s."City"
)
SELECT "Sub-Category", "City", city_profit
FROM top_cities
WHERE rn <= 5
ORDER BY "Sub-Category", city_profit DESC;

-- 3. Самые популярные города по каждому виду доставки (по два города)
WITH delivery AS (
	SELECT "Ship Mode", "City", COUNT(*) as delivery_count,
	ROW_NUMBER() OVER(PARTITION BY "Ship Mode" ORDER BY COUNT(*) DESC) AS rn
	FROM "Shop"
	WHERE "Country" = 'Germany' AND EXTRACT(YEAR FROM to_date("Order Date", 'MM/DD/YYYY')) = 2018
	GROUP BY "Ship Mode", "City"
)
SELECT "Ship Mode", "City", delivery_count
FROM delivery
WHERE rn <= 2;

-- 4. Самый прибыльный месяц. Самый прибыльный город этого месяца и самая прибыльная подкатегория этого города
WITH top_months AS(
	SELECT EXTRACT(MONTH FROM to_date("Order Date", 'MM/DD/YYYY')) AS top_month, SUM("Profit") AS month_profit
	FROM "Shop"
	WHERE "Country" = 'Germany' AND EXTRACT(YEAR FROM to_date("Order Date", 'MM/DD/YYYY')) = 2018
	GROUP BY top_month
	ORDER BY month_profit DESC
	LIMIT 1
),
top_city AS(
	SELECT tm.top_month, s."City", s."Profit"
	FROM top_months tm
	JOIN "Shop" s ON tm.top_month = EXTRACT(MONTH FROM to_date(s."Order Date", 'MM/DD/YYYY'))
	WHERE "Country" = 'Germany' AND EXTRACT(YEAR FROM to_date("Order Date", 'MM/DD/YYYY')) = 2018
	ORDER BY s."Profit" DESC
	LIMIT 1
)
SELECT tc.top_month, tc."City", s."Sub-Category", s."Profit"
FROM top_city tc
JOIN "Shop" s ON tc."City" = s."City"
ORDER BY s."Profit" DESC
LIMIT 1;

-- 5. В каком сегменте покупателей наиболее распространена доставка типа "Economy"
SELECT "Ship Mode", "Segment", COUNT(*) AS delivery_count
FROM "Shop"
WHERE "Country" = 'Germany' AND EXTRACT(YEAR FROM to_date("Order Date", 'MM/DD/YYYY')) = 2018
GROUP BY "Ship Mode", "Segment"
ORDER BY delivery_count DESC
LIMIT 1;

-- 6. Какие категории товаров дают самых ценных потребителей? Какие группы клиентов приносят наибольшую прибыль?
-- Какие категории товаров дают самых ценных потребителей
SELECT "Category", SUM("Profit") AS Profit
FROM "Shop"
WHERE "Country" = 'Germany' AND EXTRACT(YEAR FROM to_date("Order Date", 'MM/DD/YYYY')) = 2018
GROUP BY "Category"
ORDER BY Profit DESC;

-- Какие группы клиентов приносят наибольшую прибыль
SELECT "Segment", SUM("Profit") AS Profit
FROM "Shop"
WHERE "Country" = 'Germany' AND EXTRACT(YEAR FROM to_date("Order Date", 'MM/DD/YYYY')) = 2018
GROUP BY "Segment"
ORDER BY Profit DESC;

-- Сколько процентов от всех потребителей составляют простые покупатели - самая прибыльная группа
WITH segment_counts AS (
    SELECT "Segment", COUNT(*) AS count_segment, SUM(COUNT(*)) OVER () AS total_count
    FROM "Shop"
    WHERE "Country" = 'Germany' AND EXTRACT(YEAR FROM to_date("Order Date", 'MM/DD/YYYY')) = 2018
    GROUP BY "Segment"
	LIMIT 1
)
SELECT "Segment", count_segment, ROUND((count_segment * 100.0 / total_count), 2) AS percentage
FROM segment_counts;

-- Сколько процентов от всех прибыли составляет прибыль от простых потребителей
WITH profit_counts AS(
	SELECT "Segment", SUM("Profit") AS profit, SUM(SUM("Profit")) OVER () AS sum_profit
	FROM "Shop"
	WHERE "Country" = 'Germany' AND EXTRACT(YEAR FROM to_date("Order Date", 'MM/DD/YYYY')) = 2018
	GROUP BY "Segment"
	ORDER BY profit DESC
	LIMIT 1
)
SELECT "Segment", ROUND(profit * 100 / sum_profit, 2)
FROM profit_counts


-- 7. Выводы работы (то же самое, что и в файле с Pandas)
/*
1. Самыми прибыльными городами Германии в 2018 году являются Берлин, Гамбург, Нюрнберг, Мюнхен. 
Это связано с большими размерами городов и их населением, вследствие чего количество заказов и выручка там находятся на высоких позициях. 
Так что результаты вполне ожидаемы.

   Что же касается наименее прибыльных городов, то худшее положение у Дрездена. Хоть город является большим по площади и населению, 
   количество заказов и прибыль крайне малы. Для выявления причины такого маленького спроса на товары можно изучить, на что ориентирован город в большей степени 
   (некоторые города могут быть заточены на какую-то конкретную функцию: город для предпринимателей, IT-специалистов, торговый город и прочее. Гамбург, например, 
   является важным торговым портовым городом Германии). Возможно, товары, которые мы продаём, просто не востребованы в Дрездене.
   !!!Хотя, скорее всего, в нашем случае это мало вероятно, так как наши товары влючают в себя телефоны, стулья, столы и прочие вещи, 
   которыми пользуются все и везде!!!

   Если же наши товары нужны в этом городе, то нужно провести маркетинговую кампанию в городе и изучить конкурентов (цены, маркетинг, качество)
   
2. Самыми популярными товарами являются телефоны, книжные полки и стулья. А в топе городов по продажам этих товаров 
чаще всего встречается Берлин и Мюнхен - два крупных города, один из которых является столицей. Так что и эти результаты вполне ожидаемы.

4. Самым прибыльным месяцем является Август, самый прибыльный город в Августе - Нюрнберг с прибылью 2406. 
Самый продаваемый товар Нюрнберга в Августе - столы с прибылью от продаж 2406, что означает следующее: столы были единственным товаром, 
который продавался нашей компанией в Нюрнберге в 2018 году в Августе

5. Доставка типа "Economy" наиболее распространена среди простых покупателей (физических лиц). Скорее всего, это связано с тем, 
что простые люди не хотят доплачивать деньги за более быструю доставку в отличие от офисов.

6. Простые покупатели (физические лица) оказались самой прибыльной категорией потребителей. А самой прибыльной группой товаров оказалась мебель. 
Логично предположить, что эти две группы дополняют друг друга (простым людям в большинстве случаев нужна мебель, а не офисные принадлежности)

    Кроме того, было выявлено, что 56% всех потребителей составляют физические лица, обычные люди, на которых приходится 64% всей прибыли
*/	