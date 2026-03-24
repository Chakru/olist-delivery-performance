# Part II – Data Infrastructure Execution Guide

## Overview

This section builds the data infrastructure layer of the Olist E-Commerce project.
It includes data ingestion, validation, and loading into a structured relational schema.

---

## Prerequisites

* SQL Server installed (SSMS recommended)
* Access to the dataset files
* Update file paths in SQL script if needed

---

## Folder Structure

Ensure datasets are placed under:

```
/01_Raw_Data/
```

---

## Execution Steps

1. Open the SQL file:

```
/sql/01_data_ingestion_and_validation.sql
```

2. Ensure BULK INSERT file paths are updated before execution

3. Execute the script sequentially (top to bottom)

4. Ensure the correct database context (`Olist_Operations_Analysis`) is selected before execution 

---

## What This Script Does

### 1. Database Setup

* Creates database: `Olist_Operations_Analysis`
* Creates schemas:

  * staging
  * core
  * analytics

---

### 2. Staging Layer

* Loads raw CSV data into staging tables
* All columns stored as NVARCHAR

---

### 3. Data Validation

* Null checks
* Duplicate checks
* Timestamp validation
* Referential integrity checks

---

### 4. Core Layer

* Converts data types using TRY_CONVERT
* Creates primary and foreign keys
* Loads cleaned data into structured tables

---

### 5. Special Handling

* Reviews dataset:

  * CSV parsing handled using FORMAT = 'CSV'
  * Deduplication using ROW_NUMBER()
  * Orphan records removed via INNER JOIN

* Geolocation dataset:

  * Aggregated into zip-level reference view

---

## Output

After execution, the following layers are available:

* staging → raw data
* core → cleaned structured tables
* analytics → aggregated reference data

This structured layering enables controlled data transformation and ensures data quality before analytical processing.

---

## Notes

* Always execute script in order
* Do not modify raw data manually
* Data cleaning is handled inside SQL pipeline

---

## Next Step

Proceed to:

**Part III – Data Preparation & Feature Engineering**

This will build the central analytical dataset.
