with
source as (
    select * from {{ source('stripe', 'payment') }}
),
orders AS (
    SELECT order_id
    FROM {{ ref('stg_orders') }}
),
cleaned as (
    select
        id as payment_id,
        orderid as order_id,
        paymentmethod as payment_method,
        status,
        CAST(amount AS DOUBLE PRECISION) as amount,
        cast(created as date) as payment_date,
        cast(_batched_at as timestamp) as last_updated_at
    from source 
    WHERE payment_id IS NOT NULL and order_id is not null
      AND order_id IN (SELECT order_id FROM orders)
)

select * from cleaned