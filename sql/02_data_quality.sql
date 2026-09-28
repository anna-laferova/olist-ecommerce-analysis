-- =========================================================
-- 02_data_quality.sql
-- Data Quality Check — Olist E-commerce Dataset
-- =========================================================
--
-- Цель:
-- проверить полноту, уникальность, логическую согласованность
-- и качество данных перед аналитическим этапом проекта.
--
-- Период заказов:
-- 2016-09-04 — 2018-10-17
-- =========================================================

-- 1. ПРОВЕРКА КОЛИЧЕСТВА СТРОК ВО ВСЕХ ТАБЛИЦАХ
SELECT
    (SELECT COUNT(*) FROM public.geolocation) AS geolocation,
    (SELECT COUNT(*) FROM public.orders) AS orders,
    (SELECT COUNT(*) FROM public.order_items) AS order_items,
    (SELECT COUNT(*) FROM public.order_reviews) AS order_reviews,
    (SELECT COUNT(*) FROM public.customers) AS customers,
    (SELECT COUNT(*) FROM public.order_payments) AS order_payments,
    (SELECT COUNT(*) FROM public.products) AS products,
    (SELECT COUNT(*) FROM public.sellers) AS sellers,
    (SELECT COUNT(*) FROM public.category_translation) AS category_translation;
-- Все 9 таблиц заполнены.
-- Количество строк соответствует ожидаемому объёму импортированных CSV.

-- 2. УНИКАЛЬНОСТЬ КЛЮЧЕЙ

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_order_id
FROM public.orders;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customer_id
FROM public.customers;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS unique_product_id
FROM public.products;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT seller_id) AS unique_seller_id
FROM public.sellers;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (order_id, order_item_id)) AS unique_order_items
FROM public.order_items;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (order_id, payment_sequential)) AS unique_payments
FROM public.order_payments;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT review_id) AS unique_review_id,
    COUNT(DISTINCT order_id) AS unique_order_id
FROM public.order_reviews;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (review_id, order_id)) AS unique_review_order
FROM public.order_reviews;
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_category_name) AS unique_category_name
FROM public.category_translation;
-- Основные идентификаторы и составные ключи уникальны.
-- В order_reviews отдельно review_id и order_id могут повторяться,
-- но комбинация review_id + order_id уникальна.


-- 3. СВЯЗИ МЕЖДУ ТАБЛИЦАМИ


SELECT COUNT(*) AS order_items_without_order
FROM public.order_items oi
LEFT JOIN public.orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
SELECT COUNT(*) AS missing_customers
FROM public.orders o
LEFT JOIN public.customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
SELECT COUNT(*) AS payments_without_order
FROM public.order_payments op
LEFT JOIN public.orders o
    ON op.order_id = o.order_id
WHERE o.order_id IS NULL;
SELECT COUNT(*) AS reviews_without_order
FROM public.order_reviews r
LEFT JOIN public.orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
SELECT COUNT(*) AS missing_products
FROM public.order_items oi
LEFT JOIN public.products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;
SELECT COUNT(*) AS missing_sellers
FROM public.order_items oi
LEFT JOIN public.sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;
SELECT COUNT(*) AS products_without_translation
FROM public.products p
LEFT JOIN public.category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;
SELECT
    p.product_category_name,
    COUNT(*) AS product_count
FROM public.products p
LEFT JOIN public.category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY product_count DESC;

-- Нарушений основных связей между таблицами не обнаружено.
-- Все заказы, товары, продавцы и клиенты имеют соответствующие записи
-- в связанных таблицах.
--
-- Исключение: у 13 товаров категория отсутствует в таблице переводов:
-- portateis_cozinha_e_preparadores_de_alimentos — 10 товаров,
-- pc_gamer — 3 товара.
-- При аналитике категорий используем исходное название как fallback.

-- 4. ПРОПУЩЕННЫЕ ЗНАЧЕНИЯ
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_id,
    COUNT(*) FILTER (WHERE order_status IS NULL) AS null_order_status,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS null_purchase_date,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS null_approved_at,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS null_carrier_date,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS null_customer_delivery,
    COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) AS null_estimated_delivery
FROM public.orders;
SELECT
    order_status,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS null_approved_at,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS null_carrier_date,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS null_customer_delivery
FROM public.orders
GROUP BY order_status
ORDER BY total_orders DESC;
SELECT
    COUNT(*) AS delivered_orders_with_missing_dates
FROM public.orders
WHERE order_status = 'delivered'
  AND (
      order_approved_at IS NULL
      OR order_delivered_carrier_date IS NULL
      OR order_delivered_customer_date IS NULL
  );
-- Обнаружены 23 заказа со статусом delivered,
-- у которых отсутствует хотя бы одна дата этапа заказа.
-- Значения не исправляем: считаем пропусками исходного датасета.
-- При расчётах сроков доставки будем исключать строки,
-- где необходимые даты равны NULL.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS null_category,
    COUNT(*) FILTER (WHERE product_name_lenght IS NULL) AS null_name_length,
    COUNT(*) FILTER (WHERE product_description_lenght IS NULL) AS null_description_length,
    COUNT(*) FILTER (WHERE product_photos_qty IS NULL) AS null_photos_qty,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL) AS null_weight,
    COUNT(*) FILTER (WHERE product_length_cm IS NULL) AS null_length,
    COUNT(*) FILTER (WHERE product_height_cm IS NULL) AS null_height,
    COUNT(*) FILTER (WHERE product_width_cm IS NULL) AS null_width
FROM public.products;
SELECT COUNT(*) AS rows_with_all_main_product_nulls
FROM public.products
WHERE product_category_name IS NULL
  AND product_name_lenght IS NULL
  AND product_description_lenght IS NULL
  AND product_photos_qty IS NULL;
-- 610 товаров не имеют основной описательной информации:
-- категории, длины названия, длины описания и количества фото.
-- product_id при этом заполнен.
SELECT
    p.product_id,
    p.product_category_name,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    COUNT(oi.order_id) AS order_item_rows,
    COUNT(DISTINCT oi.order_id) AS orders_count
FROM public.products p
LEFT JOIN public.order_items oi
    ON p.product_id = oi.product_id
WHERE p.product_weight_g IS NULL
   OR p.product_length_cm IS NULL
   OR p.product_height_cm IS NULL
   OR p.product_width_cm IS NULL
GROUP BY
    p.product_id,
    p.product_category_name,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
ORDER BY order_item_rows DESC;
-- У 2 товаров отсутствуют вес и все габариты.
-- Оба товара участвовали в продажах.
-- Из анализа продаж их не исключаем.
-- В анализе физических характеристик учитываем NULL отдельно.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE order_item_id IS NULL) AS null_order_item_id,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE seller_id IS NULL) AS null_seller_id,
    COUNT(*) FILTER (WHERE shipping_limit_date IS NULL) AS null_shipping_limit_date,
    COUNT(*) FILTER (WHERE price IS NULL) AS null_price,
    COUNT(*) FILTER (WHERE freight_value IS NULL) AS null_freight_value
FROM public.order_items;
-- В order_items пропусков в проверяемых полях не обнаружено.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE payment_sequential IS NULL) AS null_payment_sequential,
    COUNT(*) FILTER (WHERE payment_type IS NULL) AS null_payment_type,
    COUNT(*) FILTER (WHERE payment_installments IS NULL) AS null_installments,
    COUNT(*) FILTER (WHERE payment_value IS NULL) AS null_payment_value
FROM public.order_payments;
-- В order_payments пропусков в проверяемых полях не обнаружено.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_id,
    COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS null_customer_unique_id,
    COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL) AS null_zip_code,
    COUNT(*) FILTER (WHERE customer_city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE customer_state IS NULL) AS null_state
FROM public.customers;
-- В customers пропусков в проверяемых полях не обнаружено.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE seller_id IS NULL) AS null_seller_id,
    COUNT(*) FILTER (WHERE seller_zip_code_prefix IS NULL) AS null_zip_code,
    COUNT(*) FILTER (WHERE seller_city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE seller_state IS NULL) AS null_state
FROM public.sellers;
-- В sellers пропусков в проверяемых полях не обнаружено.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE review_id IS NULL) AS null_review_id,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE review_score IS NULL) AS null_review_score,
    COUNT(*) FILTER (WHERE review_comment_title IS NULL) AS null_comment_title,
    COUNT(*) FILTER (WHERE review_comment_message IS NULL) AS null_comment_message,
    COUNT(*) FILTER (WHERE review_creation_date IS NULL) AS null_creation_date,
    COUNT(*) FILTER (WHERE review_answer_timestamp IS NULL) AS null_answer_timestamp
FROM public.order_reviews;
-- В order_reviews обязательные поля заполнены полностью.
-- NULL встречаются только в необязательных текстовых полях:
-- 87 656 отзывов без заголовка и 58 247 без текста комментария.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS null_category_name,
    COUNT(*) FILTER (WHERE product_category_name_english IS NULL) AS null_english_name
FROM public.category_translation;
-- В category_translation пропусков не обнаружено.
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE geolocation_zip_code_prefix IS NULL) AS null_zip_code,
    COUNT(*) FILTER (WHERE geolocation_lat IS NULL) AS null_lat,
    COUNT(*) FILTER (WHERE geolocation_lng IS NULL) AS null_lng,
    COUNT(*) FILTER (WHERE geolocation_city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE geolocation_state IS NULL) AS null_state
FROM public.geolocation;
-- В geolocation пропусков не обнаружено.

-- 5. КОРРЕКТНОСТЬ ЧИСЛОВЫХ ЗНАЧЕНИЙ
SELECT
    COUNT(*) FILTER (WHERE price <= 0) AS invalid_price,
    COUNT(*) FILTER (WHERE freight_value < 0) AS invalid_freight
FROM public.order_items;
-- В order_items некорректных цен и отрицательной стоимости доставки не обнаружено.
SELECT
    COUNT(*) FILTER (WHERE payment_value < 0) AS invalid_payment_value,
    COUNT(*) FILTER (WHERE payment_installments < 0) AS invalid_installments
FROM public.order_payments;
-- В order_payments отрицательных сумм платежей
-- и отрицательного количества рассрочек не обнаружено.
SELECT
    COUNT(*) FILTER (WHERE payment_value = 0) AS zero_payment_value,
    COUNT(*) FILTER (WHERE payment_installments = 0) AS zero_installments
FROM public.order_payments;
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM public.order_payments
WHERE payment_value = 0
   OR payment_installments = 0
ORDER BY order_id, payment_sequential;
-- Обнаружено 9 платежных строк с payment_value = 0
-- и 2 платежа credit_card с payment_installments = 0.
-- Значения не исправляем вручную; проверяем их в контексте заказа.
WITH suspicious_orders AS (
    SELECT DISTINCT order_id
    FROM public.order_payments
    WHERE payment_value = 0
       OR payment_installments = 0
),
payment_summary AS (
    SELECT
        op.order_id,
        COUNT(*) AS payment_rows,
        SUM(op.payment_value) AS total_payment,
        COUNT(*) FILTER (WHERE op.payment_value = 0) AS zero_payment_rows,
        COUNT(*) FILTER (WHERE op.payment_installments = 0) AS zero_installment_rows
    FROM public.order_payments op
    JOIN suspicious_orders s
        ON op.order_id = s.order_id
    GROUP BY op.order_id
),
item_summary AS (
    SELECT
        oi.order_id,
        COUNT(*) AS item_rows,
        SUM(oi.price + oi.freight_value) AS order_total
    FROM public.order_items oi
    JOIN suspicious_orders s
        ON oi.order_id = s.order_id
    GROUP BY oi.order_id
)
SELECT
    o.order_id,
    o.order_status,
    p.payment_rows,
    p.total_payment,
    p.zero_payment_rows,
    p.zero_installment_rows,
    COALESCE(i.item_rows, 0) AS item_rows,
    i.order_total,
    o.order_approved_at,
    o.order_delivered_customer_date
FROM suspicious_orders s
JOIN public.orders o
    ON s.order_id = o.order_id
JOIN payment_summary p
    ON s.order_id = p.order_id
LEFT JOIN item_summary i
    ON s.order_id = i.order_id
ORDER BY o.order_id;
-- Обнаружено 9 платежных строк с payment_value = 0
-- и 2 строки с payment_installments = 0.
--
-- Три заказа с общей суммой платежей 0.00 имеют статус canceled,
-- не содержат позиций в order_items и не имеют подтверждения оплаты.
-- Такие нулевые платежи считаем допустимой особенностью отменённых заказов,
-- а не ошибкой данных.
-- Значения вручную не исправляем.
SELECT
    o.order_status,
    COUNT(*) AS orders_without_items
FROM public.orders o
LEFT JOIN public.order_items oi
    ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY orders_without_items DESC;
-- Обнаружено 775 заказов без строк в order_items.
-- Большинство имеют статусы unavailable или canceled.
-- Один заказ имеет статус shipped и требует отдельной проверки.
WITH payment_summary AS (
    SELECT
        order_id,
        COUNT(*) AS payment_rows,
        SUM(payment_value) AS total_payment
    FROM public.order_payments
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    COALESCE(p.payment_rows, 0) AS payment_rows,
    p.total_payment
FROM public.orders o
LEFT JOIN payment_summary p
    ON o.order_id = p.order_id
WHERE o.order_status = 'shipped'
  AND NOT EXISTS (
      SELECT 1
      FROM public.order_items oi
      WHERE oi.order_id = o.order_id
  );
-- Среди заказов без order_items обнаружен 1 заказ
-- со статусом shipped.
-- Он подтвержден, передан перевозчику и имеет платеж 77.73,
-- но товарные позиции в order_items отсутствуют.
-- Считаем это неполнотой исходных данных.
-- Значения вручную не восстанавливаем.
SELECT
    COUNT(*) FILTER (
        WHERE review_score NOT BETWEEN 1 AND 5
           OR review_score IS NULL
    ) AS invalid_review_score
FROM public.order_reviews;
-- Все значения review_score находятся в допустимом диапазоне от 1 до 5.
SELECT
    COUNT(*) FILTER (
        WHERE product_weight_g <= 0
          AND product_weight_g IS NOT NULL
    ) AS invalid_weight,

    COUNT(*) FILTER (
        WHERE product_length_cm <= 0
          AND product_length_cm IS NOT NULL
    ) AS invalid_length,

    COUNT(*) FILTER (
        WHERE product_height_cm <= 0
          AND product_height_cm IS NOT NULL
    ) AS invalid_height,

    COUNT(*) FILTER (
        WHERE product_width_cm <= 0
          AND product_width_cm IS NOT NULL
    ) AS invalid_width
FROM public.products;
SELECT
    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM public.products
WHERE product_weight_g <= 0;
-- Обнаружено 4 товара с product_weight_g = 0.
-- Остальные габариты заполнены.
-- Значения считаем аномалией исходного датасета
-- и не исправляем вручную.
SELECT
    p.product_id,
    COUNT(oi.order_id) AS order_count
FROM public.products p
LEFT JOIN public.order_items oi
    ON p.product_id = oi.product_id
WHERE p.product_weight_g = 0
GROUP BY p.product_id
ORDER BY order_count DESC;
-- Все 4 товара с нулевым весом участвовали в продажах
-- (всего 8 позиций заказа).
-- Из анализа продаж их не исключаем.
-- В анализе веса и логистики product_weight_g = 0 считаем некорректным значением.
SELECT
    COUNT(*) FILTER (WHERE product_photos_qty < 0) AS invalid_photos_qty,
    COUNT(*) FILTER (WHERE product_name_lenght < 0) AS invalid_name_length,
    COUNT(*) FILTER (WHERE product_description_lenght < 0) AS invalid_description_length
FROM public.products;
-- Некорректных отрицательных значений в количестве фото
-- и длинах текстовых полей products не обнаружено.
SELECT
    COUNT(*) FILTER (
        WHERE geolocation_lat < -90
           OR geolocation_lat > 90
    ) AS invalid_lat,

    COUNT(*) FILTER (
        WHERE geolocation_lng < -180
           OR geolocation_lng > 180
    ) AS invalid_lng
FROM public.geolocation;
-- Все географические координаты находятся в допустимых диапазонах.

-- 6. ЛОГИКА ДАТ
SELECT COUNT(*) FILTER (WHERE order_approved_at < order_purchase_timestamp) AS approved_before_purchase, COUNT(*) FILTER (WHERE order_delivered_carrier_date < order_purchase_timestamp) AS carrier_before_purchase, COUNT(*) FILTER (WHERE order_delivered_customer_date < order_purchase_timestamp) AS delivered_before_purchase, COUNT(*) FILTER (WHERE order_estimated_delivery_date < order_purchase_timestamp) AS estimated_before_purchase FROM public.orders;
-- Обнаружено 166 заказов, где дата передачи перевозчику
-- раньше даты покупки. В большинстве случаев разница небольшая
-- и события приходятся на один день.
-- Считаем это аномалией временных меток исходного датасета.
-- Значения вручную не исправляем.
SELECT COUNT(*) AS anomalous_orders, MIN(order_purchase_timestamp - order_delivered_carrier_date) AS min_difference, MAX(order_purchase_timestamp - order_delivered_carrier_date) AS max_difference, AVG(order_purchase_timestamp - order_delivered_carrier_date) AS avg_difference FROM public.orders WHERE order_delivered_carrier_date < order_purchase_timestamp;
SELECT
    COUNT(*) FILTER (
        WHERE order_purchase_timestamp - order_delivered_carrier_date <= INTERVAL '1 hour'
    ) AS up_to_1_hour,

    COUNT(*) FILTER (
        WHERE order_purchase_timestamp - order_delivered_carrier_date > INTERVAL '1 hour'
          AND order_purchase_timestamp - order_delivered_carrier_date <= INTERVAL '1 day'
    ) AS from_1_hour_to_1_day,

    COUNT(*) FILTER (
        WHERE order_purchase_timestamp - order_delivered_carrier_date > INTERVAL '1 day'
    ) AS over_1_day
FROM public.orders
WHERE order_delivered_carrier_date < order_purchase_timestamp;
-- Из 166 случаев, где дата передачи перевозчику раньше даты покупки:
-- 121 случай имеет расхождение до 1 часа,
-- 43 случая — от 1 часа до 1 суток,
-- 2 случая — более 1 суток.
-- Самый крупный выброс составляет около 171 дня.
-- Считаем эти значения аномалиями временных меток исходного датасета.
-- Заказы не удаляем; при анализе сроков доставки такие строки
-- необходимо учитывать отдельно.
SELECT COUNT(*) AS delivered_before_carrier FROM public.orders WHERE order_delivered_customer_date < order_delivered_carrier_date;
SELECT
    MIN(order_delivered_carrier_date - order_delivered_customer_date) AS min_difference,
    MAX(order_delivered_carrier_date - order_delivered_customer_date) AS max_difference,
    AVG(order_delivered_carrier_date - order_delivered_customer_date) AS avg_difference
FROM public.orders
WHERE order_delivered_customer_date < order_delivered_carrier_date;
-- Обнаружено 23 заказа,
-- где order_delivered_customer_date раньше order_delivered_carrier_date.
-- Разница составляет от нескольких минут до 16 дней.
-- Это логически невозможная последовательность событий.
-- Считаем данные аномалией исходного датасета и не исправляем вручную.
SELECT COUNT(*) AS carrier_before_approved FROM public.orders WHERE order_delivered_carrier_date < order_approved_at;
SELECT COUNT(*) AS anomalous_orders, MIN(order_approved_at - order_delivered_carrier_date) AS min_difference, MAX(order_approved_at - order_delivered_carrier_date) AS max_difference, AVG(order_approved_at - order_delivered_carrier_date) AS avg_difference FROM public.orders WHERE order_delivered_carrier_date < order_approved_at;
SELECT
    COUNT(*) FILTER (
        WHERE order_approved_at - order_delivered_carrier_date <= INTERVAL '1 hour'
    ) AS up_to_1_hour,

    COUNT(*) FILTER (
        WHERE order_approved_at - order_delivered_carrier_date > INTERVAL '1 hour'
          AND order_approved_at - order_delivered_carrier_date <= INTERVAL '1 day'
    ) AS from_1_hour_to_1_day,

    COUNT(*) FILTER (
        WHERE order_approved_at - order_delivered_carrier_date > INTERVAL '1 day'
    ) AS over_1_day
FROM public.orders
WHERE order_delivered_carrier_date < order_approved_at;
-- В 1 359 заказах дата передачи перевозчику раньше order_approved_at:
-- 242 случая — до 1 часа,
-- 659 случаев — от 1 часа до 1 суток,
-- 458 случаев — более 1 суток.

SELECT COUNT(*) AS answer_before_creation FROM public.order_reviews WHERE review_answer_timestamp < review_creation_date;
-- В order_reviews нарушений последовательности дат не обнаружено:
-- review_answer_timestamp всегда не раньше review_creation_date.
SELECT COUNT(*) AS late_deliveries
FROM public.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND order_delivered_customer_date > order_estimated_delivery_date;
-- 7 826 доставленных заказов были доставлены позже
-- ожидаемой даты доставки.
-- Это не ошибка данных, а бизнес-показатель качества доставки.
SELECT COUNT(*) AS shipping_limit_before_purchase
FROM public.order_items oi
JOIN public.orders o
    ON oi.order_id = o.order_id
WHERE oi.shipping_limit_date < o.order_purchase_timestamp;
-- Случаев, где shipping_limit_date раньше даты покупки, не обнаружено.
    
-- 7. БИЗНЕС-СОГЛАСОВАННОСТЬ ДАННЫХ
SELECT
    o.order_status,
    COUNT(*) AS orders_without_payment
FROM public.orders o
LEFT JOIN public.order_payments op
    ON o.order_id = op.order_id
WHERE op.order_id IS NULL
GROUP BY o.order_status
ORDER BY orders_without_payment DESC;
WITH item_summary AS (
    SELECT
        order_id,
        COUNT(*) AS item_rows,
        SUM(price) AS items_price,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS order_total
    FROM public.order_items
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    COALESCE(i.item_rows, 0) AS item_rows,
    i.items_price,
    i.freight_value,
    i.order_total
FROM public.orders o
LEFT JOIN public.order_payments op
    ON o.order_id = op.order_id
LEFT JOIN item_summary i
    ON o.order_id = i.order_id
WHERE op.order_id IS NULL;
-- Обнаружен 1 доставленный заказ без записи в order_payments.
-- Заказ содержит 3 товарные позиции общей стоимостью 143.46
-- с учетом доставки.
-- Считаем это неполнотой платежных данных исходного датасета.
-- Значения вручную не восстанавливаем.
WITH item_totals AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS order_total
    FROM public.order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM public.order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*) AS compared_orders,
    COUNT(*) FILTER (
        WHERE ABS(i.order_total - p.payment_total) > 0.01
    ) AS mismatched_orders
FROM item_totals i
JOIN payment_totals p
    ON i.order_id = p.order_id;

WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS order_total
    FROM public.order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS payment_total
    FROM public.order_payments
    GROUP BY order_id
)
SELECT
    o.order_status,
    COUNT(*) AS mismatched_orders,
    COUNT(*) FILTER (WHERE p.payment_total > i.order_total) AS payment_higher,
    COUNT(*) FILTER (WHERE p.payment_total < i.order_total) AS payment_lower
FROM item_totals i
JOIN payment_totals p ON i.order_id = p.order_id
JOIN public.orders o ON i.order_id = o.order_id
WHERE ABS(i.order_total - p.payment_total) > 0.01
GROUP BY o.order_status
ORDER BY mismatched_orders DESC;
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS order_total
    FROM public.order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total,
        COUNT(*) AS payment_rows,
        COUNT(DISTINCT payment_type) AS payment_types
    FROM public.order_payments
    GROUP BY order_id
)
SELECT
    COUNT(*) FILTER (WHERE p.payment_rows = 1) AS single_payment_row,
    COUNT(*) FILTER (WHERE p.payment_rows > 1) AS multiple_payment_rows,
    COUNT(*) FILTER (WHERE p.payment_types = 1) AS single_payment_type,
    COUNT(*) FILTER (WHERE p.payment_types > 1) AS multiple_payment_types
FROM item_totals i
JOIN payment_totals p
    ON i.order_id = p.order_id
WHERE ABS(i.order_total - p.payment_total) > 0.01;
-- Большинство расхождений не связано с несколькими платежами:
-- 286 из 303 заказов имеют только одну платежную строку,
-- 296 из 303 используют только один тип оплаты.
-- Следовательно, структура multi-payment не объясняет основную часть расхождений.

WITH item_totals AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS order_total
    FROM public.order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total,
        COUNT(*) AS payment_rows,
        MIN(payment_type) AS payment_type,
        MAX(payment_installments) AS installments
    FROM public.order_payments
    GROUP BY order_id
)
SELECT
    p.installments,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE ABS(p.payment_total - i.order_total) > 0.01
    ) AS mismatched_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE ABS(p.payment_total - i.order_total) > 0.01
        ) / COUNT(*),
        2
    ) AS mismatch_percent,
    ROUND(
        AVG(p.payment_total - i.order_total),
        2
    ) AS avg_difference
FROM item_totals i
JOIN payment_totals p
    ON i.order_id = p.order_id
WHERE p.payment_rows = 1
  AND p.payment_type = 'credit_card'
GROUP BY p.installments
ORDER BY p.installments;
-- Из 98 665 заказов, для которых доступны и товарные позиции,
-- и платежи, у 303 заказов (~0.31%) сумма платежей отличается
-- от суммы price + freight_value.
--
-- Проверка заказов с одной оплатой credit_card показала,
-- что для массовых вариантов рассрочки доля таких расхождений
-- в основном составляет менее 1%, а средняя разница по всем
-- заказам близка к нулю.
--
-- Поэтому систематическая надбавка за рассрочку не подтверждается.
-- Расхождения считаем редкими особенностями/несогласованностями
-- исходных данных или финансовыми корректировками,
-- механизм которых в датасете не представлен.
-- Значения вручную не исправляем.

-- 8. ГЕОГРАФИЯ И ДУБЛИ

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    )) AS unique_rows
FROM public.geolocation;

-- В geolocation присутствуют полностью повторяющиеся строки.
-- Исходную таблицу не изменяем.
-- При дальнейшем анализе географии нельзя напрямую JOIN-ить
-- сырую geolocation по zip_code_prefix:
-- повторяющиеся строки могут размножить строки аналитической выборки
-- и исказить агрегированные показатели.

SELECT
    COUNT(*) AS duplicate_groups,
    SUM(row_count - 1) AS repeated_rows,
    MAX(row_count) AS max_repeats
FROM (
    SELECT
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state,
        COUNT(*) AS row_count
    FROM public.geolocation
    GROUP BY
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    HAVING COUNT(*) > 1
) d;
-- В geolocation обнаружено 128 197 групп полностью одинаковых строк.
-- Всего 262 010 записей повторяют уже существующую комбинацию
-- zip_code_prefix + lat + lng + city + state.
-- Максимальное количество повторений одной комбинации — 314.
--
-- Повторы не удаляем из исходной таблицы.
-- При дальнейших JOIN по zip_code_prefix необходимо использовать
-- предварительно агрегированную или дедуплицированную geolocation,
-- чтобы не размножать строки заказов и не искажать метрики.
SELECT COUNT(*) AS customers_without_geolocation
FROM public.customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM public.geolocation g
    WHERE g.geolocation_zip_code_prefix = c.customer_zip_code_prefix
);
-- У 278 клиентов zip_code_prefix отсутствует в geolocation.
-- Город и штат при этом остаются доступны из customers,
-- но координаты для таких клиентов получить нельзя.
SELECT COUNT(*) AS sellers_without_geolocation
FROM public.sellers s
WHERE NOT EXISTS (
    SELECT 1
    FROM public.geolocation g
    WHERE g.geolocation_zip_code_prefix = s.seller_zip_code_prefix
);
-- У 7 продавцов zip_code_prefix отсутствует в geolocation.
-- Географические координаты для них получить нельзя,
-- но seller_city и seller_state остаются доступны из sellers.

-- 9. ПОКРЫТИЕ И ПЕРИОД ДАННЫХ

SELECT
    o.order_status,
    COUNT(*) AS orders_without_review
FROM public.orders o
WHERE NOT EXISTS (
    SELECT 1
    FROM public.order_reviews r
    WHERE r.order_id = o.order_id
)
GROUP BY o.order_status
ORDER BY orders_without_review DESC;
-- 768 заказов не имеют отзыва.
-- Из них 646 имеют статус delivered (~0.67% всех доставленных заказов).
-- Отсутствие отзыва не считаем ошибкой данных:
-- клиент мог просто не оставить оценку.
-- При анализе отзывов такие заказы не будут представлены.
SELECT
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order
FROM public.orders;
-- Период данных по заказам:
-- с 2016-09-04 по 2018-10-17.
-- Сентябрь 2016 и октябрь 2018 представлены неполными месяцами.
-- При анализе месячной динамики крайние месяцы необходимо
-- интерпретировать отдельно и не сравнивать напрямую с полными месяцами.
-- =========================================================
-- ИТОГОВЫЕ ВЫВОДЫ ПО КАЧЕСТВУ ДАННЫХ
-- =========================================================
-- 1. Основные идентификаторы и составные ключи корректны.
-- Нарушений основных связей между таблицами не обнаружено.
-- У 13 товаров отсутствует английский перевод категории.
--
-- 2. В products присутствуют пропуски:
-- 610 товаров не имеют основной описательной информации,
-- у 2 товаров отсутствуют вес и габариты.
-- Также обнаружено 4 товара с нулевым весом.
--
-- 3. В orders обнаружены отдельные пропуски и аномалии временных меток.
-- В частности, 23 доставленных заказа имеют пропущенные даты этапов.
-- Аномальные последовательности дат не исправляются вручную
-- и должны учитываться при анализе сроков доставки.
--
-- 4. Обнаружены редкие нарушения бизнес-согласованности:
-- 775 заказов не имеют строк в order_items;
-- среди них есть 1 заказ со статусом shipped.
-- Также обнаружен 1 доставленный заказ без записи в order_payments.
--
-- 5. Для 303 из 98 665 сопоставимых заказов (~0.31%)
-- сумма платежей отличается от суммы price + freight_value.
-- Систематическая связь этих расхождений с рассрочкой не подтверждена.
-- Исходные значения не исправляются.
--
-- 6. В geolocation присутствует большое количество повторяющихся строк.
-- Для географического анализа необходимо предварительно
-- агрегировать или дедуплицировать geolocation перед JOIN.
-- Для 278 клиентов и 7 продавцов координаты по zip_code_prefix отсутствуют.
--
-- 7. 768 заказов не имеют отзывов, из них 646 доставлены.
-- Отсутствие отзыва не считается ошибкой данных.
--
-- 8. Период заказов охватывает 2016-09-04 — 2018-10-17.
-- Сентябрь 2016 и октябрь 2018 являются неполными месяцами
-- и требуют отдельной интерпретации при анализе динамики.
--
-- Данные в целом пригодны для дальнейшего анализа.
-- Обнаруженные особенности будут учитываться
-- в зависимости от конкретной аналитической задачи.
-- =========================================================
