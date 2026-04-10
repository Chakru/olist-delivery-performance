/*
============================================================
Project: Olist E-Commerce Data Warehouse
Layer: Data Infrastructure (Staging → Core → Analytics)
File: 01_data_ingestion_and_validation

Description:
This script performs:
1. Raw data ingestion into staging layer
2. Data validation checks (nulls, duplicates)
3. Transformation and loading into core schema
4. Creation of analytical reference objects

Execution Order:
Run sequentially from top to bottom

Dependencies:
- Raw CSV files must be available

NOTE:
-- Update file paths in BULK INSERT statements before execution
============================================================
*/

/* ============================================================
   SECTION 1: DATABASE & SCHEMA SETUP
============================================================ */

CREATE DATABASE Olist_Operations_Analysis;
GO

USE Olist_Operations_Analysis;
GO

CREATE SCHEMA staging;
GO

CREATE SCHEMA core;
GO

CREATE SCHEMA analytics;
GO

/* ============================================================
   SECTION 2: CUSTOMER DATA PIPELINE
   - Load raw data
   - Validate
   - Transform into dimension
============================================================ */

IF OBJECT_ID('staging.customers_raw') IS NOT NULL
    DROP TABLE staging.customers_raw;
GO

CREATE TABLE staging.customers_raw (
    customer_id NVARCHAR(50),
    customer_unique_id NVARCHAR(50),
    customer_zip_code_prefix NVARCHAR(20),
    customer_city NVARCHAR(100),
    customer_state NVARCHAR(10)
);
GO

BULK INSERT staging.customers_raw
FROM 'D:\Work\Projects\Data Analytics Project\Mega Project\olist-delivery-performance\01_Raw_Data\olist_customers_dataset.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

SELECT 
    COUNT(*) AS [Row Count]
FROM staging.customers_raw;
GO

SELECT 
    COUNT(*) AS [Row Count]
FROM staging.customers_raw;
GO

SELECT 
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS [Null customer_id]
FROM staging.customers_raw;
GO

SELECT 
    SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END) AS [Null customer_unique_id]
FROM staging.customers_raw;
GO

SELECT 
    customer_id, 
    COUNT(*) AS [Duplicate Count]
FROM staging.customers_raw
GROUP BY customer_id
HAVING COUNT(*) > 1;
GO

SELECT 
    COUNT(DISTINCT customer_unique_id) AS [Distinct Customers]
FROM staging.customers_raw;
GO

IF OBJECT_ID('core.dim_customers') IS NOT NULL
    DROP TABLE core.dim_customers;
GO

CREATE TABLE core.dim_customers (
	customer_id VARCHAR(50) NOT NULL,
	customer_unique_id VARCHAR(50) NOT NULL,
	customer_zip_code_prefix VARCHAR(10),
	customer_city VARCHAR(100),
	customer_state CHAR(2),
	CONSTRAINT PK_dim_customers PRIMARY KEY (customer_id)
);
GO

INSERT INTO core.dim_customers(
	customer_id,
	customer_unique_id,
	customer_zip_code_prefix,
	customer_city,
	customer_state
)
SELECT 
	customer_id,
	customer_unique_id,
	customer_zip_code_prefix,
	customer_city,
	customer_state
FROM staging.customers_raw;
GO

CREATE INDEX IX_dim_customers_unique_id ON core.dim_customers (customer_unique_id);
GO

/* ============================================================
   SECTION 3: ORDERS DATA PIPELINE
   - Load raw order data
   - Validate data quality (nulls, duplicates)
   - Transform timestamps and load into core.orders
============================================================ */

IF OBJECT_ID('staging.orders_raw') IS NOT NULL
    DROP TABLE staging.orders_raw;
GO

CREATE TABLE staging.orders_raw (
	order_id NVARCHAR(50),
	customer_id  NVARCHAR(50),
	order_status NVARCHAR(50),
	order_purchase_timestamp NVARCHAR(50),
	order_approved_at NVARCHAR(50),
	order_delivered_carrier_date NVARCHAR(50),
	order_delivered_customer_date NVARCHAR(50),
	order_estimated_delivery_date NVARCHAR(50)
);
GO

BULK INSERT staging.orders_raw 
FROM 'D:\Work\Projects\Data Analytics Project\Mega Project\olist-delivery-performance\01_Raw_Data\olist_orders_dataset.csv'
WITH ( 
	FIRSTROW = 2, 
	FIELDTERMINATOR = ',', 
	ROWTERMINATOR = '0x0a', 
	CODEPAGE = '65001',
	TABLOCK 
);
GO

SELECT 
	COUNT(*) AS Row_Count 
FROM staging.orders_raw;
GO

SELECT 
	COUNT(*) AS Row_Count,
	SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id
FROM staging.orders_raw;
GO


SELECT 
	order_id,
	COUNT(*) AS [Total Count] 
FROM staging.orders_raw
GROUP BY order_id
HAVING COUNT(*) > 1;
GO

IF OBJECT_ID('core.orders') IS NOT NULL
    DROP TABLE core.orders;
GO

CREATE TABLE core.orders (
	order_id VARCHAR(50) NOT NULL,
	customer_id VARCHAR(50) NOT NULL,
	order_status VARCHAR(50),
	order_purchase_timestamp DATETIME2,
	order_approved_at DATETIME2,
	order_delivered_carrier_date DATETIME2,
	order_delivered_customer_date DATETIME2,
	order_estimated_delivery_date DATETIME2,
	CONSTRAINT PK_orders PRIMARY KEY (order_id),
	CONSTRAINT FK_orders_customer FOREIGN KEY (customer_id) REFERENCES core.dim_customers(customer_id)
);
GO

INSERT INTO core.orders (
	order_id,
	customer_id,
	order_status,
	order_purchase_timestamp,
	order_approved_at,
	order_delivered_carrier_date,
	order_delivered_customer_date,
	order_estimated_delivery_date
)

SELECT 
	order_id,
	customer_id,
	order_status,
	TRY_CONVERT(DATETIME2, order_purchase_timestamp),
	TRY_CONVERT(DATETIME2, order_approved_at),
	TRY_CONVERT(DATETIME2, order_delivered_carrier_date),
	TRY_CONVERT(DATETIME2, order_delivered_customer_date),
	TRY_CONVERT(DATETIME2, order_estimated_delivery_date)
FROM staging.orders_raw;
GO

SELECT 
    COUNT(*) AS [Row Count] 
FROM core.orders;
GO

SELECT 
    COUNT(*) AS [Orphan check] 
FROM core.orders o LEFT JOIN core.dim_customers c 
    ON c.customer_id = o.customer_id 
WHERE c.customer_id IS NULL;
GO

/* ============================================================
   SECTION 4: ORDER ITEMS DATA PIPELINE
   - Load order item level data
   - Validate grain and relationships
   - Transform numeric and datetime fields
   - Load into core.order_items
============================================================ */

IF OBJECT_ID('staging.order_items_raw') IS NOT NULL
    DROP TABLE staging.order_items_raw;
GO

CREATE TABLE staging.order_items_raw (
	 order_id NVARCHAR(50), 
	 order_item_id NVARCHAR(50),
	 product_id NVARCHAR(50), 
	 seller_id NVARCHAR(50), 
	 shipping_limit_date NVARCHAR(50), 
	 price NVARCHAR(50), 
	 freight_value NVARCHAR(50)
);
GO

BULK INSERT staging.order_items_raw
FROM 'D:\Work\Projects\Data Analytics Project\Mega Project\olist-delivery-performance\01_Raw_Data\olist_order_items_dataset.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

IF OBJECT_ID('core.order_items') IS NOT NULL
    DROP TABLE core.order_items;
GO

CREATE TABLE core.order_items (
	order_id VARCHAR(50) NOT NULL,
	order_item_id INT NOT NULL,
	product_id VARCHAR(50) NOT NULL,
	seller_id VARCHAR(50) NOT NULL, 
	shipping_limit_date DATETIME2, 
	price DECIMAL(10,2), 
	freight_value DECIMAL(10,2),
	CONSTRAINT PK_order_items PRIMARY KEY (order_id, order_item_id),
	CONSTRAINT FK_order_id FOREIGN KEY (order_id) REFERENCES core.orders(order_id)
	CONSTRAINT FK_product_id FOREIGN KEY (product_id) REFERENCES core.dim_products,
	CONSTRAINT FK_seller_id FOREIGN KEY (seller_id) REFERENCES core.dim_sellers
)
GO


INSERT INTO core.order_items (
	 order_id, 
	 order_item_id, 
	 product_id, 
	 seller_id, 
	 shipping_limit_date, 
	 price, 
	 freight_value 
)

SELECT 
	order_id,
	TRY_CONVERT(INT, order_item_id),
	product_id,
	seller_id,
	TRY_CONVERT(DATETIME2, shipping_limit_date),
	TRY_CONVERT(decimal(10,2), price),
	TRY_CONVERT(decimal(10,2), freight_value)
FROM staging.order_items_raw;
GO

SELECT 
    COUNT(*) AS [Row Count]
FROM core.order_items;
GO

SELECT 
    COUNT(*) AS [Orphan check] 
FROM core.order_items oi 
    LEFT JOIN core.orders o ON oi.order_id = o.order_id 
WHERE o.order_id IS NULL;
GO

/* ============================================================
   SECTION 5: PAYMENTS DATA PIPELINE
   - Load payment transactions
   - Validate multi-payment scenarios per order
   - Convert numeric fields and load into core.order_payments
============================================================ */

IF OBJECT_ID('staging.order_payments_raw') IS NOT NULL
    DROP TABLE staging.order_payments_raw;
GO

CREATE TABLE staging.order_payments_raw (
    order_id NVARCHAR(50),
    payment_sequential NVARCHAR(50),
    payment_type NVARCHAR(50),
    payment_installments NVARCHAR(50),
    payment_value NVARCHAR(50)
);
GO

BULK INSERT staging.order_payments_raw
FROM 'D:\Work\Projects\Data Analytics Project\Mega Project\olist-delivery-performance\01_Raw_Data\olist_order_payments_dataset.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

IF OBJECT_ID('core.order_payments') IS NOT NULL
    DROP TABLE core.order_payments;
GO

CREATE TABLE core.order_payments (
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(10,2),
    CONSTRAINT PK_order_payments PRIMARY KEY (order_id, payment_sequential),
     CONSTRAINT FK_order_payments_orders FOREIGN KEY (order_id) REFERENCES core.orders(order_id)
);
GO

INSERT INTO core.order_payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)

SELECT 
    order_id,
    TRY_CONVERT(INT, payment_sequential),
    payment_type,
    TRY_CONVERT(INT, payment_installments),
    TRY_CONVERT(DECIMAL(10,2), payment_value)
FROM staging.order_payments_raw;
GO

SELECT 
	COUNT(*) AS [Row Count] 
FROM core.order_payments;
GO

SELECT
	COUNT(*) AS [Orphan check] 
FROM core.order_payments op 
	LEFT JOIN 
core.orders o 
	ON op.order_id = o.order_id 
WHERE op.order_id IS NULL;
GO

/* ============================================================
   SECTION 5: PAYMENTS DATA PIPELINE
   - Load payment transactions
   - Validate multi-payment scenarios per order
   - Convert numeric fields and load into core.order_payments
============================================================ */

IF OBJECT_ID('staging.products_raw') IS NOT NULL
    DROP TABLE staging.products_raw;
GO

CREATE TABLE staging.products_raw (
    product_id NVARCHAR(50),
    product_category_name NVARCHAR(50),
    product_name_lenght NVARCHAR(50),
    product_description_lenght NVARCHAR(50),
    product_photos_qty NVARCHAR(50),
    product_weight_g NVARCHAR(50),
    product_length_cm NVARCHAR(50),
    product_height_cm NVARCHAR(50),
    product_width_cm NVARCHAR(50)
);
GO

BULK INSERT staging.products_raw
FROM 'D:\Work\Projects\Data Analytics Project\Mega Project\olist-delivery-performance\01_Raw_Data\olist_products_dataset.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

IF OBJECT_ID('core.dim_products') IS NOT NULL
    DROP TABLE core.dim_products;
GO

CREATE TABLE core.dim_products (
    product_id VARCHAR(50) NOT NULL,
    product_category_name VARCHAR(50),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm DECIMAL(10,2),
    product_height_cm DECIMAL(10,2),
    product_width_cm DECIMAL(10,2),

    CONSTRAINT PK_products PRIMARY KEY (product_id) 
);
GO

INSERT INTO core.dim_products (
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)

SELECT 
    product_id,
    product_category_name,
    TRY_CONVERT(INT, product_name_lenght),
    TRY_CONVERT(INT, product_description_lenght),
    TRY_CONVERT(INT, product_photos_qty),
    TRY_CONVERT(INT, product_weight_g),
    TRY_CONVERT(DECIMAL(10,2), product_length_cm),
    TRY_CONVERT(DECIMAL(10,2), product_height_cm),
    TRY_CONVERT(DECIMAL(10,2), product_width_cm)
FROM staging.products_raw;
GO

SELECT 
    COUNT(*) AS [Row Count]
FROM staging.products_raw;
GO

SELECT 
	COUNT(*) AS [Null product_id]
FROM core.dim_products
WHERE product_id IS NULL;
GO

/* ============================================================
   SECTION 7: SELLERS DATA PIPELINE
   - Load seller information
   - Validate completeness of location attributes
   - Load into core.dim_sellers
============================================================ */

IF OBJECT_ID('staging.sellers_raw') IS NOT NULL
    DROP TABLE staging.sellers_raw;
GO

CREATE TABLE staging.sellers_raw (
    seller_id NVARCHAR(50),
    seller_zip_code_prefix NVARCHAR(50),
    seller_city NVARCHAR(50),
    seller_state NVARCHAR(50)
);
GO

BULK INSERT staging.sellers_raw
FROM 'D:\Work\Projects\Data Analytics Project\Mega Project\olist-delivery-performance\01_Raw_Data\olist_sellers_dataset.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

IF OBJECT_ID('core.dim_sellers') IS NOT NULL
    DROP TABLE core.dim_sellers;
GO

CREATE TABLE core.dim_sellers (
    seller_id VARCHAR(50) NOT NULL,
    seller_zip_code_prefix VARCHAR(50),
    seller_city VARCHAR(50),
    seller_state VARCHAR(50),
    CONSTRAINT PK_dim_sellers PRIMARY KEY (seller_id)
);
GO

INSERT INTO core.dim_sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)

SELECT 
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM staging.sellers_raw;
GO

SELECT 
	COUNT(*) AS [Row Count]
FROM core.dim_sellers;
GO

/* ============================================================
   SECTION 8: GEOLOCATION DATA PIPELINE
   - Load geolocation data
   - Convert latitude and longitude values
   - Aggregate for zip-level analytics
============================================================ */

IF OBJECT_ID('staging.geolocation_raw') IS NOT NULL
    DROP TABLE staging.geolocation_raw;
GO

CREATE TABLE staging.geolocation_raw (
    geolocation_zip_code_prefix NVARCHAR(50),
    geolocation_lat NVARCHAR(50),
    geolocation_lng NVARCHAR(50),
    geolocation_city NVARCHAR(50),
    geolocation_state NVARCHAR(50)
);
GO

BULK INSERT staging.geolocation_raw
FROM 'D:\Work\Projects\Data Analytics Project\Mega Project\olist-delivery-performance\01_Raw_Data\olist_geolocation_dataset.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

IF OBJECT_ID('core.geolocation_points') IS NOT NULL
    DROP TABLE core.geolocation_points;
GO

CREATE TABLE core.geolocation_points (
    geolocation_zip_code_prefix VARCHAR(50) NOT NULL,
    geolocation_lat DECIMAL(10,6),
    geolocation_lng DECIMAL(10,6),
    geolocation_city VARCHAR(50),
    geolocation_state VARCHAR(50)
);
GO

INSERT INTO core.geolocation_points (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)

SELECT 
    geolocation_zip_code_prefix,
    TRY_CONVERT(DECIMAL(10,6), geolocation_lat),
    TRY_CONVERT(DECIMAL(10,6), geolocation_lng),
    geolocation_city,
    geolocation_state
FROM staging.geolocation_raw;
GO

SELECT 
	COUNT(*) AS [Row Count]
FROM staging.geolocation_raw;
GO

SELECT 
	COUNT(*) AS [Row Count]
FROM core.geolocation_points;
GO

SELECT 
    COUNT(DISTINCT geolocation_zip_code_prefix) AS [Distinct Zip Codes]
FROM core.geolocation_points;
GO

IF OBJECT_ID('analytics.zip_geolocation_reference') IS NOT NULL
    DROP VIEW analytics.zip_geolocation_reference;
GO

CREATE VIEW analytics.zip_geolocation_reference AS 
SELECT 
	geolocation_zip_code_prefix AS [Zip_Code],
	AVG(geolocation_lat) AS [Avg_Lat],
	AVG(geolocation_lng) AS [Avg_Long]
FROM core.geolocation_points
GROUP BY geolocation_zip_code_prefix;
GO

SELECT * FROM analytics.zip_geolocation_reference;
GO

/* ============================================================
   SECTION 9: REVIEWS DATA PIPELINE
   - Load customer reviews
   - Validate duplicates and malformed timestamps
   - Deduplicate and load into core.order_reviews
============================================================ */

IF OBJECT_ID('staging.review_raw') IS NOT NULL
    DROP TABLE staging.review_raw;
GO

CREATE TABLE staging.review_raw (
    review_id NVARCHAR(50),
    order_id NVARCHAR(50),
    review_score VARCHAR(50),
    review_comment_title NVARCHAR(255),
    review_comment_message NVARCHAR(MAX),
    review_creation_date NVARCHAR(50),
    review_answer_timestamp NVARCHAR(50)
);
GO

BULK INSERT staging.review_raw
FROM 'D:\Work\Projects\Data Analytics Project\Mega Project\olist-delivery-performance\01_Raw_Data\olist_order_reviews_dataset.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);
GO

SELECT 
	COUNT(*) AS [Row Count]
FROM staging.review_raw;
GO

SELECT 
	COUNT(*) AS [Row Count],
	SUM(CASE WHEN review_id IS NULL OR LTRIM(RTRIM(review_id)) = '' THEN 1 ELSE 0 END) AS [Null Review ID]
FROM staging.review_raw;
GO

SELECT 
	review_id,
	COUNT(*) AS [Total Count]
FROM staging.review_raw
GROUP BY review_id
HAVING COUNT(*)> 1;
GO

SELECT 
	DISTINCT review_score
FROM staging.review_raw;
GO

SELECT 
	SUM(CASE WHEN TRY_CONVERT(DATETIME2, review_creation_date) IS NULL THEN 1 ELSE 0 END) AS [Bad_Creation_Date]
FROM staging.review_raw;
GO

SELECT 
	SUM(CASE WHEN TRY_CONVERT(DATETIME2, review_answer_timestamp) IS NULL THEN 1 ELSE 0 END) AS [Bad_Review_Answer_Date]
FROM staging.review_raw;
GO

IF OBJECT_ID('core.order_reviews') IS NOT NULL
    DROP TABLE core.order_reviews;
GO

CREATE TABLE core.order_reviews (
    review_id VARCHAR(50) NOT NULL,
    order_id VARCHAR(50),
    review_score INT,  
    review_comment_title VARCHAR(255),
    review_comment_message VARCHAR(MAX),
    review_creation_date DATETIME2, 
    review_answer_timestamp DATETIME2,
    CONSTRAINT PK_order_reviews PRIMARY KEY (review_id),
    CONSTRAINT FK_order_reviews_orders FOREIGN KEY (order_id) REFERENCES core.orders(order_id)
);
GO

;WITH deduplicated_reviews AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY review_id
            ORDER BY TRY_CONVERT(DATETIME2, review_creation_date) DESC
        ) AS rn
    FROM staging.review_raw
    WHERE review_id IS NOT NULL
      AND LTRIM(RTRIM(review_id)) <> ''
)

INSERT INTO core.order_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)

SELECT 
    dr.review_id,
    dr.order_id,
    TRY_CONVERT(INT, dr.review_score),
    dr.review_comment_title,
    dr.review_comment_message,
    TRY_CONVERT(DATETIME2, dr.review_creation_date),
    TRY_CONVERT(DATETIME2, dr.review_answer_timestamp)

FROM deduplicated_reviews dr
INNER JOIN core.orders o
    ON dr.order_id = o.order_id
WHERE dr.rn = 1;
GO

SELECT 
    COUNT(*) AS [Row Count]
FROM core.order_reviews;
GO

SELECT 
	COUNT(DISTINCT review_id) AS [Distinct Review ID]
FROM core.order_reviews;
GO

/* ============================================================
   SECTION 10: CATEGORY TRANSLATION PIPELINE
   - Load product category translations
   - Clean invalid or blank categories
   - Load into core.product_category_translation
============================================================ */

IF OBJECT_ID('staging.category_raw') IS NOT NULL
    DROP TABLE staging.category_raw;
GO

CREATE TABLE staging.category_raw (
    product_category_name NVARCHAR(255),
    product_category_name_english NVARCHAR(255)
);
GO

BULK INSERT staging.category_raw
FROM 'D:\Work\Projects\Data Analytics Project\Mega Project\olist-delivery-performance\01_Raw_Data\product_category_name_translation.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
); 
GO

IF OBJECT_ID('core.product_category_translation') IS NOT NULL
    DROP TABLE core.product_category_translation;
GO

CREATE TABLE core.product_category_translation (
    product_category_name NVARCHAR(255) NOT NULL,
    product_category_name_english NVARCHAR(255),
    CONSTRAINT PK_product_category_translation PRIMARY KEY (product_category_name)
);
GO

INSERT INTO core.product_category_translation (
    product_category_name,
    product_category_name_english
)
SELECT 
    product_category_name,
    product_category_name_english
FROM staging.category_raw
WHERE product_category_name IS NOT NULL
  AND LTRIM(RTRIM(product_category_name)) <> '';
GO      

/* ============================================================
   PIPELINE SUMMARY
   - Staging layer populated from raw CSV files
   - Core layer built with cleaned and typed data
   - Referential integrity validated using orphan checks
   - Analytical view created for geolocation aggregation
============================================================ */