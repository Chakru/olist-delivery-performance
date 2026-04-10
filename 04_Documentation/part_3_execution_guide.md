# Part III – Data Preparation & Feature Engineering Execution Guide

## Overview

This phase transforms the validated relational data into a structured analytical dataset.

The goal is to build a clean, order-level fact table (`Fact_Orders_Master`) that supports accurate analysis, KPI calculation, and downstream reporting.

---

## Prerequisites

- Part II (Data Infrastructure Setup) completed  
- Core tables available in SQL Server  
- SQL Server Management Studio (SSMS) or equivalent tool  
- Database context set to `Olist_Operations_Analysis`  

---

## Execution Steps

1. Open the SQL file:
```
02_data_preparation_and_feature_engineering.sql
```

2. Ensure the correct database is selected:
```
USE Olist_Operations_Analysis;
```

3. Execute the script sequentially (top to bottom)

---

## What This Script Does

### 1. Base Orders Construction

Creates a unified order-level base by joining:

- `orders`
- `customers`
- `reviews`
- `payments`

This step ensures all core attributes are available at the order level.

---

### 2. Order Items Aggregation

Handles one-to-many relationships in `order_items` by aggregating:

- Total order value (`price`)
- Total freight cost (`freight_value`)
- Seller count per order

This prevents duplication when joining transactional data.

---

### 3. Fact Table Creation

Builds the final analytical table:
```
fact_orders_master
```

This table includes:

- Order-level attributes  
- Customer information  
- Aggregated financial metrics  
- Review scores  
- Delivery timestamps  

---

### 4. Feature Engineering

Creates analytical features required for business insights.

#### Delivery Features
- `actual_delivery_days`
- `estimated_delivery_days`
- `delivery_delay_days`
- `delay_flag` (1 = Late, 0 = On-time/Early)
- `delay_category` (Early / On-time / Late)

#### Revenue & Operational Features
- `order_revenue`
- `seller_count`

---

### 5. Distance Calculation

Uses geolocation data to:

- Map customer and seller locations  
- Calculate approximate distance between them  
- Create distance buckets:

  - 0–100 km  
  - 100–300 km  
  - 300–700 km  
  - 700+ km  

This enables analysis of logistics impact on delivery performance.

---

## Data Quality Considerations

- Ensures **1 row = 1 order** (strict grain control)  
- Prevents revenue duplication via aggregation  
- Handles null and inconsistent timestamp values  
- Validates extreme or negative delivery durations  

---

## Output

After execution, the following dataset is available:

- `analytics.Fact_Orders_Master`

This dataset serves as the **single source of truth** for:

- KPI calculation  
- Hypothesis testing  
- Power BI reporting  

---

## Notes

- Do not join `order_items` directly without aggregation  
- Always validate grain before performing joins  
- Ensure delivery calculations handle null values safely  

---

## Next Step

Proceed to:

**Part IV – Hypothesis Testing**

This phase will validate business hypotheses using the engineered dataset and quantify operational and financial impact.