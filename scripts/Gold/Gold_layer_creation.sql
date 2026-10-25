

--we try to avoid using inner join because if other table does not have all the information about the customer, we might loose the customer
--After joining table, check if any duplicates were introduced by the join logic
--There are no duplicate values 
select cst_id, count(*) from
(select ci.cst_id,cst_key, 
       ci.cst_firstname,
       ci.cst_lastname,
       ci.cst_marital_status,
       ci.cst_gndr,
       ci.cst_create_date,
       ca.bdate,
       ca.gen,
       la.cntry
from silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid) t
group by cst_id
having count(*) > 1;

select * from silver.crm_cust_info;
select * from silver.erp_cust_az12;
select * from silver.erp_loc_a101;

-------------------------------------------------------------------

select ci.cst_id,
       ci.cst_key, 
       ci.cst_firstname,
       ci.cst_lastname,
       ci.cst_marital_status,
       ci.cst_gndr,
       ci.cst_create_date,
       ca.bdate,
       ca.gen,
       la.cntry
from silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key = la.cid;

--why ca.gen, ci.cst_gndr
select distinct ci.cst_gndr,
                ca.gen
from silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
order by 1, 2;
--Most table giving different information
--Female	Male
--Female	n/a
--Male	Female
--Also had null values -- null often come from joined tables !null will appear if sql finds no match
--We need to ask expert here what is master is that CRM or ERP system -- which source is the master for these values?
--the master source of customer data is CRM!
--solution 
select distinct ci.cst_gndr,
                ca.gen,
        case when ci.cst_gndr != 'n/a' then ci.cst_gndr
             else coalesce(ca.gen, 'n/a')
        end as new_gen
from silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key = ca.cid
order by 1, 2;

--Updating the exiting query
--Naming the columns
--We need to define the primary key in order to connect our data model
--
create view dim_customer as
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


--dim_product

select * from silver.crm_prd_info;
select * from silver.erp_px_cat_g1v2;

--No duplicates 
select prd_key, count(*) from 
(select 
       pn.prd_id,
       pn.cat_id,
       pn.prd_key,
       pc.cat,
       pc.subcat,
       pn.prd_nm,
       pn.prd_cost,
       pn.prd_line,
       pc.maintenance,
       pn.prd_start_dt,
       pn.prd_end_dt
from silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id =pc.id
where pn.prd_end_dt is null) t -- filter out all historical data 
group by prd_key
having count(*) > 1;

--Naming columns 
--rearrange the columns for better readbility 

create view dim.products as 
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


--Sales Fact table -- we have keys, dates and measures
--Use the dimension's surrogate keys instead of IDs to easily connect facts with dimensions

select * from silver.crm_sales_details;

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
ON sd.sls_prod_key = pr.product_number
LEFT JOIN gold.dim_customers cu
ON sd.sls_cust_id = cu.customer_id;


--Testing 

select customer_key from gold.dim_customers;

select * from gold.dim_products;

--check all dimension tables can successfully join to the fact table
--The purpose is to check whether every sales record successfully connects to a customer dimension record
select *
from gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p 
ON p.product_key = f.product_key 
where c.customer_key is null;

--Relationship
--In a start schema, the relationship between fact and dim is 1 to N 
--primary key from customer table is customer_key
--primary key from product table is product key
--we have two foriegn key in fact sales table - product_key and customer_key whih used to join dim tables


--Data Catalog
--we have data model which we called as data products and we will be sharing this product with different types of users
--data catalog which needs by every data model, to describe everything about your data model the col the tables 


