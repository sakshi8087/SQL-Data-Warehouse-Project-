# SQL Data Warehouse Project

A data warehouse built on **SQL Server** using the **Medallion Architecture** (Bronze → Silver → Gold). Raw CRM and ERP CSV files are loaded, cleaned, standardised and finally modelled into a **Star Schema** for analytics and reporting.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Layer Descriptions](#layer-descriptions)
4. [Why Star Schema (and not Snowflake)?](#why-star-schema-and-not-snowflake)
5. [Project Structure](#project-structure)
6. [Prerequisites and Setup Checks](#prerequisites-and-setup-checks)
7. [Data Cleaning and Transformation](#data-cleaning-and-transformation)
8. [Data Quality Checks](#data-quality-checks)
9. [How to Run](#how-to-run)

---

## Project Overview

| Item | Details |
|------|---------|
| Database | Microsoft SQL Server |
| Sources | CRM and ERP (CSV files) |
| Architecture | Medallion (Bronze, Silver, Gold) |
| Final model | Star Schema (Fact + Dimension tables) |
| Goal | Clean, integrated, analytics-ready data |

---

## Architecture

```
 CSV Sources            Bronze                Silver                 Gold
┌────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────────┐
│ CRM files  │ ───▶ │  Raw data   │ ───▶ │ Cleaned &   │ ───▶ │ Star schema     │
│ ERP files  │      │ (as-is)     │      │ standardised│      │ (views/tables)  │
└────────────┘      └─────────────┘      └─────────────┘      └─────────────────┘
                     BULK INSERT          Transformations       Business-ready
```

---

## Layer Descriptions

### Bronze Layer: Raw Data

- **Purpose:** Store data exactly as it arrives from the source systems.
- **Source:** CSV files from CRM and ERP, loaded using `BULK INSERT`.
- **Transformations:** None. No cleaning, no business rules.
- **Load type:** Full load (truncate and insert).
- **Why keep it raw?** It gives full traceability and lets you reprocess data without going back to the source.

### Silver Layer: Cleaned and Standardised Data

- **Purpose:** Prepare data for analysis by fixing quality issues.
- **Source:** Bronze tables.
- **Typical transformations:**
  - Removing duplicates
  - Trimming unwanted spaces
  - Handling NULLs and invalid values
  - Standardising values (e.g. `M` → `Male`, `S` → `Single`)
  - Fixing data types and invalid dates
  - Deriving new columns and recalculating inconsistent values (e.g. sales, price)
  - Integrating related tables from CRM and ERP
- **Load type:** Full load (truncate and insert) via stored procedure.

### Gold Layer: Business-Ready Data

- **Purpose:** Provide data modelled for reporting, dashboards and analytics.
- **Source:** Silver tables.
- **Model:** Star Schema with dimension and fact objects (e.g. `dim_customers`, `dim_products`, `fact_sales`).
- **Transformations:** Joins, aggregations, surrogate keys and business logic.
- **Object type:** Views.

| | Bronze | Silver | Gold |
|---|--------|--------|------|
| Definition | Raw, unprocessed data | Cleaned, standardised data | Business-ready data |
| Object type | Tables | Tables | Views |
| Transformations | None | Heavy | Business logic and modelling |
| Data model | As-is from source | As-is from source | Star schema |
| Audience | Data engineers | Engineers and analysts | Analysts and BI users |

---

## Why Star Schema (and not Snowflake)?

### Star Schema

A central **fact table** (measurable events like sales) directly connected to **denormalised dimension tables** (customers, products, dates). The diagram looks like a star.

```
        dim_customers
              │
dim_products ─ fact_sales ─ dim_date
```

### Snowflake Schema

Dimensions are **normalised** into further sub-dimensions (e.g. `dim_products` → `dim_category` → `dim_subcategory`), so the diagram branches out like a snowflake.

### Comparison

| Feature | Star Schema | Snowflake Schema |
|---------|-------------|------------------|
| Structure | Fact joined directly to dimensions | Dimensions split into sub-dimensions |
| Normalisation | Denormalised | Normalised |
| Query complexity | Simple, fewer joins | Complex, more joins |
| Query performance | Faster | Slower due to extra joins |
| Storage | Slightly more (data redundancy) | Less redundancy |
| Maintenance | Easier to understand and maintain | More complex |
| Best for | Reporting and BI | Large, highly normalised dimensions |

### Why we chose Star Schema

- Simple and easy for analysts and BI tools (Power BI, Tableau) to understand.
- Fewer joins give faster query performance.
- Dataset size is small enough that the extra storage from denormalisation is not a concern.
- Easier to maintain and extend.

---

## Project Structure

```
dwh_project/
│
├── 01_datasets/
│   ├── source_crm/          # cust_info.csv, prd_info.csv, sales_details.csv
│   └── source_erp/          # CUST_AZ12.csv, LOC_A101.csv, PX_CAT_G1V2.csv
│
├── 02_scripts/
│   ├── init_database.sql    # Create database and schemas
│   ├── bronze/              # DDL and load scripts
│   ├── silver/              # DDL and load scripts
│   └── gold/                # Views for the star schema
│
├── 03_tests/                # Data quality checks
├── 04_docs/                 # Diagrams, data catalog, naming conventions
└── README.md
```

> Adjust the folder names above to match your repository.

---

## Prerequisites and Setup Checks

Before loading data with `BULK INSERT`, confirm that SQL Server can access the source files and that your login has the required permissions.

### 1. Check that the source file exists

```sql
EXEC master.sys.xp_fileexist 'C:\sql\dwh_project\01_datasets\source_crm\cust_info.csv';
```

Returns `File Exists = 1` if SQL Server can see the file. If it returns `0`, check the path and the SQL Server service account's folder permissions.

### 2. Check sysadmin permission

```sql
SELECT IS_SRVROLEMEMBER('sysadmin');
```

| Result | Meaning |
|--------|---------|
| `1` | You are a member of the `sysadmin` role |
| `0` | You are not a member of `sysadmin` |
| `NULL` | Invalid role name |

`sysadmin` (or the `ADMINISTER BULK OPERATIONS` permission) is needed for `BULK INSERT`.

---

## Data Cleaning and Transformation

Data was inspected in the Bronze layer to find quality issues, then fixed while loading into the Silver layer.

| Step | Layer | What was done |
|------|-------|---------------|
| 1 | Bronze | Inspected raw tables for duplicates, NULLs, unwanted spaces, invalid dates and inconsistent values |
| 2 | Silver | Applied the cleaning logic in transformation queries and loaded the cleaned data |
| 3 | Silver | Re-ran the same checks to confirm the issues were resolved |

### Issues found and how they were fixed

<!-- Replace or extend this table with the exact checks from your transformation file -->

| Table | Issue found in Bronze | Fix applied in Silver |
|-------|----------------------|------------------------|
| `crm_cust_info` | Duplicate customer IDs | Kept the latest record using `ROW_NUMBER()` |
| `crm_cust_info` | Unwanted spaces in names | Applied `TRIM()` |
| `crm_cust_info` | Abbreviated gender / marital status | Mapped to full values (`Male`, `Female`, `Married`, `Single`), `n/a` for unknown |
| `crm_prd_info` | NULL or negative cost | Replaced with `0` using `ISNULL()` |
| `crm_prd_info` | Combined product key | Split into category ID and product key |
| `crm_sales_details` | Invalid dates stored as integers | Converted to `DATE`, set invalid values to `NULL` |
| `crm_sales_details` | Sales or price inconsistent with quantity | Recalculated `sales = quantity * price` |
| `erp_cust_az12` | Extra prefix in customer ID, future birthdates | Removed prefix, set future dates to `NULL` |
| `erp_loc_a101` | Dashes in country/customer keys, inconsistent country codes | Removed dashes, normalised country names |

---

## Data Quality Checks

Quality checks were run twice: once on **Bronze** (to find problems) and again on **Silver** (to confirm the fixes). Each check should return **no rows** when the data is clean.

### Example checks

```sql
-- 1. Duplicates or NULLs in the primary key
SELECT cst_id, COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- 2. Unwanted spaces
SELECT cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

-- 3. Data standardisation and consistency
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info;

-- 4. Invalid date order
SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt;

-- 5. Business rule: sales = quantity * price
SELECT sls_sales, sls_quantity, sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL
   OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0;
```

### Validation summary

| Check | Bronze result | Silver result |
|-------|---------------|---------------|
| Duplicate primary keys | Issues found | Resolved |
| Unwanted spaces | Issues found | Resolved |
| Inconsistent categorical values | Issues found | Resolved |
| Invalid dates | Issues found | Resolved |
| Sales / quantity / price mismatch | Issues found | Resolved |

> Full queries are in `03_tests/` (or the transformation file included in this repository).

---

## How to Run

1. **Verify prerequisites** by running the [setup checks](#prerequisites-and-setup-checks).
2. **Create the database and schemas:** run `init_database.sql` (creates `bronze`, `silver`, `gold`).
3. **Bronze:** create tables, then run the load procedure.
   ```sql
   EXEC bronze.load_bronze;
   ```
4. **Silver:** create tables, then run the load procedure.
   ```sql
   EXEC silver.load_silver;
   ```
5. **Gold:** create the star schema views.
6. **Validate:** run the quality checks in `03_tests/`.

---

## Tools Used

- Microsoft SQL Server
- SQL Server Management Studio (SSMS)
- GitHub

## Author

**Your Name**
[LinkedIn](https://linkedin.com/in/your-profile) · [GitHub](https://github.com/your-username)
