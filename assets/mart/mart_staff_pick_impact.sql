/* @bruin

name: kickstarter_dbt.mart_staff_pick_impact
type: bq.sql
connection: gcp-kickstarter

materialization:
  type: table

depends:
  - kickstarter_dbt.stg_kickstarter

@bruin */

-- Does being a Kickstarter staff pick significantly boost success?
-- Compares success rate, funding ratio, and backer counts across categories
-- for staff-picked vs non-staff-picked campaigns.

with stg as (

    select *
    from `{{ var.GCP_PROJECT_ID }}.kickstarter_dbt.stg_kickstarter`

),

by_category_and_pick as (

    select
        main_category,
        is_staff_pick,

        count(*)                                              as total_campaigns,
        countif(is_successful)                                as successful_campaigns,
        round(
            safe_divide(countif(is_successful), count(*)) * 100, 2
        )                                                     as success_rate_pct,
        round(avg(funding_ratio), 4)                         as avg_funding_ratio,
        round(avg(backers_count), 1)                         as avg_backers,
        round(avg(pledged_usd), 2)                           as avg_pledged_usd,
        round(avg(campaign_duration_days), 1)                as avg_duration_days

    from stg
    group by main_category, is_staff_pick

),

-- Pivot to side-by-side comparison per category
pivoted as (

    select
        main_category,

        -- Staff pick metrics
        max(case when is_staff_pick then total_campaigns    end) as staff_pick_campaigns,
        max(case when is_staff_pick then success_rate_pct   end) as staff_pick_success_rate_pct,
        max(case when is_staff_pick then avg_funding_ratio  end) as staff_pick_avg_funding_ratio,
        max(case when is_staff_pick then avg_backers        end) as staff_pick_avg_backers,
        max(case when is_staff_pick then avg_pledged_usd    end) as staff_pick_avg_pledged_usd,

        -- Non-staff-pick metrics
        max(case when not is_staff_pick then total_campaigns    end) as non_pick_campaigns,
        max(case when not is_staff_pick then success_rate_pct   end) as non_pick_success_rate_pct,
        max(case when not is_staff_pick then avg_funding_ratio  end) as non_pick_avg_funding_ratio,
        max(case when not is_staff_pick then avg_backers        end) as non_pick_avg_backers,
        max(case when not is_staff_pick then avg_pledged_usd    end) as non_pick_avg_pledged_usd

    from by_category_and_pick
    group by main_category

)

select
    *,
    -- Lift: how much better do staff picks do?
    round(staff_pick_success_rate_pct - non_pick_success_rate_pct, 2) as success_rate_lift_pct,
    round(staff_pick_avg_backers - non_pick_avg_backers, 1)           as backer_lift
from pivoted
order by success_rate_lift_pct desc