/*
============================================================
Project: Olist E-Commerce Delivery Performance Analysis

Layer: Hypothesis Testing (Part IV)

File: 03_hypothesis_testing.sql

Description:
This script evaluates key business hypotheses related to
delivery performance, seller behaviour, customer satisfaction,
and revenue impact.

Each section answers a specific business question using
metrics derived from the final analytical dataset:
→ analytics.fact_orders_final

============================================================

INPUT:
- analytics.fact_orders_final
- core.order_items (for seller-level analysis)

============================================================

OUTPUT:
- Aggregated metrics for decision-making
- Inputs for dashboard & case study

============================================================

IMPORTANT NOTES:

- Analysis restricted to delivered orders only
- Null delivery timestamps excluded to ensure accuracy
- Delay logic based on engineered feature: is_delayed
- Revenue is based on total_order_value
- Customer behaviour uses is_repeat_customer

============================================================
*/


/* ============================================================
   H1 – DELAY SIGNIFICANCE
   Business Question:
   → Is delivery delay a meaningful operational problem?

   Metrics:
   - Total delivered orders
   - % delayed deliveries
   - Average delay duration
   - Delay distribution
============================================================ */

-- H1.1 – Total delivered orders
SELECT 
    COUNT(DISTINCT order_id) AS total_delivered_orders
FROM analytics.fact_orders_final
WHERE LOWER(order_status) = 'delivered'
    AND order_delivered_customer_date IS NOT NULL;
GO


-- H1.2 – Percentage of delayed deliveries
SELECT 
    (delayed_orders * 100.0 / NULLIF(total_delivered_orders, 0)) AS late_delivery_percentage
FROM (
    SELECT 
        SUM(CASE WHEN is_delayed = 1 THEN 1 ELSE 0 END) AS delayed_orders,
        COUNT(DISTINCT order_id) AS total_delivered_orders
    FROM analytics.fact_orders_final
    WHERE LOWER(order_status) = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
) t;
GO


-- H1.3 – Average delay days (only delayed orders)
SELECT 
    AVG(delay_days_clean) AS average_delay_days
FROM analytics.fact_orders_final
WHERE LOWER(order_status) = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND is_delayed = 1;
GO


-- H1.4 – Delay distribution (severity segmentation)
WITH delay_bucket_base AS (
    SELECT 
        order_id,
        CASE 
            WHEN delay_days_clean BETWEEN 0 AND 2  THEN '0-2 Days'
            WHEN delay_days_clean BETWEEN 3 AND 5  THEN '3-5 Days'
            WHEN delay_days_clean BETWEEN 6 AND 10 THEN '6-10 Days'
            WHEN delay_days_clean > 10             THEN '10+ Days'
            ELSE 'Unknown'
        END AS delay_bucket
    FROM analytics.fact_orders_final
    WHERE LOWER(order_status) = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND is_delayed = 1
        AND delay_days_clean IS NOT NULL
)
SELECT 
    delay_bucket,
    COUNT(*) AS total_delivered_orders,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS distribution_percentage
FROM delay_bucket_base
GROUP BY delay_bucket
ORDER BY 
    CASE delay_bucket
        WHEN '0-2 Days'  THEN 1
        WHEN '3-5 Days'  THEN 2
        WHEN '6-10 Days' THEN 3
        WHEN '10+ Days'  THEN 4
        ELSE 5
    END;
GO


/* ============================================================
   H2 – SELLER CONCENTRATION
   Business Question:
   → Are delays concentrated among specific sellers?

   Metrics:
   - Seller-level delay rate
   - Top delayed sellers
   - Pareto concentration
   - Revenue contribution
============================================================ */

-- H2.1 – Seller-level delay rate
SELECT 
    t.seller_id,
    total_delivered_orders,
    delayed_orders,
    ROUND(delayed_orders * 100.0 / NULLIF(total_delivered_orders, 0), 2) AS delay_percentage
FROM (
    SELECT 
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS total_delivered_orders,
        COUNT(DISTINCT CASE WHEN f.is_delayed = 1 THEN oi.order_id END) AS delayed_orders
    FROM core.order_items oi
    INNER JOIN analytics.fact_orders_final f
        ON oi.order_id = f.order_id
    WHERE LOWER(f.order_status) = 'delivered'
        AND f.order_delivered_customer_date IS NOT NULL
    GROUP BY oi.seller_id
) t;
GO


-- H2.2 – Top sellers by delay rate (min volume filter applied)
WITH seller_delay_agg AS (
    SELECT 
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COUNT(DISTINCT CASE WHEN f.is_delayed = 1 THEN oi.order_id END) AS delayed_orders,
        ROUND(
            COUNT(DISTINCT CASE WHEN f.is_delayed = 1 THEN oi.order_id END) * 100.0
            / NULLIF(COUNT(DISTINCT oi.order_id), 0), 2
        ) AS delay_percentage
    FROM core.order_items oi
    INNER JOIN analytics.fact_orders_final f
        ON oi.order_id = f.order_id
    WHERE LOWER(f.order_status) = 'delivered'
        AND f.order_delivered_customer_date IS NOT NULL
    GROUP BY oi.seller_id
    HAVING COUNT(DISTINCT oi.order_id) >= 20
),
seller_delay_ranked AS (
    SELECT 
        *,
        DENSE_RANK() OVER (ORDER BY delay_percentage DESC) AS delay_rank
    FROM seller_delay_agg 
)
SELECT *
FROM seller_delay_ranked 
WHERE delay_rank <= 10;
GO


-- H2.3 – Pareto analysis (delay concentration)
WITH seller_delays AS (
    SELECT 
        oi.seller_id,
        COUNT(DISTINCT CASE WHEN f.is_delayed = 1 THEN oi.order_id END) AS delayed_orders
    FROM core.order_items oi
    INNER JOIN analytics.fact_orders_final f
        ON oi.order_id = f.order_id
    WHERE LOWER(f.order_status) = 'delivered'
        AND f.order_delivered_customer_date IS NOT NULL
    GROUP BY oi.seller_id
),
pareto AS (
    SELECT 
        seller_id,
        delayed_orders,
        COUNT(*) OVER() AS total_sellers,
        SUM(delayed_orders) OVER (ORDER BY delayed_orders DESC) AS cumulative_delayed_orders,
        SUM(delayed_orders) OVER () AS total_delayed_orders
    FROM seller_delays
)
SELECT 
    seller_id,
    delayed_orders,
    total_sellers,
    cumulative_delayed_orders,
    ROUND(cumulative_delayed_orders * 100.0 / total_delayed_orders, 2) AS cumulative_percentage,
    ROW_NUMBER() OVER (ORDER BY delayed_orders DESC) AS row_numbering
FROM pareto
ORDER BY delayed_orders DESC;
GO


-- H2.4 – Revenue contribution of high-delay sellers
-- Assumption: Revenue equally distributed across sellers per order

WITH base AS (
    SELECT DISTINCT
        oi.seller_id,
        oi.order_id,
        CASE WHEN f.is_delayed = 1 THEN 1 ELSE 0 END AS is_delayed,
        f.total_order_value / NULLIF(f.seller_count, 0) AS revenue_per_seller
    FROM core.order_items oi
    INNER JOIN analytics.fact_orders_final f
        ON oi.order_id = f.order_id
    WHERE LOWER(f.order_status) = 'delivered'
        AND f.order_delivered_customer_date IS NOT NULL
),
seller_agg AS (
    SELECT 
        seller_id,
        SUM(is_delayed) AS delayed_orders,
        ROUND(SUM(revenue_per_seller), 2) AS total_revenue
    FROM base
    GROUP BY seller_id
),
pareto AS (
    SELECT 
        *,
        SUM(delayed_orders) OVER (ORDER BY delayed_orders DESC) AS cumulative_delayed_orders,
        SUM(delayed_orders) OVER () AS total_delayed_orders,
        ROW_NUMBER() OVER (ORDER BY delayed_orders DESC) AS row_numbering
    FROM seller_agg
)
SELECT 
    seller_id,
    delayed_orders,
    cumulative_delayed_orders,
    total_revenue,
    ROUND(cumulative_delayed_orders * 100.0 / total_delayed_orders, 2) AS cumulative_delay_percentage,
    ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER (), 2) AS revenue_percentage,
    SUM(total_revenue) OVER (ORDER BY delayed_orders DESC) AS cumulative_revenue,
    ROUND(
        SUM(total_revenue) OVER (ORDER BY delayed_orders DESC) * 100.0 
        / SUM(total_revenue) OVER (), 2
    ) AS cumulative_revenue_percentage,
    row_numbering
FROM pareto
ORDER BY delayed_orders DESC;
GO


/* ============================================================
   H3 – DISTANCE IMPACT
   Business Question:
   → Does delivery distance impact delays?

   Metrics:
   - Delay rate by distance bucket
   - Average delay duration by distance

   Note: Long distance bucket has low sample size; interpret with caution
============================================================ */

-- H3.1 – Delay rate by distance
SELECT 
    distance_bucket_refined,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN is_delayed = 1 THEN order_id END) AS delayed_orders,
    ROUND(
        COUNT(DISTINCT CASE WHEN is_delayed = 1 THEN order_id END) * 100.0
        / NULLIF(COUNT(DISTINCT order_id), 0), 2
    ) AS delay_percentage
FROM analytics.fact_orders_final
WHERE LOWER(order_status) = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND distance_bucket_refined IS NOT NULL
GROUP BY distance_bucket_refined
ORDER BY 
    CASE distance_bucket_refined
        WHEN 'Very Short' THEN 1
        WHEN 'Short' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Long' THEN 4
    END;
GO


-- H3.2 – Average delay days
SELECT 
    distance_bucket_refined,
    COUNT(order_id) AS delayed_orders,
    ROUND(AVG(delay_days_clean), 2) AS average_delay_days
FROM analytics.fact_orders_final
WHERE LOWER(order_status) = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND distance_bucket_refined IS NOT NULL
    AND is_delayed= 1
GROUP BY distance_bucket_refined
ORDER BY 
    CASE distance_bucket_refined
        WHEN 'Very Short' THEN 1
        WHEN 'Short' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'Long' THEN 4
    END;
GO


/* ============================================================
   H4 – CUSTOMER SATISFACTION
   Business Question:
   → Do delays reduce customer satisfaction?

   Metrics:
   - Average review score
   - % low ratings
   - Review distribution
============================================================ */

-- H4.1 – Average review score
SELECT 
    CASE WHEN is_delayed = 1 THEN 'Delayed' ELSE 'On-Time' END AS delivery_status,
    COUNT(order_id) AS total_orders,
    ROUND(AVG(review_score), 2) AS average_review_score
FROM analytics.fact_orders_final
WHERE LOWER(order_status) = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND review_score IS NOT NULL
GROUP BY is_delayed;
GO


-- H4.2 – Percentage of low ratings
SELECT 
    CASE WHEN is_delayed = 1 THEN 'Delayed' ELSE 'On-Time' END AS delivery_status,
    ROUND(
        COUNT(CASE WHEN review_score IN (1, 2) THEN order_id END) * 100.0
        / NULLIF(COUNT(order_id), 0), 2
    ) AS low_rating_percentage
FROM analytics.fact_orders_final
WHERE LOWER(order_status) = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND review_score IS NOT NULL
GROUP BY is_delayed;
GO


-- H4.3 – Review distribution
WITH base AS (
    SELECT 
        CASE WHEN is_delayed = 1 THEN 'Delayed' ELSE 'On-Time' END AS delivery_status,
        review_score,
        order_id
    FROM analytics.fact_orders_final
    WHERE LOWER(order_status) = 'delivered'
        AND order_delivered_customer_date IS NOT NULL
        AND review_score IS NOT NULL
)
SELECT 
    delivery_status,
    review_score,
    COUNT(order_id) AS total_orders
FROM base
GROUP BY delivery_status, review_score;
GO

-- H4.4 – Satisfaction delta (On-Time vs Delayed)

WITH satisfaction AS (
	SELECT
		CASE
			WHEN is_delayed = 1 THEN 'Delayed'
			ELSE 'On-Time'
		END AS delivery_status,
		AVG(review_score) AS avg_score
	FROM analytics.fact_orders_final
	WHERE LOWER(order_status) = 'delivered'
	AND order_delivered_customer_date IS NOT NULL
	AND review_score IS NOT NULL
	GROUP BY is_delayed
)
SELECT
	MAX(CASE WHEN delivery_status = 'On-Time' THEN avg_score END) - MAX(CASE WHEN delivery_status = 'Delayed' THEN avg_score END) AS satisfaction_delta
FROM satisfaction;
GO


/* ============================================================
   H5 – REVENUE EXPOSURE
   Business Question:
   → What is the financial impact of delays?

   Metrics:
   - Revenue from delayed orders
   - Revenue at risk (Delayed + Low Rating)
   - Repeat purchase behaviour
============================================================ */

-- H5.1 – Revenue from delayed orders
SELECT 
    SUM(total_order_value) AS total_revenue,
    SUM(CASE WHEN is_delayed = 1 THEN total_order_value ELSE 0 END) AS delayed_revenue,
    ROUND(
        SUM(CASE WHEN is_delayed = 1 THEN total_order_value ELSE 0 END) * 100.0
        / NULLIF(SUM(total_order_value), 0), 2
    ) AS delayed_revenue_percentage
FROM analytics.fact_orders_final
WHERE LOWER(order_status) = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND total_order_value IS NOT NULL;
GO


-- H5.2 – Revenue at risk (delayed + low rating)
SELECT 
    SUM(
        CASE 
            WHEN is_delayed = 1 AND review_score IN (1, 2)
            THEN total_order_value 
            ELSE 0 
        END
    ) AS revenue_at_risk,
    ROUND(
        SUM(
            CASE 
                WHEN is_delayed = 1 AND review_score IN (1, 2)
                THEN total_order_value
                ELSE 0 
            END
        ) * 100.0
        / NULLIF(SUM(total_order_value), 0), 2
    ) AS revenue_at_risk_percentage
FROM analytics.fact_orders_final
WHERE LOWER(order_status) = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND review_score IS NOT NULL;
GO


-- H5.3 – Repeat purchase rate
SELECT 
    CASE WHEN is_delayed = 1 THEN 'Delayed' ELSE 'On-Time' END AS delivery_status,
    ROUND(
        SUM(CASE WHEN is_repeat_customer = 1 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(order_id), 0), 2
    ) AS repeat_customer_rate
FROM analytics.fact_orders_final
WHERE LOWER(order_status) = 'delivered'
    AND order_delivered_customer_date IS NOT NULL
    AND is_repeat_customer IS NOT NULL
GROUP BY is_delayed;
GO


-- H5.4 – Financially critical segments
-- (Derived analytically using:
--  H2 → Seller concentration
--  H4 → Customer dissatisfaction
--  H5 → Revenue at risk + retention drop)
------------------------------------------

-- No direct SQL required. This is synthesis layer.


/*************************************************************
FINAL SUMMARY

- H1 confirms whether delay is a real problem
- H2 identifies problematic sellers
- H3 validates operational drivers (distance)
- H4 measures customer impact
- H5 quantifies financial risk

This file directly supports:
→ Business recommendations
→ Dashboard insights
→ Case study narrative

*************************************************************/