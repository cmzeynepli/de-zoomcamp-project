/* @bruin

name: kickstarter_dbt.mart_monthly_trends
type: bq.sql
connection: gcp-kickstarter

materialization:
  type: table

depends:
  - kickstarter_dbt.stg_kickstarter

columns:
  - name: launch_year
    type: integer
    checks:
      - name: not_null
  - name: launch_month
    type: integer
    checks:
      - name: not_null

@bruin */

-- Monthly launch trends: volume, success rate, and funding over time.
-- Useful for spotting seasonal patterns and year-over-year changes.

with stg as (

    select *
    from `{{ var.GCP_PROJECT_ID }}.kickstarter_dbt.stg_kickstarter`
    where launch_year is not null
      and launch_month is not null

)

select
    launch_year,
    launch_month,
    date(launch_year, launch_month, 1)                        as month_start,

    count(*)                                                  as total_campaigns,
    countif(is_successful)                                    as successful_campaigns,
    round(
        safe_divide(countif(is_successful), count(*)) * 100, 2
    )                                                         as success_rate_pct,

    round(sum(pledged_usd), 2)                               as total_pledged_usd,
    round(avg(pledged_usd), 2)                               as avg_pledged_usd,
    round(avg(goal_usd), 2)                                  as avg_goal_usd,
    round(avg(backers_count), 1)                             as avg_backers,
    countif(is_staff_pick)                                    as staff_picks

from stg
group by launch_year, launch_month
order by launch_year, launch_month