-- =========================================================
-- 03_analysis.sql
-- Olist E-commerce Analysis
-- =========================================================
--
-- Цель:
-- анализ продаж, клиентов, категорий, доставки,
-- отзывов и продавцов на основе исторических данных Olist.
--
-- Основной анализ продаж:
-- только заказы со статусом delivered.
--
-- GMV = SUM(order_items.price)
-- =========================================================


-- =========================================================
-- 1. БАЗОВЫЕ KPI
-- =========================================================
SELECT
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT c.customer_unique_id) AS customers,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS gmv,
    ROUND(SUM(oi.freight_value), 2) AS freight,
    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value
FROM public.orders o
JOIN public.order_items oi
    ON o.order_id = oi.order_id
JOIN public.customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered';
-- Базовые KPI по завершённым заказам:
-- 96 478 доставленных заказов;
-- 93 358 уникальных покупателей;
-- 110 197 проданных товарных позиций;
-- GMV товаров — 13 221 498.11;
-- стоимость доставки — 2 198 275.64;
-- средний чек — 137.04.
--
-- В среднем на один доставленный заказ приходится
-- около 1.14 товарной позиции.
--
-- Эти показатели используются как базовая точка
-- для дальнейшего анализа продаж.
-- =========================================================
-- 2. ДИНАМИКА ПРОДАЖ
-- =========================================================

SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT c.customer_unique_id) AS customers,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS gmv,
    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value
FROM public.orders o
JOIN public.order_items oi
    ON o.order_id = oi.order_id
JOIN public.customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2016-10-01'
  AND o.order_purchase_timestamp < '2018-10-01'
GROUP BY 1
ORDER BY 1;
-- Динамика продаж показывает заметный рост объёма бизнеса в течение 2017 года.
-- Ноябрь 2017 выделяется резким пиком количества заказов и GMV.
--
-- В 2018 году продажи стабилизируются на значительно более высоком уровне:
-- ежемесячно выполняется примерно 6–7 тыс. доставленных заказов.
--
-- Ноябрь 2017 является крупнейшим месяцем
-- как по количеству доставленных заказов (7 289),
-- так и по GMV (987 765.37).
--
-- Количество заказов и GMV изменяются не полностью синхронно,
-- поскольку на GMV также влияет средний чек.
--
-- Данные конца 2016 года очень разрежены,
-- поэтому этот период не используем для основных выводов о динамике.
-- =========================================================
-- 3. ТОВАРНЫЕ КАТЕГОРИИ
-- =========================================================

WITH category_sales AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'unknown'
        ) AS category,

        COUNT(*) AS items_sold,
        COUNT(DISTINCT o.order_id) AS orders,
        ROUND(SUM(oi.price), 2) AS gmv,
        ROUND(AVG(oi.price), 2) AS average_item_price

    FROM public.orders o
    JOIN public.order_items oi
        ON o.order_id = oi.order_id
    JOIN public.products p
        ON oi.product_id = p.product_id
    LEFT JOIN public.category_translation ct
        ON p.product_category_name = ct.product_category_name

    WHERE o.order_status = 'delivered'

    GROUP BY
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'unknown'
        )
)
SELECT
    category,
    items_sold,
    orders,
    gmv,
    average_item_price,
    ROUND(
        100.0 * gmv / SUM(gmv) OVER (),
        2
    ) AS gmv_share_percent,
    RANK() OVER (
        ORDER BY gmv DESC
    ) AS gmv_rank
FROM category_sales
ORDER BY gmv DESC
LIMIT 15;
-- Наибольший GMV формируют категории health_beauty, watches_gifts
-- и bed_bath_table.
--
-- health_beauty является лидером по GMV и формирует 9.33%
-- общего GMV завершённых заказов.
--
-- Категории отличаются по механизму формирования GMV:
-- bed_bath_table имеет большой объём проданных товаров,
-- но сравнительно невысокую среднюю цену позиции,
-- тогда как watches_gifts достигает высокого GMV
-- при меньшем объёме за счёт более высокой средней цены товара.
--
-- Топ-5 категорий формируют около 39.8% общего GMV,
-- топ-10 — около 62.4%.
-- Таким образом, продажи заметно концентрируются в крупнейших
-- категориях, но одна категория не доминирует в структуре продаж.
-- =========================================================
-- 4. КЛИЕНТЫ И РЕГИОНЫ
-- =========================================================
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS orders_count
    FROM public.orders o
    JOIN public.customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS customers,

    COUNT(*) FILTER (
        WHERE orders_count = 1
    ) AS one_time_customers,

    COUNT(*) FILTER (
        WHERE orders_count >= 2
    ) AS repeat_customers,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE orders_count >= 2
        ) / COUNT(*),
        2
    ) AS repeat_customer_rate

FROM customer_orders;
-- Среди 93 358 покупателей завершённых заказов
-- 90 557 (97%) совершили только одну покупку,
-- а 2 801 покупатель (3%) совершили два и более заказа.
--
-- Таким образом, повторные покупки в исторических данных Olist
-- встречаются относительно редко.
-- Это указывает на преобладание разовых покупателей,
-- однако причины низкой повторяемости из имеющихся данных определить нельзя.
WITH state_sales AS (
    SELECT
        c.customer_state AS state,
        COUNT(DISTINCT o.order_id) AS orders,
        COUNT(DISTINCT c.customer_unique_id) AS customers,
        ROUND(SUM(oi.price), 2) AS gmv
    FROM public.orders o
    JOIN public.order_items oi
        ON o.order_id = oi.order_id
    JOIN public.customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_state
)

SELECT
    state,
    orders,
    customers,
    gmv,
    ROUND(
        gmv / orders,
        2
    ) AS average_order_value,
    ROUND(
        100.0 * gmv / SUM(gmv) OVER (),
        2
    ) AS gmv_share_percent
FROM state_sales
ORDER BY gmv DESC;
-- Продажи сильно концентрируются в крупнейших штатах.
-- São Paulo (SP) является основным рынком:
-- 40 501 доставленный заказ и 38.33% общего GMV.
--
-- Три крупнейших штата — SP, RJ и MG —
-- формируют около 63.4% общего GMV,
-- а топ-5 штатов — около 73.9%.
--
-- Средний чек заметно различается между регионами.
-- Однако высокие значения среднего чека в небольших штатах
-- необходимо интерпретировать осторожно из-за малого количества заказов.
--
-- Таким образом, основной объём бизнеса сосредоточен
-- в нескольких крупнейших штатах.
-- =========================================================
-- 5. ДОСТАВКА
-- =========================================================
SELECT
    COUNT(*) AS delivered_orders,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_purchase_timestamp
                )
            ) / 86400.0
        )::numeric,
        2
    ) AS average_delivery_days,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY
                EXTRACT(
                    EPOCH FROM (
                        order_delivered_customer_date
                        - order_purchase_timestamp
                    )
                ) / 86400.0
        )::numeric,
        2
    ) AS median_delivery_days,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              > order_estimated_delivery_date
    ) AS late_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_delivered_customer_date
                  > order_estimated_delivery_date
        ) / COUNT(*),
        2
    ) AS late_delivery_rate

FROM public.orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;
-- Для 96 470 доставленных заказов доступны даты,
-- необходимые для расчёта срока доставки.
-- У 8 доставленных заказов фактическая дата доставки отсутствует,
-- поэтому они не включены в расчёт.
--
-- Среднее время доставки составляет 12.56 дня,
-- медианное — 10.22 дня.
-- Среднее выше медианы, что указывает на наличие
-- заказов с более длительными сроками доставки,
-- которые повышают среднее значение.
--
-- 7 826 заказов были доставлены позже ожидаемой даты,
-- что составляет 8.11% анализируемых доставок.
WITH state_delivery AS (
    SELECT
        c.customer_state AS state,
        COUNT(*) AS delivered_orders,

        AVG(
            EXTRACT(
                EPOCH FROM (
                    o.order_delivered_customer_date
                    - o.order_purchase_timestamp
                )
            ) / 86400.0
        ) AS average_delivery_days,

        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY
                EXTRACT(
                    EPOCH FROM (
                        o.order_delivered_customer_date
                        - o.order_purchase_timestamp
                    )
                ) / 86400.0
        ) AS median_delivery_days,

        COUNT(*) FILTER (
            WHERE o.order_delivered_customer_date
                  > o.order_estimated_delivery_date
        ) AS late_orders

    FROM public.orders o
    JOIN public.customers c
        ON o.customer_id = c.customer_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL

    GROUP BY c.customer_state
)

SELECT
    state,
    delivered_orders,

    ROUND(
        average_delivery_days::numeric,
        2
    ) AS average_delivery_days,

    ROUND(
        median_delivery_days::numeric,
        2
    ) AS median_delivery_days,

    late_orders,

    ROUND(
        100.0 * late_orders / delivered_orders,
        2
    ) AS late_delivery_rate

FROM state_delivery
ORDER BY average_delivery_days DESC;
-- Сроки и качество доставки заметно различаются между штатами.
--
-- São Paulo (SP), крупнейший рынок по количеству заказов,
-- имеет сравнительно короткий средний срок доставки — 8.76 дня
-- и долю задержек 5.89%.
--
-- В ряде штатов сроки доставки значительно выше:
-- например, RJ — 15.31 дня, BA — 19.34 дня.
--
-- Высокий средний срок доставки не всегда сопровождается
-- высокой долей задержек, поскольку ожидаемые сроки доставки
-- также могут различаться между регионами.
--
-- Результаты небольших штатов необходимо интерпретировать осторожно
-- из-за малого количества заказов.
-- =========================================================
-- 6. ОТЗЫВЫ И ДОСТАВКА
-- =========================================================
WITH review_per_order AS (
    SELECT
        order_id,
        AVG(review_score) AS review_score
    FROM public.order_reviews
    GROUP BY order_id
),

delivery_reviews AS (
    SELECT
        o.order_id,

        CASE
            WHEN o.order_delivered_customer_date
                 > o.order_estimated_delivery_date
                THEN 'Late'
            ELSE 'On time'
        END AS delivery_status,

        r.review_score

    FROM public.orders o
    JOIN review_per_order r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)

SELECT
    delivery_status,

    COUNT(*) AS orders,

    ROUND(
        AVG(review_score)::numeric,
        2
    ) AS average_review_score,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score <= 2
        ) / COUNT(*),
        2
    ) AS low_review_rate,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score >= 4
        ) / COUNT(*),
        2
    ) AS high_review_rate

FROM delivery_reviews
GROUP BY delivery_status
ORDER BY delivery_status;
-- Между своевременностью доставки и оценкой заказа
-- наблюдается выраженная связь.
--
-- Для своевременно доставленных заказов средняя оценка составляет 4.29,
-- тогда как для задержанных — 2.57.
SELECT
    ROUND(
        AVG(review_score)::numeric,
        2
    ) AS average_review_score
FROM public.order_reviews;
-- Средняя оценка по всем записям отзывов составляет 4.09.
--
-- Среди своевременных заказов 82.77% имеют высокую оценку (4–5),
-- а доля низких оценок (1–2) составляет 9.19%.
--
-- Среди задержанных заказов ситуация существенно хуже:
-- 53.99% имеют низкую оценку и только 34.56% — высокую.
--
-- Таким образом, задержанные доставки связаны
-- со значительно менее благоприятным клиентским опытом.
-- Наблюдательные данные не позволяют утверждать,
-- что задержка является единственной причиной низкой оценки.
SELECT
    review_score,
    COUNT(*) AS reviews,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS review_share_percent
FROM public.order_reviews
GROUP BY review_score
ORDER BY review_score;
-- В целом оценки клиентов преимущественно положительные:
-- 57.78% отзывов имеют оценку 5,
-- ещё 19.29% — оценку 4.
--
-- Таким образом, 77.07% всех записей отзывов
-- имеют высокую оценку (4–5).
--
-- Доля низких оценок (1–2) составляет 14.69%,
-- нейтральных оценок 3 — 8.24%.
--
-- При этом предыдущий анализ показал,
-- что распределение оценок существенно ухудшается
-- среди заказов, доставленных позже ожидаемого срока.
-- =========================================================
-- 7. ПРОДАВЦЫ
-- =========================================================
WITH seller_sales AS (
    SELECT
        oi.seller_id,
        COUNT(*) AS items_sold,
        COUNT(DISTINCT o.order_id) AS orders,
        ROUND(SUM(oi.price), 2) AS gmv
    FROM public.orders o
    JOIN public.order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
)

SELECT
    seller_id,
    items_sold,
    orders,
    gmv,

    ROUND(
        gmv / orders,
        2
    ) AS gmv_per_order,

    ROUND(
        100.0 * gmv / SUM(gmv) OVER (),
        2
    ) AS gmv_share_percent,

    RANK() OVER (
        ORDER BY gmv DESC
    ) AS gmv_rank

FROM seller_sales
ORDER BY gmv DESC
LIMIT 15;
-- Продажи распределены между большим количеством продавцов.
--
-- Крупнейший продавец формирует только 1.72% общего GMV.
--
-- При этом продавцы заметно различаются по модели продаж:
-- часть достигает высокого GMV за счёт большого количества заказов,
-- а часть — за счёт более высокой стоимости товаров в заказе.
--
-- Таким образом, GMV не зависит критически
-- от одного или нескольких крупнейших продавцов.
WITH seller_sales AS (
    SELECT
        oi.seller_id,
        SUM(oi.price) AS gmv
    FROM public.orders o
    JOIN public.order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
),

ranked_sellers AS (
    SELECT
        seller_id,
        gmv,
        ROW_NUMBER() OVER (
            ORDER BY gmv DESC
        ) AS seller_rank
    FROM seller_sales
)

SELECT
    COUNT(*) AS sellers,

    ROUND(
        100.0 * SUM(gmv) FILTER (
            WHERE seller_rank <= 10
        ) / SUM(gmv),
        2
    ) AS top_10_gmv_share,

    ROUND(
        100.0 * SUM(gmv) FILTER (
            WHERE seller_rank <= 50
        ) / SUM(gmv),
        2
    ) AS top_50_gmv_share,

    ROUND(
        100.0 * SUM(gmv) FILTER (
            WHERE seller_rank <= 100
        ) / SUM(gmv),
        2
    ) AS top_100_gmv_share

FROM ranked_sellers;
-- В завершённых продажах участвуют 2 970 продавцов.
--
-- Топ-10 продавцов формируют 13.27% общего GMV,
-- топ-50 — 33.20%,
-- топ-100 — 45.52%.
--
-- Таким образом, продажи не зависят критически
-- от нескольких крупнейших продавцов,
-- однако почти половина GMV приходится на топ-100 продавцов.
-- Одновременно присутствует большое количество продавцов
-- с относительно небольшим вкладом в общий GMV.
-- =========================================================
-- 8. ИТОГОВЫЕ ВЫВОДЫ
-- =========================================================
--
-- 1. ПРОДАЖИ
--
-- В анализируемых данных содержится 96 478 завершённых заказов
-- от 93 358 уникальных покупателей.
-- Общий GMV товаров составляет 13 221 498.11,
-- средний чек — 137.04.
--
-- В течение 2017 года наблюдается выраженный рост продаж.
-- Ноябрь 2017 является крупнейшим месяцем
-- как по количеству заказов, так и по GMV.
-- В 2018 году объём продаж стабилизируется
-- примерно на уровне 6–7 тыс. доставленных заказов в месяц.
--
--
-- 2. ТОВАРНЫЕ КАТЕГОРИИ
--
-- Наибольший GMV формируют health_beauty,
-- watches_gifts и bed_bath_table.
--
-- Топ-5 категорий дают около 39.8% общего GMV,
-- топ-10 — около 62.4%.
--
-- Разные категории формируют GMV по-разному:
-- часть за счёт высокого объёма продаж,
-- часть за счёт более высокой средней цены товара.
--
--
-- 3. ПОКУПАТЕЛИ
--
-- Повторные покупки встречаются редко:
-- только 3.00% покупателей совершили два и более
-- завершённых заказа.
--
-- Данные показывают преобладание разовых покупателей,
-- однако причины низкой повторяемости
-- из имеющегося датасета определить нельзя.
--
--
-- 4. РЕГИОНЫ
--
-- Продажи существенно концентрируются в крупнейших штатах.
-- São Paulo формирует 38.33% общего GMV.
--
-- SP, RJ и MG вместе дают около 63.4% GMV,
-- а топ-5 штатов — около 73.9%.
--
-- При сравнении небольших регионов необходимо учитывать
-- малое количество заказов и повышенную нестабильность показателей.
--
--
-- 5. ДОСТАВКА
--
-- Среднее время доставки составляет 12.56 дня,
-- медианное — 10.22 дня.
--
-- 8.11% анализируемых заказов были доставлены
-- позже ожидаемой даты.
--
-- Между регионами наблюдаются существенные различия
-- как по срокам доставки, так и по доле задержек.
--
--
-- 6. КЛИЕНТСКИЙ ОПЫТ
--
-- В целом отзывы преимущественно положительные:
-- 77.07% записей отзывов имеют оценку 4 или 5.
--
-- При этом своевременность доставки сильно связана
-- с клиентской оценкой.
--
-- Средняя оценка своевременно доставленных заказов — 4.29,
-- задержанных — 2.57.
--
-- Среди задержанных заказов 53.99% имеют оценку 1–2,
-- тогда как среди своевременных заказов
-- доля таких оценок составляет только 9.19%.
--
-- Наблюдаемая связь не доказывает,
-- что задержка является единственной причиной низкой оценки.
--
--
-- 7. ПРОДАВЦЫ
--
-- В завершённых продажах участвуют 2 970 продавцов.
--
-- Топ-10 продавцов формируют 13.27% GMV,
-- топ-50 — 33.20%,
-- топ-100 — 45.52%.
--
-- Продажи не зависят критически от нескольких продавцов,
-- однако существенная часть GMV сосредоточена
-- среди крупнейших участников маркетплейса.
--
--
-- ОБЩИЙ ВЫВОД
--
-- Основной объём бизнеса Olist концентрируется
-- в нескольких крупных товарных категориях и регионах,
-- при этом продавцы представлены значительно более широким составом.
--
-- Одной из наиболее заметных закономерностей проекта является
-- связь качества доставки с клиентскими оценками:
-- задержанные заказы получают существенно менее благоприятные отзывы.
--
-- Повторные покупки встречаются редко,
-- что является отдельным направлением для дальнейшего исследования.
--
-- Полученные результаты описывают исторические закономерности
-- и не интерпретируются как доказательство причинно-следственных связей.
-- =========================================================