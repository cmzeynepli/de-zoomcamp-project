/* @bruin

name: kickstarter_dbt.mart_duration_analysis
type: bq.sql
connection: gcp-kickstarter

materialization:
  type: table

depends:
  - kickstarter_dbt.stg_kickstarter

@bruin */

-- Does campaign length affect success?
-- Groups campaigns into duration buckets and measures success rate.
-- Kickstarter allows 1–60 day campaigns; the "sweet spot" is often cited as 30 days.

with stg as (

    select *
    from `{{ var.GCP_PROJECT_ID }}.{{ var.BQ_DATASET_DBT }}.stg_kickstarter`
    where campaign_duration_days between 1 and 120

),

bucketed as (

    select *,
        case
            when campaign_duration_days <= 7  then '1_1_to_7_days'
            when campaign_duration_days <= 14 then '2_8_to_14_days'
            when campaign_duration_days <= 21 then '3_15_to_21_days'
            when campaign_duration_days <= 30 then '4_22_to_30_days'
            when campaign_duration_days <= 45 then '5_31_to_45_days'
            when campaign_duration_days <= 60 then '6_46_to_60_days'
            else                                   '7_over_60_days'
        end as duration_bucket,
        case
            when campaign_duration_days <= 7  then '1–7 days'
            when campaign_duration_days <= 14 then '8–14 days'
            when campaign_duration_days <= 21 then '15–21 days'
            when campaign_duration_days <= 30 then '22–30 days'
            when campaign_duration_days <= 45 then '31–45 days'
            when campaign_duration_days <= 60 then '46–60 days'
            else                                   'Over 60 days'
        end as duration_bucket_label
    from stg

)

select
    duration_bucket,
    duration_bucket_label,
    count(*)                                              as total_campaigns,
    countif(is_successful)                                as successful_campaigns,
    round(
        safe_divide(countif(is_successful), count(*)) * 100, 2
    )                                                     as success_rate_pct,
    round(avg(goal_usd), 2)                              as avg_goal_usd,
    round(avg(pledged_usd), 2)                           as avg_pledged_usd,
    round(avg(backers_count), 1)                         as avg_backers,
    round(avg(funding_ratio), 4)                         as avg_funding_ratio

from bucketed
group by duration_bucket, duration_bucket_label
order by duration_bucket