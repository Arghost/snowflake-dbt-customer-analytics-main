# Customer & Revenue Analytics Accelerator

### Snowflake + dbt project

This repository contains a small but realistic **modern analytics stack** using:

- **Snowflake** as the cloud data warehouse
- **dbt** as the transformation and data modeling framework
- A simple **Customer & Orders** domain (Jaffle Shop + Stripe sample data)

The goal is to demonstrate how to go from **raw operational data** to **analytics-ready data marts**, using software engineering practices (version control, tests, documentation, lineage) that are now standard in modern data teams.

---

## 1. Business context & use case

Imagine a digital / e-commerce client that wants to answer questions like:

- Who are my **most valuable customers**?
- How many **orders** do we get by customer?
- What is the **total revenue** per customer?
- When did each customer make their **first** and **last** purchase?

This project implements a **Customer & Revenue Analytics Accelerator**:

- Raw order and payment data is loaded into **Snowflake**.
- **dbt** cleanly models that data in layers:
  - **Staging** for cleaned, standardized sources
  - **Core** for dimensional & fact models
  - **Marts** for BI-ready tables with business KPIs

---

## 2. High-level architecture

```text
               ┌───────────────────────────────────┐
               │            Source systems         │
               │    (Jaffle Shop, Stripe sample)   │
               └───────────────────────────────────┘
                              │
                              │  (Load / Ingest - outside dbt)
                              ▼
                    ┌─────────────────────┐
                    │   Snowflake RAW     │
                    │  RAW_DB.JAFFLE_SHOP │
                    │  RAW_DB.STRIPE      │
                    └─────────────────────┘
                              │
                              │  (dbt: models, tests, docs)
                              ▼
                    ┌─────────────────────┐
                    │  Snowflake ANALYTICS│
                    │  dbt models         │
                    │  (STAGING → CORE →  │
                    │        MARTS)       │
                    └─────────────────────┘
                              │
                              │  (BI / notebooks)
                              ▼
             ┌─────────────────────────────────────┐
             │ Power BI / Tableau / Looker / etc. │
             └─────────────────────────────────────┘
```

---

## 3. Data modeling layers

The project uses a classic layered approach:

### 3.1 RAW (outside of dbt)

Raw tables are loaded into:

- `RAW_DB.JAFFLE_SHOP.customers`
- `RAW_DB.JAFFLE_SHOP.orders`
- `RAW_DB.STRIPE.payment`

These are **not** controlled by dbt. They are the starting point for transformations.

---

### 3.2 STAGING (`stg_*` models)

**Goal:** Clean and standardize source data into a consistent shape.

Location: `models/staging/`

Main models:

- `stg_customers`
  - Reads from `source('jaffle_shop', 'customers')`
  - Standardizes column names (`customer_id`, `first_name`, `last_name`, etc.)
  - Ensures a clean, unique `customer_id`

- `stg_orders`
  - Reads from `source('jaffle_shop', 'orders')`
  - Renames `id` → `order_id`, standardizes `customer_id`, casts dates
  - Optionally filters out invalid or test orders

- `stg_payments`
  - Reads from `source('stripe', 'payment')`
  - Standardizes `payment_id`, `order_id`, amounts and timestamps
  - Prepares payment data so it can be joined to orders

**Example tests (YAML):**

- `stg_customers.customer_id` → `unique`, `not_null`
- `stg_orders.order_id` → `unique`, `not_null`
- `stg_payments.payment_id` → `unique`, `not_null`

---

### 3.3 CORE (`dim_` and `fct_` models)

**Goal:** Represent the business in dimensional models and facts.

Location: `models/core/`

Main models:

- `dim_customers`
  - Grain: **1 row per `customer_id`**
  - Source: `stg_customers` + aggregated orders from `stg_orders`
  - Typical fields:
    - `customer_id`
    - `first_name`, `last_name`, `email`
    - `first_order_date`, `last_order_date`
    - `total_orders` (if aggregated here or in a mart)

- `fct_orders`
  - Grain: **1 row per `order_id`**
  - Source: `stg_orders` + aggregated payments from `stg_payments`
  - Typical fields:
    - `order_id`, `customer_id`
    - `order_created_at`
    - `total_paid`, `payments_count` (from payments aggregation)

**Example tests (YAML):**

- `dim_customers.customer_id`
  - `unique`, `not_null`
- `fct_orders.order_id`
  - `unique`, `not_null`
- `fct_orders.customer_id`
  - `not_null`
  - `relationships` → must exist in `dim_customers.customer_id`

This ensures **referential integrity** between facts and dimensions and catches data quality issues early.

---

### 3.4 MARTS (`mrt_*` models)

**Goal:** BI-ready tables for direct consumption by dashboards.

Location: `models/marts/`

Example mart:

- `mrt_customer_kpis`
  - Grain: **1 row per `customer_id`**
  - Sources: `dim_customers` and `fct_orders`
  - Typical fields:
    - Customer attributes (name, email, etc.)
    - Behavioral KPIs:
      - `total_orders`
      - `total_revenue`
      - `first_order_date`
      - `last_order_date`

This is the table that a BI tool (Power BI, Tableau, Looker) can connect to directly without complex joins.

---

## 4. Why dbt on Snowflake (vs. “just SQL” or ETL tools)

Snowflake can execute SQL and create tables without dbt, but dbt adds a **software engineering layer** on top of your SQL:

1. **DAG & lineage with `ref()` and `source()`**
   - Models reference each other with `{{ ref('model_name') }}` and `{{ source('source_name','table') }}`.
   - dbt builds a dependency graph (DAG) and knows:
     - in which order to run models,
     - what breaks when something changes.

2. **Data tests as code**
   - `unique`, `not_null`, `relationships`, etc. defined in YAML.
   - Run with `dbt test` or `dbt build`.
   - Ensures consistent, automated data quality checks.

3. **Documentation & discovery**
   - Model + column descriptions stored in YAML.
   - `dbt docs generate` builds a documentation site with:
     - model details,
     - tests,
     - lineage graph.

4. **Git & CI/CD friendly**
   - All transformations are plain files (`.sql`, `.yml`) tracked in Git.
   - Easy to integrate with CI (GitHub/GitLab) running `dbt build` on pull requests.
   - Promotes analytics engineering best practices.

5. **Warehouse-native transformations**
   - All transformations execute **inside Snowflake**:
     - no data movement to external servers,
     - takes full advantage of Snowflake’s scalability.

---

## 5. Project structure (simplified)

```text
.
├── models
│   ├── staging
│   │   ├── jaffle_shop
│   │   │   ├── stg_customers.sql
│   │   │   ├── stg_orders.sql
│   │   │   └── staging_jaffle_shop.yml
│   │   └── stripe
│   │       ├── stg_payments.sql
│   │       └── staging_stripe.yml
│   ├── core
│   │   ├── dim_customers.sql
│   │   ├── fct_orders.sql
│   │   └── core.yml
│   └── marts
│       ├── mrt_customer_kpis.sql
│       └── marts.yml
├── dbt_project.yml
└── packages.yml   (if used)

```

---

## 6. How to run this project

> These steps assume you already have:
>
> - Access to a Snowflake account
> - A dbt environment configured (dbt Cloud or dbt Core)
> - The raw Jaffle Shop / Stripe data loaded into `RAW_DB`

### 6.1 Clone the repo

```bash
git clone <your-repo-url>.git
cd <your-repo-folder>
```

### 6.2 Configure dbt profile / connection

- **dbt Cloud**:
  - Configure a Snowflake connection and link it to this repo.
  - Set target database/schema (e.g. `ANALYTICS_DB.dev_<user>`).

- **dbt Core**:
  - Edit `profiles.yml` with your Snowflake credentials.
  - Ensure the target points to your analytics database and dev schema.

### 6.3 Run models

```bash
# Build everything (models + tests)
dbt build

# Or run specific layers
dbt run  -s stg_customers stg_orders stg_payments dim_customers fct_orders mrt_customer_kpis
dbt test -s stg_customers stg_orders stg_payments dim_customers fct_orders mrt_customer_kpis

```

### 6.4 Generate and view docs

> - In dbt Cloud: use the “Generate Docs” button and then “View Docs”.
> - In dbt Core:

```bash
dbt docs generate
dbt docs serve
# visit http://localhost:8080 in your browser
```

### 7 dbt command cheat sheet

Some useful commands for this project:

```bash
# Check connection and config
dbt debug

# Run all models
dbt run

# Run only specific models
dbt run -s stg_customers
dbt run -s dim_customers fct_orders

# Run tests
dbt test
dbt test -s dim_customers fct_orders

# Full build (models + tests + snapshots + seeds)
dbt build

# Build only what is needed for a given model (and its upstream dependencies)
dbt build -s +mrt_customer_kpis

# Generate and serve docs (Core)
dbt docs generate
dbt docs serve
```

### 8 What this project demonstrates.

This repo is designed as a portfolio-ready example showing that I:

> - Worked with Snowflake as a modern data warehouse.
> - Used **dbt** to:

    - Build layered models (staging, core, marts),
    - Implement data quality tests,
    - Document models and visualize lineage.
    - Model a simple but realistic **customer & orders** domain.
    - Expose a BI-ready mart (mrt_customer_kpis) for dashboards.

> - It can be easily extended to:

    - Additional facts (e.g. fct_payments, fct_subscriptions)
    - More marts (marketing, sales, finance)
