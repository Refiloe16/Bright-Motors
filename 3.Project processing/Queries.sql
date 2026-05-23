--checking the first 100 columns
select * from `workspace`.`default`.`car_sales_data` limit 100;

---Check for duplicates first
SELECT vin, COUNT(*) AS cnt
FROM `workspace`.`default`.`car_sales_data`
GROUP BY vin
HAVING COUNT(*) > 1
ORDER BY cnt DESC;

---duplicates exist, create deduplicated view
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY vin ORDER BY saledate DESC) AS rn
    FROM `workspace`.`default`.`car_sales_data`
) t
WHERE rn = 1;

--- Revenue & Volume by Car Make (Top 15)
SELECT
    make,
    COUNT(*)                          AS units_sold,
    ROUND(SUM(sellingprice), 2)      AS total_revenue,
    ROUND(AVG(sellingprice), 2)      AS avg_selling_price
FROM `workspace`.`default`.`car_sales_data`
WHERE sellingprice IS NOT NULL
GROUP BY make
ORDER BY total_revenue DESC
LIMIT 15;

---Top 20 Models by Revenue
SELECT
    make,
    model,
    COUNT(*)                          AS units_sold,
    ROUND(SUM(sellingprice), 2)      AS total_revenue,
    ROUND(AVG(sellingprice), 2)      AS avg_selling_price
FROM `workspace`.`default`.`car_sales_data`
WHERE sellingprice IS NOT NULL
GROUP BY make, model
ORDER BY total_revenue DESC
LIMIT 20;

---Sales by State (Regional Performance)
SELECT
    state,
    COUNT(*)                          AS units_sold,
    ROUND(SUM(sellingprice), 2)      AS total_revenue,
    ROUND(AVG(sellingprice), 2)      AS avg_selling_price
FROM `workspace`.`default`.`car_sales_data`
WHERE sellingprice IS NOT NULL AND state IS NOT NULL
GROUP BY state
ORDER BY total_revenue DESC;

---Sales Trend by Year (manufacture year)
SELECT
    year                              AS manufacture_year,
    COUNT(*)                          AS units_sold,
    ROUND(SUM(sellingprice), 2)      AS total_revenue,
    ROUND(AVG(sellingprice), 2)      AS avg_selling_price,
    ROUND(AVG(odometer), 0)           AS avg_odometer
FROM `workspace`.`default`.`car_sales_data`
WHERE sellingprice IS NOT NULL
GROUP BY year
ORDER BY year DESC;

--- Derived time fields
SELECT
    YEAR(TO_DATE(REGEXP_REPLACE(saledate, '^\\w+\\s', ''), 'MMM dd yyyy HH:mm:ss'))    AS sale_year,
    MONTH(TO_DATE(REGEXP_REPLACE(saledate, '^\\w+\\s', ''), 'MMM dd yyyy HH:mm:ss'))   AS sale_month,
    QUARTER(TO_DATE(REGEXP_REPLACE(saledate, '^\\w+\\s', ''), 'MMM dd yyyy HH:mm:ss')) AS sale_quarter
FROM `workspace`.`default`.`car_sales_data`
WHERE     -- Remove obviously bad years
     year BETWEEN 1990 AND 2025;

---Sales Trend by Sale Date (month-year)
SELECT
    YEAR(TO_DATE(REGEXP_REPLACE(saledate, '^\\w+\\s', ''), 'MMM dd yyyy HH:mm:ss'))    AS sale_year,
    MONTH(TO_DATE(REGEXP_REPLACE(saledate, '^\\w+\\s', ''), 'MMM dd yyyy HH:mm:ss'))   AS sale_month,
    COUNT(*)                          AS units_sold,
    ROUND(SUM(sellingprice), 2)      AS total_revenue,
    ROUND(AVG(sellingprice), 2)      AS avg_selling_price
FROM `workspace`.`default`.`car_sales_data`
WHERE sellingprice IS NOT NULL AND saledate IS NOT NULL
GROUP BY sale_year, sale_month
ORDER BY sale_year, sale_month;

---Sales by Quarter
SELECT
    YEAR(TO_DATE(REGEXP_REPLACE(saledate, '^\\w+\\s', ''), 'MMM dd yyyy HH:mm:ss'))    AS sale_year,
    QUARTER(TO_DATE(REGEXP_REPLACE(saledate, '^\\w+\\s', ''), 'MMM dd yyyy HH:mm:ss')) AS sale_quarter,
    COUNT(*)                          AS units_sold,
    ROUND(SUM(sellingprice), 2)      AS total_revenue
FROM `workspace`.`default`.`car_sales_data`
WHERE sellingprice IS NOT NULL AND saledate IS NOT NULL
GROUP BY sale_year, sale_quarter
ORDER BY sale_year, sale_quarter;

---Body Style Popularity & Revenue
SELECT
    body,
    COUNT(*)                          AS units_sold,
    ROUND(SUM(sellingprice), 2)      AS total_revenue,
    ROUND(AVG(sellingprice), 2)      AS avg_selling_price
FROM `workspace`.`default`.`car_sales_data`
WHERE sellingprice IS NOT NULL AND body IS NOT NULL
GROUP BY body
ORDER BY total_revenue DESC;
 
--- Transmission Type Breakdown
SELECT
    transmission,
    COUNT(*)                          AS units_sold,
    ROUND(AVG(sellingprice), 2)      AS avg_selling_price
FROM `workspace`.`default`.`car_sales_data`
WHERE sellingprice IS NOT NULL AND transmission IS NOT NULL
GROUP BY transmission
ORDER BY units_sold DESC;
 
------------------------------------------------------------------------------------
---BIG_QUERY
-------------------------------------------------------------------------------------
SELECT
    --- IDENTIFIERS
    UPPER(TRIM(vin))                                        AS vin,
 
    --- NUMERIC CASTS 
    CAST(year AS INT)                                       AS car_year,
 
    CASE
        WHEN odometer IS NULL OR TRIM(odometer) IN ('', '—', '-') THEN NULL
        WHEN CAST(odometer AS INT) = 0                            THEN NULL
        ELSE CAST(REGEXP_REPLACE(CAST(odometer AS STRING), '[^0-9.]', '')
      AS DOUBLE)
    END                                                     AS odometer,
 
    CASE
        WHEN sellingprice IS NULL OR TRIM(sellingprice) = '' THEN NULL
        WHEN CAST(
               REGEXP_REPLACE(sellingprice, '[^0-9.]', '')
             AS DOUBLE) <= 0                                THEN NULL
        ELSE CAST(REGEXP_REPLACE(sellingprice, '[^0-9.]', '') AS DOUBLE)
    END                                                     AS selling_price,
        COUNT(*)                                    AS units_sold,
    ROUND(SUM(sellingprice), 2)                AS total_revenue,
    ROUND(AVG(sellingprice), 2)                AS avg_selling_price,
    CASE
        WHEN mmr IS NULL OR TRIM(mmr) = '' THEN NULL
        WHEN CAST(REGEXP_REPLACE(mmr, '[^0-9.]', '') AS DOUBLE) <= 0 THEN NULL
        ELSE CAST(REGEXP_REPLACE(mmr, '[^0-9.]', '') AS DOUBLE)
    END                                                     AS mmr,
       CAST(
      REGEXP_REPLACE(CAST(condition AS STRING), '[^0-9.]', '')
      AS DOUBLE
    )                                                        AS condition_score,
  
 
        CASE
      WHEN condition_score >= 40 THEN 'Excellent'
      WHEN condition_score >= 30 THEN 'Good'
      WHEN condition_score >= 20 THEN 'Fair'
      ELSE                            'Poor'
    END                                                      AS condition_tier,

 
    ---TEXT STANDARDISATION 
    INITCAP(TRIM(make))                                     AS make,
    INITCAP(TRIM(model))                                    AS model,
    TRIM(trim)                                              AS trim_level,
    INITCAP(TRIM(body))                                     AS body_style,
    INITCAP(TRIM(transmission))                             AS transmission,
    UPPER(TRIM(state))                                      AS region,
    LOWER(TRIM(seller))                                     AS seller,

        CASE
      WHEN LOWER(transmission) LIKE '%electric%'  THEN 'Electric'
      WHEN LOWER(transmission) LIKE '%hybrid%'    THEN 'Hybrid'
      WHEN LOWER(body_style)   LIKE '%electric%'  THEN 'Electric'
      ELSE 'Petrol/Diesel'
    END                                                      AS fuel_type,

    -- Nullify dashes in colour fields
    CASE
        WHEN TRIM(color)    IN ('—', '-', '', 'null') THEN NULL
        ELSE TRIM(color)
    END                                                     AS color,
    CASE
        WHEN TRIM(interior) IN ('—', '-', '', 'null') THEN NULL
        ELSE TRIM(interior)
    END                                                     AS interior_color,
 
    ---DATE PARSING 
    TO_DATE(
        REGEXP_REPLACE(TRIM(saledate), '^[A-Za-z]+\\s', ''),
        'MMM dd yyyy HH:mm:ss'
    )                                                       AS sale_date,
 
    YEAR(TO_DATE(
        REGEXP_REPLACE(TRIM(saledate), '^[A-Za-z]+\\s', ''),
        'MMM dd yyyy HH:mm:ss'
    ))                                                      AS sale_year,
 
    MONTH(TO_DATE(
        REGEXP_REPLACE(TRIM(saledate), '^[A-Za-z]+\\s', ''),
        'MMM dd yyyy HH:mm:ss'
    ))                                                      AS sale_month,
 
    QUARTER(TO_DATE(
        REGEXP_REPLACE(TRIM(saledate), '^[A-Za-z]+\\s', ''),
        'MMM dd yyyy HH:mm:ss'
    ))                                                      AS sale_quarter,
 
    --- CALCULATED COLUMNS 
    CASE
        WHEN CAST(REGEXP_REPLACE(sellingprice, '[^0-9.]', '') AS DOUBLE) > 0
         AND CAST(REGEXP_REPLACE(mmr,          '[^0-9.]', '') AS DOUBLE) > 0
        THEN ROUND(
            (
              CAST(REGEXP_REPLACE(sellingprice, '[^0-9.]', '') AS DOUBLE) -
              CAST(REGEXP_REPLACE(mmr,          '[^0-9.]', '') AS DOUBLE)
            ) /
            CAST(REGEXP_REPLACE(sellingprice,   '[^0-9.]', '') AS DOUBLE)
            * 100,
        2)
        ELSE NULL
    END                                                     AS profit_margin_pct,
 
    -- Absolute gap between selling price and market value
    CASE
        WHEN CAST(REGEXP_REPLACE(sellingprice, '[^0-9.]', '') AS DOUBLE) > 0
         AND CAST(REGEXP_REPLACE(mmr,          '[^0-9.]', '') AS DOUBLE) > 0
        THEN ROUND(
            CAST(REGEXP_REPLACE(sellingprice, '[^0-9.]', '') AS DOUBLE) -
            CAST(REGEXP_REPLACE(mmr,          '[^0-9.]', '') AS DOUBLE),
        2)
        ELSE NULL
    END                                                     AS price_vs_market,
 
    -- Performance tier
    CASE
        WHEN CAST(REGEXP_REPLACE(sellingprice, '[^0-9.]', '') AS DOUBLE) > 0
         AND CAST(REGEXP_REPLACE(mmr,          '[^0-9.]', '') AS DOUBLE) > 0
        THEN
            CASE
                WHEN (
                    (CAST(REGEXP_REPLACE(sellingprice, '[^0-9.]', '') AS DOUBLE) -
                     CAST(REGEXP_REPLACE(mmr,          '[^0-9.]', '') AS DOUBLE)) /
                     CAST(REGEXP_REPLACE(sellingprice, '[^0-9.]', '') AS DOUBLE)
                ) * 100 >= 10 THEN 'High Margin'
                WHEN (
                    (CAST(REGEXP_REPLACE(sellingprice, '[^0-9.]', '') AS DOUBLE) -
                     CAST(REGEXP_REPLACE(mmr,          '[^0-9.]', '') AS DOUBLE)) /
                     CAST(REGEXP_REPLACE(sellingprice, '[^0-9.]', '') AS DOUBLE)
                ) * 100 >= 0  THEN 'Medium Margin'
                ELSE 'Low Margin'
            END
        ELSE 'Unknown'
    END                                                     AS margin_tier,
 
    -- Car age at time of sale
    CASE
        WHEN CAST(year AS INT) BETWEEN 1990 AND 2025
        THEN YEAR(TO_DATE(
                REGEXP_REPLACE(TRIM(saledate), '^[A-Za-z]+\\s', ''),
                'MMM dd yyyy HH:mm:ss'
             )) - CAST(year AS INT)
        ELSE NULL
    END                                                     AS car_age_at_sale,
 
    -- Mileage band for grouping
    CASE
        WHEN CAST(odometer AS INT) < 10000                  THEN '1. Under 10k'
        WHEN CAST(odometer AS INT) < 30000                  THEN '2. 10k–30k'
        WHEN CAST(odometer AS INT) < 60000                  THEN '3. 30k–60k'
        WHEN CAST(odometer AS INT) < 100000                 THEN '4. 60k–100k'
        ELSE                                                     '5. 100k+'
    END                                                     AS mileage_band
 
FROM `workspace`.`default`.`car_sales_data`
WHERE
    CAST(year AS INT) BETWEEN 1990 AND 2025
    AND CAST(REGEXP_REPLACE(sellingprice, '[^0-9.]', '') AS DOUBLE) > 0
    AND vin IS NOT NULL
    AND TRIM(vin) != ''
    AND sellingprice IS NOT NULL
GROUP BY make,
         vin,
         year,
         odometer,
         sellingprice,
         mmr,
         CASE
        WHEN mmr IS NULL OR TRIM(mmr) = '' THEN NULL
        WHEN CAST(REGEXP_REPLACE(mmr, '[^0-9.]', '') AS DOUBLE) <= 0 THEN NULL
        ELSE CAST(REGEXP_REPLACE(mmr, '[^0-9.]', '') AS DOUBLE)
    END,
    condition,
     CASE
      WHEN condition_score >= 40 THEN 'Excellent'
      WHEN condition_score >= 30 THEN 'Good'
      WHEN condition_score >= 20 THEN 'Fair'
      ELSE                            'Poor'
    END,
    model,
    trim,
    body,
    transmission,
    color,
    interior,
    saledate,
    CASE
        WHEN saledate IS NULL OR TRIM(saledate) = '' THEN NULL
        ELSE TO_DATE(REGEXP_REPLACE(TRIM(saledate), '^[A-Za-z]+\\s', ''), 'MMM dd yyyy HH:mm:ss')
    END,
    CASE
        WHEN TRIM(saledate) IS NULL OR TRIM(saledate) = '' THEN NULL
        ELSE YEAR(TO_DATE(REGEXP_REPLACE(TRIM(saledate), '^[A-Za-z]+\\s', ''), 'MMM dd yyyy HH:mm:ss'))
    END,
    CASE
        WHEN TRIM(saledate) IS NULL OR TRIM(saledate) = '' THEN NULL
        ELSE MONTH(TO_DATE(REGEXP_REPLACE(TRIM(saledate), '^[A-Za-z]+\\s', ''), 'MMM dd yyyy HH:mm:ss'))
    END,
    CASE
        WHEN TRIM(saledate) IS NULL OR TRIM(saledate) = '' THEN NULL
        ELSE DAY(TO_DATE(REGEXP_REPLACE(TRIM(saledate), '^[A-Za-z]+\\s', ''), 'MMM dd yyyy HH:mm:ss'))
    END,
    state ,
    seller 
ORDER BY total_revenue DESC;
