# customers Table Documentation

**File:** `olist_customers_dataset.csv`  
**Layer:** Staging → Core (Customer Dimension Source)

---

## 1. Business Purpose

This table contains customer-level information associated with each order in the Olist marketplace.

It primarily supports:

- Customer segmentation
- Geographic distribution analysis
- Repeat purchase identification
- Joining customer location to order-level performance metrics

It does not contain revenue, seller, or delivery information.

---

## 2. Table Grain

**Grain Definition:**  
One row per `customer_id`.

Each row represents a customer record associated with a specific order event.

### Important clarification:

`customer_id` identifies a customer record linked to a specific order.

`customer_unique_id` identifies the real-world customer across multiple orders.

This means:

A single real-world customer may appear multiple times in this table.

---

## 3. Key Columns

| Column Name              | Description                           | Expected Behavior          |
| ------------------------ | ------------------------------------- | -------------------------- |
| customer_id              | Transaction-level customer identifier | Unique per row             |
| customer_unique_id       | Persistent customer identifier        | May repeat                 |
| customer_zip_code_prefix | Zip code prefix of customer           | Numeric but stored as text |
| customer_city            | Customer city name                    | Text                       |
| customer_state           | Brazilian state abbreviation          | 2-character code           |

---

## 4. Primary Key Expectation

**Expected Primary Key:** `customer_id`

### Assumption:

No duplicate `customer_id` values should exist.

`customer_unique_id` is not unique.

This will be validated after ingestion.

---

## 5. Analytical Implications

Because multiple `customer_id` values can map to the same `customer_unique_id`:

- Repeat purchase behavior must be calculated using `customer_unique_id`.
- Customer count for revenue exposure must distinguish between:
  - Total customer instances
  - Distinct real customers

Failure to respect this distinction will inflate customer metrics.

---

## 6. Data Engineering Notes

This table will be:

- Loaded into `staging.customers_raw` with all fields as NVARCHAR.
- Validated for uniqueness and null values.
- Converted into a typed `core.dim_customers` table.

## 7. Core Table Implementation

- Core table: `core.dim_customers`

- Primary Key: `customer_id`

- Supporting Index: `customer_unique_id`

- Row Count: `99,441`

- Distinct Real Customers: `96,096`

## 8. Relationships

- `customer_id` links to `core.orders.customer_id`
- Relationship: One customer → many orders

## 9. Data Quality Checks

- Verified no null values in `customer_id`
- Verified uniqueness of `customer_id`
- Validated distinct count of `customer_unique_id`

