/* @bruin

name: kickstarter_dbt.mart_success_by_category
type: bq.sql
connection: gcp-kickstarter

materialization:
  type: table

depends:
  - kickstarter_dbt.stg_kickstarter

columns:
  - name: main_category
    type: string
    description: Top-level category slug
    checks:
      - name: not_null

  - name: total_campaigns
    type: integer
    description: Total number of campaigns in this category
    checks:
      - name: not_null

  - name: success_rate_pct
    type: float
    description: Percentage of campaigns that reached their goal (0–100)

  - name: avg_pledged_usd
    type: float
    description: Average amount pledged in USD across all campaigns in category

@bruin */

with stg as (

    select *
    from `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET_DBT }}.stg_kickstarter`

),

aggregated as (

    select
        main_category,
        sub_category,

        -- Volume
        count(*)                                                as total_campaigns,
        countif(is_successful)                                  as successful_campaigns,
        countif(not is_successful)                              as failed_campaigns,

        -- Success rate
        round(
            safe_divide(countif(is_successful), count(*)) * 100,
            2
        )                                                       as success_rate_pct,

        -- Funding
        round(avg(pledged_usd), 2)                             as avg_pledged_usd,
        round(avg(goal_usd), 2)                                as avg_goal_usd,
        round(avg(funding_ratio), 4)                           as avg_funding_ratio,
        round(sum(pledged_usd), 2)                             as total_pledged_usd,

        -- Staff picks
        countif(is_staff_pick)                                  as staff_pick_count,
        round(
            safe_divide(countif(is_staff_pick), count(*)) * 100,
            2
        )                                                       as staff_pick_rate_pct,

        -- Backers
        round(avg(backers_count), 1)                           as avg_backers,
        sum(backers_count)                                      as total_backers,

        -- Campaign duration
        round(avg(campaign_duration_days), 1)                  as avg_duration_days,

        -- Success rate for staff picks vs non-staff picks
        round(
            safe_divide(
                countif(is_successful and is_staff_pick),
                nullif(countif(is_staff_pick), 0)
            ) * 100,
            2
        )                                                       as staff_pick_success_rate_pct,

        round(
            safe_divide(
                countif(is_successful and not is_staff_pick),
                nullif(countif(not is_staff_pick), 0)
            ) * 100,
            2
        )                                                       as non_staff_pick_success_rate_pct,

    from stg
    group by main_category, sub_category

)

select *
from aggregated
order by total_campaigns desc