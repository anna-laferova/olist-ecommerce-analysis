-- =========================================================
-- 04_powerbi_views.sql
-- Analytical Views for Power BI
-- =========================================================
--
-- Цель:
-- подготовить удобные аналитические представления
-- для построения модели и дашборда Power BI.
-- =========================================================
-- =========================================================
-- 1. ЗАКАЗЫ
-- 1 строка = 1 доставленный заказ
-- =========================================================

CREATE OR REPLACE VIEW public.vw_orders_analysis AS

WITH item_totals AS (
    SELECT
        order_id,
        COUNT(*) AS items_sold,
        SUM(price) AS gmv,
        SUM(freight_value) AS freight
    FROM public.order_items
    GROUP BY order_id
),

review_per_order AS (
    SELECT
        order_id,
        AVG(review_score::numeric) AS review_score
    FROM public.order_reviews
    GROUP BY order_id
),

customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS customer_order_count
    FROM public.orders o
    JOIN public.customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    o.order_id,

    c.customer_unique_id,
    c.customer_state,
    c.customer_city,

    o.order_purchase_timestamp,
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::date AS order_month,

    i.items_sold,
    i.gmv,
    i.freight,
    i.gmv + i.freight AS total_order_value,

    EXTRACT(
        EPOCH FROM (
            o.order_delivered_customer_date
            - o.order_purchase_timestamp
        )
    ) / 86400.0 AS delivery_days,

    o.order_estimated_delivery_date,
    o.order_delivered_customer_date,

    CASE
        WHEN o.order_delivered_customer_date IS NULL
          OR o.order_estimated_delivery_date IS NULL
            THEN NULL
        ELSE
            o.order_delivered_customer_date
            > o.order_estimated_delivery_date
    END AS is_late,

    r.review_score,

    co.customer_order_count,

    CASE
        WHEN co.customer_order_count >= 2
            THEN 'Repeat'
        ELSE 'One-time'
    END AS customer_type

FROM public.orders o

JOIN public.customers c
    ON o.customer_id = c.customer_id

JOIN item_totals i
    ON o.order_id = i.order_id

LEFT JOIN review_per_order r
    ON o.order_id = r.order_id

JOIN customer_orders co
    ON c.customer_unique_id = co.customer_unique_id

WHERE o.order_status = 'delivered';
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT customer_unique_id) AS customers,
    SUM(items_sold) AS items_sold,
    ROUND(SUM(gmv), 2) AS gmv,
    ROUND(SUM(freight), 2) AS freight,
    ROUND(AVG(gmv), 2) AS average_order_value
FROM public.vw_orders_analysis;
-- =========================================================
-- 2. ТОВАРНЫЕ ПОЗИЦИИ
-- 1 строка = 1 товарная позиция доставленного заказа
-- =========================================================

CREATE OR REPLACE VIEW public.vw_order_items_analysis AS

SELECT
    oi.order_id,
    oi.order_item_id,

    oi.product_id,
    oi.seller_id,

    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'unknown'
    ) AS category,

    oi.price,
    oi.freight_value

FROM public.order_items oi

JOIN public.orders o
    ON oi.order_id = o.order_id

JOIN public.products p
    ON oi.product_id = p.product_id

LEFT JOIN public.category_translation ct
    ON p.product_category_name = ct.product_category_name

WHERE o.order_status = 'delivered';
SELECT
    COUNT(*) AS rows,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT product_id) AS products,
    COUNT(DISTINCT seller_id) AS sellers,
    COUNT(DISTINCT category) AS categories,
    ROUND(SUM(price), 2) AS gmv,
    ROUND(SUM(freight_value), 2) AS freight
FROM public.vw_order_items_analysis;
SELECT current_user;