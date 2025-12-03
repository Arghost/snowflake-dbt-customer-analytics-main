with customers as (
    select * 
    from {{ref ('dim_customers')}}
),
orders_aggr as (
    select 
        customer_id,
        count(*) as total_orders,
        sum(total_paid) as total_revenue
    from {{ref ('fct_orders')}}
    group by customer_id
),
joined as (
    select 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.total_orders,
        c.first_order_date,
        c.last_order_date,
        o.total_revenue
    from customers c
    left join orders_aggr o
    on c.customer_id = o.customer_id
)
select * from joined