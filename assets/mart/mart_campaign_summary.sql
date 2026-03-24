/* @bruin

name: kickstarter_dbt.mart_campaign_summary
type: bq.sql
connection: gcp-kickstarter

materialization:
  type: table

depends:
  - kickstarter_dbt.stg_kickstarter

columns:
  - name: country_code
    type: string
    description: ISO 2-letter country code
    checks:
      - name: unique
      - name: not_null

  - name: total_campaigns
    type: integer
    description: Total campaigns from this country (min 10)
    checks:
      - name: not_null

  - name: avg_goal_usd
    type: float
    description: Average campaign goal in USD

  - name: avg_pledged_usd
    type: float
    description: Average amount pledged in USD

@bruin */

with stg as (

    select *
    from `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET_DBT }}.stg_kickstarter`

),

by_country as (

    select
        country_code,
        country_name,

        count(*)                                                as total_campaigns,
        countif(is_successful)                                  as successful_campaigns,
        round(
            safe_divide(countif(is_successful), count(*)) * 100,
            2
        )                                                       as success_rate_pct,

        round(avg(goal_usd), 2)                                as avg_goal_usd,
        round(avg(pledged_usd), 2)                             as avg_pledged_usd,
        round(sum(pledged_usd), 2)                             as total_pledged_usd,
        round(avg(pledged_usd - goal_usd), 2)                  as avg_pledged_minus_goal_usd,
        round(avg(funding_ratio), 4)                           as avg_funding_ratio,

        round(avg(backers_count), 1)                           as avg_backers,
        sum(backers_count)                                      as total_backers,
        countif(is_staff_pick)                                  as staff_pick_count

    from stg
    group by country_code, country_name

),

-- Top category per country — computed separately to avoid a correlated subquery
category_counts as (

    select
        country_code,
        main_category,
        count(*) as n
    from stg
    group by country_code, main_category

),

top_category as (

    select
        country_code,
        main_category as top_category
    from (
        select
            country_code,
            main_category,
            row_number() over (
                partition by country_code
                order by n desc
            ) as rn
        from category_counts
    )
    where rn = 1

),

joined as (

    select
        b.*,
        t.top_category
    from by_country b
    left join top_category t using (country_code)

),

filtered as (

    select *
    from joined
    where total_campaigns >= 10

)

select *
from filtered