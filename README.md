# Part I – Strategic Foundation

## Objective
This phase establishes the business context, defines the problem, and frames the analytical approach. The goal is to ensure that all downstream analysis is driven by clear business questions rather than exploratory guesswork.

---

## Business Context
Olist operates as a marketplace connecting sellers across Brazil to customers through multiple sales channels. Sellers are responsible for order fulfilment, while Olist manages the platform and customer experience.

Delivery performance is a critical component of this ecosystem. Delays in delivery can impact customer satisfaction, reduce repeat purchases, and introduce operational inefficiencies.

---

## Problem Definition
Olist experiences inconsistent delivery performance across sellers and regions. While delays are observed, it is unclear:

- Whether delays are a systemic issue or isolated cases  
- Which operational factors are driving these delays  
- How delays impact customer satisfaction  
- What financial risk is associated with poor delivery performance  

---

## Core Business Question
What operational factors are driving delivery delays, and how do those delays impact customer satisfaction and revenue performance?

---

## Analytical Approach
Instead of starting with data exploration, this project follows a hypothesis-driven approach:

1. Define the problem clearly  
2. Identify measurable outcomes  
3. Formulate testable hypotheses  
4. Validate each hypothesis using structured analysis  

This ensures that every transformation and metric is aligned with a business objective.

---

## Hypotheses

### H1 – Delivery delays are operationally significant
This tests whether late deliveries represent a meaningful operational issue rather than isolated outliers.

### H2 – Delivery delays are concentrated among a minority of sellers
This evaluates whether delays are driven by a small subset of sellers rather than evenly distributed.

### H3 – Delivery distance impacts delivery performance
This tests whether longer distances increase the probability of delay.

### H4 – Late deliveries reduce customer satisfaction
This evaluates the relationship between delivery performance and customer review scores.

### H5 – High-delay sellers create disproportionate revenue exposure
This tests whether sellers contributing to delays also account for a significant share of revenue.

---

## Stakeholders

### Primary Stakeholder
- Head of Operations  
Focus: Improve delivery efficiency and reduce delays  

### Secondary Stakeholder
- Head of Customer Experience  
Focus: Maintain customer satisfaction and reduce negative reviews  

### Evaluator
- BI Manager  
Focus: Validate analytical approach and ensure data reliability  

---

## Success Criteria
The project will be considered successful if it can:

- Quantify the extent of delivery delays  
- Identify high-risk sellers contributing to delays  
- Establish the relationship between delay and customer satisfaction  
- Estimate revenue exposure linked to delivery inefficiencies  
- Provide clear, actionable recommendations  

---

## Key Metrics (Initial Definition)

### Delivery Metrics
- On-Time Delivery Rate  
- Late Delivery %  
- Average Delivery Time  
- Delivery Delay Days  

### Customer Metrics
- Average Review Score  
- Low Rating %  
- Repeat Purchase Rate (to be derived)  

### Financial Metrics
- Revenue per Order  
- Freight Cost %  

### Operational Metrics
- Seller Delay Rate  
- Regional Delivery Performance  

*Metric definitions will be refined in later phases.*

---

## Key Assumptions

- Delivery timestamps accurately reflect actual performance  
- Review scores are a valid proxy for customer satisfaction  
- Order-level aggregation is appropriate for business analysis  
- Seller-level performance can be derived from order data  

---

## Risks & Limitations

- Multi-item orders may introduce complexity in delivery measurement  
- Missing or inconsistent timestamps may affect delay calculations  
- External logistics factors are not directly captured in the dataset  
- Customer satisfaction may be influenced by factors beyond delivery  

---

## Output of This Phase
This phase delivers:

- Clear business problem definition  
- Structured analytical framework  
- Hypothesis-driven roadmap  
- Defined success metrics  

These outputs guide all subsequent phases of the project.

---

## Next Step
Proceed to **Part II – Data Infrastructure Setup**, where raw data will be ingested, validated, and structured for analysis.