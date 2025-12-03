WITH source AS (
    SELECT * 
    FROM {{ source('jaffle_shop', 'customers') }}    
)
,cleaned AS (
        SELECT
            id AS customer_id,
            first_name AS first_name,
            last_name AS last_name,
        FROM source
        WHERE id IS NOT NULL
    )

select * from cleaned