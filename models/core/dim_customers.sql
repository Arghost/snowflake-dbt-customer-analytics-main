with customers as (
    select * 
    from {{ref ('stg_customers')}}
),
orders_agg as (
    select customer_id,
        count(order_id) as total_orders,
        min (created_at) as first_order_date,
        max (created_at) as last_order_date
    from {{ref ('stg_orders')}}
    group by customer_id
),
joined as (
    select 
        c.customer_id,
        c.first_name,
        c.last_name,
        o.total_orders,
        o.last_order_date,
        o.first_order_date
    from customers c
    left join orders_agg o
        on c.customer_id = o.customer_id
)
select * from joined
order by total_orders desc