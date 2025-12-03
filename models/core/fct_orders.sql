with orders as (
    select *
    from {{ref ('stg_orders')}}
),
payments_agg as (
    select 
        order_id,
        sum(amount) as total_paid,
        from {{ref ('stg_payment')}}
        group by order_id
),
joined as (
    select
        o.order_id,
        o.customer_id,
        o.created_at,
        pa.total_paid
    from orders o
    left join payments_agg pa
    on o.order_id = pa.order_id
)

select * from joined