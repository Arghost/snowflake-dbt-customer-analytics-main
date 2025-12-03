WITH source AS (
    SELECT * 
    FROM {{ source('jaffle_shop', 'orders') }}
),
customers AS (
    SELECT customer_id
    FROM {{ ref('stg_customers') }}
),
cleaned AS (
    SELECT
        id AS order_id,
        user_id AS customer_id,
        cast(order_date as date) AS created_at,
        cast(_etl_loaded_at as timestamp) as last_updated_at
    FROM source
    WHERE order_id IS NOT NULL
      AND customer_id IN (SELECT customer_id FROM customers)
)

SELECT *
FROM cleaned