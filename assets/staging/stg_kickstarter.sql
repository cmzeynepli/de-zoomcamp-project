/* @bruin

name: kickstarter_dbt.stg_kickstarter
type: bq.sql
connection: gcp-kickstarter

materialization:
  type: view

depends:
  - kickstarter_dbt.load_to_bq

columns:
  - name: campaign_id
    type: integer
    description: Unique Kickstarter campaign ID
    checks:
      - name: unique
      - name: not_null

  - name: is_successful
    type: boolean
    description: True if the campaign reached its funding goal
    checks:
      - name: not_null

  - name: main_category
    type: string
    description: Top-level category (e.g. art, technology, games)
    checks:
      - name: not_null

  - name: country_code
    type: string
    description: ISO 2-letter country code
    checks:
      - name: not_null

  - name: funding_ratio
    type: float
    description: pledged / goal — values > 1.0 indicate overfunded campaigns

  - name: campaign_duration_days
    type: integer
    description: Number of days from launch to deadline
    checks:
      - name: min
        value: 1
      - name: max
        value: 120

@bruin */

with raw as (

    select *
    from `{{ var.GCP_PROJECT_ID }}.kickstarter_raw.kickstarter_raw`

),

cleaned as (

    select
        -- ── Identifiers ──────────────────────────────────────────────────
        cast(id as int64)                                    as campaign_id,
        slug                                                  as campaign_slug,
        name                                                  as campaign_name,
        blurb                                                 as campaign_blurb,

        -- ── Category ──────────────────────────────────────────────────────
        lower(trim(category))                                 as category_slug,

        -- Extract the parent category (before the slash)
        -- e.g. "art/painting" → "art"
        case
            when category like '%/%'
                then lower(split(category, '/')[OFFSET(0)])
            else lower(trim(category))
        end                                                   as main_category,

        -- Extract the sub-category (after the slash)
        case
            when category like '%/%'
                then lower(split(category, '/')[OFFSET(1)])
            else null
        end                                                   as sub_category,

        -- ── Geography ─────────────────────────────────────────────────────
        upper(trim(country))                                  as country_code,
        country_displayable_name                              as country_name,
        language                                              as content_language,

        -- ── Outcome ───────────────────────────────────────────────────────
        cast(state as int64)                                  as state_raw,
        case
            when cast(state as int64) = 1 then true
            else false
        end                                                   as is_successful,

        -- ── Financials ────────────────────────────────────────────────────
        currency                                              as currency_code,
        round(cast(goal as float64), 2)                       as goal_local,
        round(cast(pledged as float64), 2)                    as pledged_local,
        round(cast(usd_pledged as float64), 2)                as pledged_usd,
        round(cast(converted_pledged_amount as float64), 2)   as pledged_usd_converted,

        -- Goal in USD (using fx_rate)
        case
            when fx_rate > 0 then round(goal / fx_rate, 2)
            else null
        end                                                   as goal_usd,

        -- Funding ratio: how much did backers fund relative to goal?
        case
            when goal > 0 then round(pledged / goal, 4)
            else null
        end                                                   as funding_ratio,

        -- Overfunded flag
        case
            when goal > 0 and pledged >= goal then true
            else false
        end                                                   as is_overfunded,

        cast(backers_count as int64)                          as backers_count,

        -- Average pledge per backer (in USD)
        case
            when backers_count > 0
                then round(cast(usd_pledged as float64) / backers_count, 2)
            else null
        end                                                   as avg_pledge_usd_per_backer,

        round(cast(fx_rate as float64), 6)                    as fx_rate,
        round(cast(static_usd_rate as float64), 6)            as static_usd_rate,

        -- ── Timing ────────────────────────────────────────────────────────
        timestamp_seconds(cast(launched_at as int64))         as launched_at_ts,
        date(timestamp_seconds(cast(launched_at as int64)))   as launched_date,
        extract(year from timestamp_seconds(cast(launched_at as int64)))  as launch_year,
        extract(month from timestamp_seconds(cast(launched_at as int64))) as launch_month,

        timestamp_seconds(cast(deadline as int64))            as deadline_ts,
        date(timestamp_seconds(cast(deadline as int64)))      as deadline_date,

        -- Campaign duration in days
        date_diff(
            date(timestamp_seconds(cast(deadline as int64))),
            date(timestamp_seconds(cast(launched_at as int64))),
            day
        )                                                     as campaign_duration_days,

        timestamp_seconds(cast(created_at as int64))          as created_at_ts,

        -- ── Flags ─────────────────────────────────────────────────────────
        cast(staff_pick as bool)                              as is_staff_pick,
        cast(spotlight as bool)                               as is_spotlight

    from raw

    where
        -- Remove rows with null campaign IDs
        id is not null
        -- Only keep final states (0=failed, 1=successful); exclude live/cancelled
        and cast(state as int64) in (0, 1)

)

select *
from cleaned