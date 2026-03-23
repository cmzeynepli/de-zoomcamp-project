# Dashboard Setup — Looker Studio

This dashboard connects to the two BigQuery mart tables produced by bruin and
visualises the most business-relevant insights from the Kickstarter dataset.

---

## Prerequisites

- Your Google account must have at least **BigQuery Data Viewer** on the project
- Go to [Looker Studio](https://lookerstudio.google.com) and sign in

---

## Step 1 — Create a new report

1. Click **"Blank Report"**
2. When prompted to add a data source, click **"BigQuery"**

---

## Connect Data Source 1 (Tile 1)

| Field | Value |
|---|---|
| Project | `<your GCP_PROJECT_ID>` |
| Dataset | `kickstarter_dbt` |
| Table | `mart_success_by_category` |

Click **"Add"** → **"Add to Report"**

## Build Tile 1: Success Rate by Category (Bar Chart)

1. Insert → **Chart → Bar chart**
2. Configure:
   - **Dimension**: `main_category`
   - **Metric**: `success_rate_pct`
   - **Sort**: `success_rate_pct` descending
3. Style:
   - Title: *"Campaign Success Rate by Category"*
   - Show data labels: ✓
   - Bar color: gradient green (low) → dark green (high) via conditional formatting

**Business Question Answered**: Which creative categories give creators the best
chance of being funded on Kickstarter?

---

## Connect Data Source 2 (Tile 2)

Add a second data source:

| Field | Value |
|---|---|
| Project | `<your GCP_PROJECT_ID>` |
| Dataset | `kickstarter_dbt` |
| Table | `mart_campaign_summary` |


## Build Tile 2: Avg Pledged vs Goal by Country (Bubble / Table)

Option A — **Scatter chart** (recommended):
1. Insert → **Chart → Scatter chart**
2. Configure:
   - **Dimension**: `country_name`
   - **Metric X**: `avg_goal_usd`
   - **Metric Y**: `avg_pledged_usd`
   - **Bubble size**: `total_campaigns`
3. Add a reference line: Y = X (equal funding line)

Option B — **Table with heatmap**:
1. Insert → **Chart → Table**
2. Columns: `country_name`, `total_campaigns`, `avg_goal_usd`, `avg_pledged_usd`,
   `success_rate_pct`, `avg_funding_ratio`
3. Enable heatbar on `avg_pledged_usd` and `success_rate_pct`

**Business Question Answered**: Which countries produce the most successfully funded
campaigns, and do their pledged amounts exceed or fall short of goals?

---

## Connect Data Source 3 (Tile 3)

Add a third data source:

| Field | Value |
|---|---|
| Project | `<your GCP_PROJECT_ID>` |
| Dataset | `kickstarter_dbt` |
| Table | `mart_duration_analysis` |

## Build Tile 3: Duration Impact on Success (Line/Bar)
1. Insert → **Chart → Line chart** or **Bar chart**
2. Configure:
   - **Dimension**: `campaign_duration_days` (or duration bin)
   - **Metric**: `success_rate_pct`
   - Optional segment by `main_category` or `country`
3. Title: *"Campaign Duration vs Success Rate"*

---
## Connect Data Source 4 (Tile 4)

Add a fourth data source:

| Field | Value |
|---|---|
| Project | `<your GCP_PROJECT_ID>` |
| Dataset | `kickstarter_dbt` |
| Table | `mart_goal_size_analysis` |


## Build Tile 4: Goal Size Analysis (Histogram)
1. Insert → **Chart → Histogram**
2. Configure:
   - **Dimension**: `goal_usd` (goal size bucket)
   - **Metric**: `success_rate_pct`
3. Title: *"Success Rate by Campaign Goal Size"*

---

## Connect Data Source 5 (Tile 5)

Add a fifth data source:

| Field | Value |
|---|---|
| Project | `<your GCP_PROJECT_ID>` |
| Dataset | `kickstarter_dbt` |
| Table | `mart_monthly_trends` |

## Build Tile 5: Monthly Trends (Time Series)
1. Insert → **Chart → Time series**
2. Configure:
   - **Dimension**: `launch_month`
   - **Metrics**: `total_campaigns`, `success_rate_pct`, `avg_pledged_usd`
3. Title: *"Monthly Kickstarter Campaign Trends"*


---

## Sharing the Dashboard

Once built:
1. Click **Share** → **Get report link**
2. Set to "Anyone with the link can view"
3. Or embed in a README / wiki with the embed code

---



