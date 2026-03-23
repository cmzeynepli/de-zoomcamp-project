/* @bruin

name: kickstarter_dbt.mart_goal_size_analysis
type: bq.sql
connection: gcp-kickstarter

materialization:
  type: table

depends:
  - kickstarter_dbt.stg_kickstarter

columns:
  - name: goal_bucket
    type: string
    description: Goal size bucket (e.g. <$1k, $1k-$5k, ...)
    checks:
      - name: not_null
  - name: total_campaigns
    type: integer
    checks:
      - name: not_null

@bruin */

-- How does goal size affect success rate?
-- Buckets campaigns by funding goal (USD) and computes success metrics per bucket.

with stg as (

    select *
    from `{{ var.GCP_PROJECT_ID }}.kickstarter_dbt.stg_kickstarter`
    where goal_usd is not null

),

bucketed as (

    select *,
        case
            when goal_usd < 1000              then '1_under_1k'
            when goal_usd < 5000              then '2_1k_to_5k'
            when goal_usd < 10000             then '3_5k_to_10k'
            when goal_usd < 25000             then '4_10k_to_25k'
            when goal_usd < 50000             then '5_25k_to_50k'
            when goal_usd < 100000            then '6_50k_to_100k'
            else                                   '7_over_100k'
        end as goal_bucket,
        case
            when goal_usd < 1000              then 'Under $1k'
            when goal_usd < 5000              then '$1k – $5k'
            when goal_usd < 10000             then '$5k – $10k'
            when goal_usd < 25000             then '$10k – $25k'
            when goal_usd < 50000             then '$25k – $50k'
            when goal_usd < 100000            then '$50k – $100k'
            else                                   'Over $100k'
        end as goal_bucket_label
    from stg

)

select
    goal_bucket,
    goal_bucket_label,
    count(*)                                              as total_campaigns,
    countif(is_successful)                                as successful_campaigns,
    round(
        safe_divide(countif(is_successful), count(*)) * 100, 2
    )                                                     as success_rate_pct,
    round(avg(goal_usd), 2)                              as avg_goal_usd,
    round(avg(pledged_usd), 2)                           as avg_pledged_usd,
    round(avg(backers_count), 1)                         as avg_backers,
    round(avg(campaign_duration_days), 1)                as avg_duration_days,
    countif(is_staff_pick)                                as staff_pick_count

from bucketed
group by goal_bucket, goal_bucket_label
order by goal_bucket