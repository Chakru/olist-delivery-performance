/*
============================================================
Project: Olist E-Commerce Data Warehouse

Layer: Data Preparation & Feature Engineering (Part III)

File: 02_data_preparation.sql

Description:
This script transforms cleaned core layer data into a 
fully engineered analytical dataset.

Key objectives:
1. Consolidate order-level data
2. Aggregate item-level data to order grain
3. Engineer delivery and delay features
4. Enrich with geolocation data
5. Estimate distance between customer and seller
6. Create customer behaviour metrics

Final Output:
- analytics.facts_orders_final (1 row per order_id)

Execution Order:
Run sequentially from top to bottom

Dependencies:
- Core layer tables must be available
- analytics.zip_geolocation_reference must exist

Important Notes:
- Final grain = 1 row per order_id
- Payment joins may introduce duplication (handled downstream)
- Distance is an approximation (not real-world km)
============================================================
*/


/* ============================================================
   SECTION 1: REVIEW AGGREGATION
   - Aggregate review scores at order level
   - Grain: 1 row per order_id
============================================================ */

CREATE OR ALTER VIEW analytics.review_agg AS
SELECT
    order_id,
    AVG(review_score) AS avg_review_score
FROM core.order_reviews
GROUP BY order_id;
GO


/* ============================================================
   SECTION 2: BASE ORDERS TABLE
   - Join orders, customers, reviews, payments
   - Intermediate layer before deduplication
============================================================ */

CREATE OR ALTER VIEW analytics.base_orders AS
SELECT 
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,

    r.avg_review_score,

    p.payment_type,
    p.payment_value

FROM core.orders o

LEFT JOIN core.dim_customers c 
    ON o.customer_id = c.customer_id

LEFT JOIN analytics.review_agg r
    ON o.order_id = r.order_id

LEFT JOIN core.order_payments p
    ON o.order_id = p.order_id;
GO


/* Data Quality Checks:
   - Detect duplication due to payment joins
   - Validate order coverage
*/

SELECT COUNT(*) AS [Total Rows] FROM analytics.base_orders;
GO


SELECT COUNT(DISTINCT order_id) AS [Distinct Orders] 
FROM analytics.base_orders;
GO


SELECT 
    order_id,
    COUNT(*) AS [Duplicate Count]
FROM analytics.base_orders
GROUP BY order_id
HAVING COUNT(*) > 1;
GO


/* ============================================================
   SECTION 3: ORDER ITEM AGGREGATION
   - Convert item-level data → order-level
============================================================ */

CREATE OR ALTER VIEW analytics.order_item_agg AS
SELECT 
    order_id,
    SUM(price) AS total_order_value,
    SUM(freight_value) AS total_freight_value,
    COUNT(DISTINCT seller_id) AS seller_count
FROM core.order_items
GROUP BY order_id;
GO


/* Data Quality Checks:
   - Ensure 1 row per order_id after aggregation
*/

SELECT COUNT(*) [Total Rows] FROM analytics.order_item_agg;
GO


SELECT COUNT(DISTINCT order_id) [Total Rows] FROM core.order_items;
GO


/* ============================================================
   SECTION 4: FACT TABLE (ORDER LEVEL)
   - Deduplicate and create analytical base
============================================================ */

CREATE OR ALTER VIEW analytics.fact_orders_master AS
WITH deduplicated_base_orders AS (
    SELECT DISTINCT
        order_id,
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        avg_review_score
    FROM analytics.base_orders
)
SELECT 
    b.*,
    oi.total_order_value,
    oi.total_freight_value,
    oi.seller_count
FROM deduplicated_base_orders b
LEFT JOIN analytics.order_item_agg oi
    ON b.order_id = oi.order_id;
GO


/* ============================================================
   SECTION 5: DELIVERY FEATURE ENGINEERING
   - Create delivery time and delay metrics
============================================================ */

CREATE OR ALTER VIEW analytics.fact_orders_enriched AS
SELECT
    *,

    -- Actual delivery time (only valid for delivered orders)
    CASE 
        WHEN order_status = 'delivered' 
             AND order_delivered_customer_date IS NOT NULL
        THEN DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)
        ELSE NULL
    END AS actual_delivery_days,

    -- Estimated delivery time
    DATEDIFF(DAY, order_purchase_timestamp, order_estimated_delivery_date) 
        AS estimated_delivery_days,

    -- Delay calculation
    CASE 
        WHEN order_status = 'delivered' 
             AND order_delivered_customer_date IS NOT NULL
        THEN DATEDIFF(DAY, order_estimated_delivery_date, order_delivered_customer_date)
        ELSE NULL
    END AS delay_days,

    -- Delay flag
    CASE 
        WHEN order_status = 'delivered' 
             AND order_delivered_customer_date IS NOT NULL
             AND DATEDIFF(DAY, order_estimated_delivery_date, order_delivered_customer_date) > 0
        THEN 1
        ELSE 0
    END AS is_delayed,

    -- Delay category
    CASE 
        WHEN order_status != 'delivered' THEN NULL
        WHEN DATEDIFF(DAY, order_estimated_delivery_date, order_delivered_customer_date) < 0 THEN 'Early'
        WHEN DATEDIFF(DAY, order_estimated_delivery_date, order_delivered_customer_date) = 0 THEN 'On-time'
        ELSE 'Late'
    END AS delivery_status_category

FROM analytics.fact_orders_master;
GO


/* ============================================================
   SECTION 6: CUSTOMER GEO ENRICHMENT
   - Attach customer latitude & longitude
============================================================ */

CREATE OR ALTER VIEW analytics.fact_orders_geo_stage1 AS
SELECT
    f.*,
    g.Avg_Lat AS customer_latitude,
    g.Avg_Long AS customer_longitude 
FROM analytics.fact_orders_enriched f
LEFT JOIN analytics.zip_geolocation_reference g
    ON f.customer_zip_code_prefix = g.Zip_Code;
GO


/* ============================================================
   SECTION 7: SELLER GEO AGGREGATION
   - Aggregate seller locations at order level
============================================================ */

CREATE OR ALTER VIEW analytics.order_seller_geo_agg AS
SELECT
    oi.order_id,
    AVG(sg.Avg_Lat) AS seller_latitude,
    AVG(sg.Avg_Long) AS seller_longitude
FROM core.order_items oi
LEFT JOIN analytics.seller_geo sg
    ON oi.seller_id = sg.seller_id
GROUP BY oi.order_id;
GO


/* ============================================================
   SECTION 8: DISTANCE CALCULATION
   - Approximate customer ↔ seller distance
============================================================ */

CREATE OR ALTER VIEW analytics.fact_order_with_distance AS
SELECT
    og.*,
    sg.seller_latitude,
    sg.seller_longitude,

    -- Euclidean distance (approximation)
    CASE 
        WHEN og.customer_latitude IS NOT NULL 
         AND sg.seller_latitude IS NOT NULL
        THEN SQRT(
            POWER((og.customer_latitude - sg.seller_latitude), 2) +
            POWER((og.customer_longitude - sg.seller_longitude), 2)
        )
        ELSE NULL
    END AS distance

FROM analytics.fact_orders_geo_stage1 og
LEFT JOIN analytics.order_seller_geo_agg sg
    ON og.order_id = sg.order_id;
GO


/* ============================================================
   SECTION 9: DISTANCE BUCKETING
   - Segment orders by delivery distance
============================================================ */

CREATE OR ALTER VIEW analytics.fact_order_with_distance_bucket AS
SELECT 
    *,
    CASE
        WHEN distance IS NULL THEN NULL
        WHEN distance <= 5 THEN 'Very Short'
        WHEN distance <= 15 THEN 'Short'
        WHEN distance <= 30 THEN 'Medium'
        ELSE 'Long'
    END AS distance_bucket
FROM analytics.fact_order_with_distance;
GO


/* ============================================================
   SECTION 10: CUSTOMER METRICS
   - Identify repeat customers
============================================================ */

CREATE OR ALTER VIEW analytics.customer_order_metrics AS
SELECT 
    customer_unique_id,
    COUNT(order_id) AS total_orders
FROM analytics.fact_orders_master
GROUP BY customer_unique_id;
GO


/* ============================================================
   SECTION 11: FINAL DATASET
   - Ready for hypothesis testing & Power BI
============================================================ */

CREATE OR ALTER VIEW analytics.facts_orders_final AS
SELECT
    f.*,
    CASE 
        WHEN c.total_orders > 1 THEN 1
        ELSE 0
    END AS is_repeat_customer
FROM analytics.fact_order_with_distance_bucket f
LEFT JOIN analytics.customer_order_metrics c
    ON f.customer_unique_id = c.customer_unique_id;
GO


/*************************************************************
FINAL SUMMARY

- Final dataset grain: 1 row per order_id
- Includes:
    - Revenue metrics
    - Delivery performance
    - Delay classification
    - Distance segmentation
    - Customer repeat behaviour
*************************************************************/