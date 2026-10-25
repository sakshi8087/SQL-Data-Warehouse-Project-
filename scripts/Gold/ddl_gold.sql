/*

===========================================================
DDL Script : create gold views
==========================================================
script purpose:
            this script views for the gold layer in the data warehouse.
            the gold layer represents the final dim and fact tables(star schema)

            Each view performs transformations and combines data from the silver layer.
            to produce a clean and business-ready dataset.

===========================================================

*/

--==========================================================
--Create dimentions : gold.dim_customers
--============================================================

if OBJECT_ID('gold.dim_customers', 'v') is not null
    drop view gold.dim_customers;
Go

create view gold.dim_customers as
select row_number() over(order by cst_id ) as Customer_key,-- surrogate key which created to connect data model
       ci.cst_id as customer_id,
       cst_key as customer_number, 
       ci.cst_firstname as first_name,
       ci.cst_lastname as last_name,
       la.cntry as country,
       ci.cst_marital_status as marital_status,
        case when ci.cst_gndr != 'n/a' then ci.cst_gndr
             else coalesce(ca.gen, 'n/a')
        end as gender, -- CRM is the aster for gender 
          ca.bdate as birthdate,
       ci.cst_create_date as create_date 
from silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid;

GO

--=============================================================
--Create Dimention : dim_products
--============================================================
IF object_id('gold.dim_products', 'v') is not null
   drop view gold.dim_products;
GO

create view gold.dim_products as 
select 
       row_number() over(order by pn.prd_start_dt, pn.prd_key) as product_key,
       pn.prd_id as product_id,
       pn.prd_key as product_number,
       pn.prd_nm as product_name,
       pn.cat_id as category_id,
       pc.cat as category_name,
       pc.subcat as subcategory_name,
       pc.maintenance,
       pn.prd_cost as cost,
       pn.prd_line as product_line,
       pn.prd_start_dt as start_date
from silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id =pc.id
where pn.prd_end_dt is null; -- filter out historical data 

GO


--===========================================================
--create Fact : fact_sales
--==========================================================

IF object_id('gold.fact_sales', 'v') IS NOT NULL
   DROP VIEW gold.fact_sales;
GO 
create view gold.fact_sales AS  
select sd.sls_ord_num as order_num,
       pr.product_key ,
       cu.customer_key,
       sd.sls_order_dt as order_date,
       sd.sls_ship_dt as shipping_date,
       sd.sls_due_dt as due_date,
       sd.sls_sales as sales_amount,
       sd.sls_quantity as quantity,
       sd.sls_price as price
from silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
ON sd.sls_cust_id = cu.customer_id;

GO
