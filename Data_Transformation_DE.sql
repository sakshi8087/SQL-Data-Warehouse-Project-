SELECT name FROM DataWarehouse.sys.schemas
WHERE name IN ('bronze', 'silver', 'gold');


--Bronze
SELECT TABLE_SCHEMA, TABLE_NAME
FROM DataWarehouse.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'bronze';


  SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,       -- Extract category ID
            SUBSTRING(prd_key, 7, LEN(prd_key))         AS prd_key,      -- Extract product key
            prd_nm,
            ISNULL(prd_cost, 0)                         AS prd_cost,
            CASE
                WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
                WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
                WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
                WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
                ELSE 'n/a'
            END                                         AS prd_line,     -- Map product line codes to descriptive values
            CAST(prd_start_dt AS DATE)                  AS prd_start_dt,
            CAST(
                LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1
                AS DATE
            ) AS prd_end_dt -- Calculate end date as one day before the next start date
        FROM bronze.crm_prd_info;

select * from bronze.erp_px_cat_g1v2;

select * from bronze.crm_cust_info where cst_id =29449 order by cst_create_date DESC;
--check for uniquness of cust id 
select cst_id, count(*) 
from bronze.crm_cust_info
group by cst_id
having count(*) > 1 OR cst_id is null;


 SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname)  AS cst_lastname,
            CASE
                WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                ELSE 'n/a'
            END                 AS cst_marital_status, -- Normalize marital status values to readable format
            CASE
                WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                ELSE 'n/a'
            END                 AS cst_gndr,           -- Normalize gender values to readable format
            cst_create_date
        FROM (
            SELECT
                *,
                ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) t
        WHERE flag_last = 1
---
select  cst_gndr, count(*) as null_rows from bronze.crm_cust_info
where cst_gndr is null
group by cst_gndr;

--
select cst_key, count(*) 
from bronze.crm_cust_info
group by cst_key
having count(*) > 1 OR cst_key is null;



select sum(case when cst_firstname is null then 1 else 0 end) as fname_null,
       sum(case when cst_lastname is null then 1 else 0 end) as lname_null,
       sum(case when cst_create_date is null then 1 else 0 end) as create_date_null
from bronze.crm_cust_info;



---crm_prd_info
select * from bronze.erp_px_cat_g1v2;  -- id as AC-HE-HL-U509-R
select prd_id, prd_key, SUBSTRING(prd_key,1,5) as cat_id  from bronze.crm_prd_info; -- id as AC_BR


select prd_start_dt, prd_end_dt,
       cast(lead(prd_start_dt) over(partition by prd_key order by prd_start_dt ) -1 as date) 
       from bronze.crm_prd_info where prd_key='AC-HE-HL-U509-B';; -- we can see prd_cost has some null values, prd_end_dt also contain some null dates

--here for this prd_key you can see start_dt > end_dt for example 2011/7/1 > 2007/12/28 
--start should be smaller than end as well as end date of the first history should be younger than start date of the next record
--It's okay to have end date as null because which shows the current record of that product
select * from bronze.crm_prd_info where prd_key='AC-HE-HL-U509-B';


select * from bronze.crm_prd_info  where prd_key='AC-HE-HL-U509-B';
select prd_key, count(*) from bronze.crm_prd_info group by prd_key having count(*) > 1;



select * from bronze.crm_prd_info;

---crm_sales_details
select * from bronze.crm_sales_details;
select sum(case when sls_prd_key is null then 1 else 0 end) as sls_prd_key_null,
       sum(case when sls_cust_id is null then 1 else 0 end) as sls_cust_id_null,
       sum(case when sls_ord_num is null then 1 else 0 end) as sls_prd_key
from bronze.crm_sales_details;


--there are no duplicates found in keys and order num 
select sls_ord_num, count(*) as dyplicate_count
from bronze.crm_sales_details
group by sls_ord_num
having count(*) > 1;

select * from bronze.crm_sales_details where sls_ord_num='SO55367';

--we need to recalculate the sls_sales because we have null , 0 values in sales also in sls_price we have negative value 
select * from bronze.crm_sales_details
where abs(sls_quantity) * sls_price <> sls_sales OR sls_sales is null OR sls_sales <=0

--dates are not date format, but while casting it as date it shows an error "Explicit conversion from data type int to date is not allowed."
-- we need to cast to varchar then to date
select CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) from bronze.crm_sales_details
where sls_order_dt != 0 OR LEN(sls_order_dt) = 8 ;


--silver
SELECT TABLE_SCHEMA, TABLE_NAME
FROM DataWarehouse.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'silver';

select * from silver.crm_prd_info;
select * from bronze.crm_prd_info;



select cst_id, count(*) 
from silver.crm_cust_info
group by cst_id
having count(*) > 1 OR cst_id is null;

select cst_key
from silver.crm_cust_info
where cst_key != trim(cst_key);

select distinct cst_marital_status 
from silver.crm_cust_info;

select sum(case when cst_create_date is null then 1 else 0 end) as create_date_null,
       sum(case when cst_key is null then 1 else 0 end) as create_key_null
from silver.crm_cust_info;

erp_cust_az12
erp_px_cat_g1v2

select * from silver.erp_cust_az12;
--out of range date checking

select bdate
from silver.erp_cust_az12
where bdate > '1986-06-25' OR bdate > getdate();

select min(bdate), max(bdate) from silver.erp_cust_az12;

select distinct gen from silver.erp_cust_az12;

--erp cat csv
select distinct subcat from silver.erp_px_cat_g1v2;

select distinct maintenance from silver.erp_px_cat_g1v2;

select distinct cat from silver.erp_px_cat_g1v2;

select * from silver.erp_px_cat_g1v2
where cat != trim(cat) OR subcat != trim(subcat) OR maintenance != trim(maintenance);




select top 5 * from silver.crm_sales_details;