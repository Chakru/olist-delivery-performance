# Part IV – Hypothesis Testing Execution Guide

## Overview

This phase validates key business hypotheses related to delivery performance, customer satisfaction, and revenue exposure.

Using the engineered dataset (`analytics.fact_orders_final`), structured SQL queries are executed to quantify operational inefficiencies, identify root causes of delays, and assess their business impact.

---

## Prerequisites

* Part III completed
* `analytics.fact_orders_final` available
* SQL Server environment configured
* Database context set to `Olist_Operations_Analysis`

---

## Execution Steps

1. Open the SQL file:

```
03_SQL/03_hypothesis_testing.sql
```

2. Set database context:
```
USE Olist_Operations_Analysis;
```

3. Execute queries sequentially from H1 to H5 to maintain logical flow and dependency across hypotheses.

---

## Hypotheses Tested

### H1 – Delivery delays are operationally significant

Measures:

* Total delivered orders
* % late deliveries
* Average delay days
* Delay distribution

Objective:
Determine whether delays are a systemic operational issue or isolated cases.

---

### H2 – Delays are concentrated among sellers

Measures:

* Seller-level delay rate
* Seller ranking
* Pareto analysis
* Revenue contribution of high-delay sellers

Objective:
Identify whether a small group of sellers drives the majority of delays.

---

### H3 – Distance impacts delivery performance

Measures:

* Delay rate by distance bucket
* Average delay days by distance
* Trend validation

Objective:
Evaluate whether logistics distance is a structural factor.

---

### H4 – Delay impacts customer satisfaction

Measures:

* Average review score (Delayed vs On-time)
* % low ratings (1–2 stars)
* Review distribution
* Satisfaction delta (On-time vs Delayed)

Objective:
Assess the impact of delays on customer experience.

---

### H5 – Revenue exposure due to delays

Measures:

* Revenue from delayed orders
* Revenue at risk (Delayed + Low rating orders)
* Revenue contribution of high-delay sellers
* Repeat purchase rate (Delayed vs On-time)

Objective:
Quantify financial risk associated with delivery inefficiencies.

---

## Output

The queries generate:

* Delay distribution insights
* Seller performance rankings
* Distance-based delivery trends
* Customer satisfaction comparisons
* Revenue exposure metrics

These outputs support data-driven decision-making.

---

## Key Considerations

* Maintain correct grain (order-level vs seller-level joins)
* Handle one-to-many relationships carefully (order → multiple sellers)
* Use COUNT DISTINCT to avoid duplication
* Validate null values and extreme values before interpretation
* Interpret small sample segments cautiously (e.g., long-distance bucket)
* Revenue attribution across sellers is assumed to be equally distributed per order

---

## Next Step

Proceed to:

Part V – Data Modeling for Power BI
