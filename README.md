# 🚀 Kickstarter Campaign Analytics Pipeline

## Problem Description

Kickstarter is one of the world's largest crowdfunding platforms, yet **over 60% of campaigns fail to reach their funding goal**. Creators launch without data-driven insight into what actually drives success.

This project answers the question:
> **What factors — category, funding goal, country, staff pick status, and campaign duration — best predict whether a Kickstarter campaign will succeed?**

Using a dataset of **203,000 Kickstarter campaigns **, we build a fully reproducible, cloud-based batch data pipeline that ingests raw data, stores it in a data lake, transforms it in a data warehouse, and presents findings in a dashboard.

---

## Architecture Overview

```
HuggingFace Dataset (Parquet)
         │
         ▼  [Bruin: ingest_raw]
  GCS Bucket  ←─────────────────────────────
  gs://kickstarter-datalake/raw/            │  IaC: Terraform
         │                                  │  credentials: secrets/sa.json
         ▼  [Bruin: load_to_bq]              │
  BigQuery: raw.kickstarter_raw ────────────┘
  (partitioned by launched_date, clustered by category, country)
         │
         ▼  [Bruin: stg_kickstarter]
  BigQuery: stg_kickstarter (View)
         │
      ┌───────────────────────────────────┬──────────────────────────────┬───────────────────────────────┬─────────────────────────────┐
      ▼                                   ▼                              ▼                               ▼                             ▼
  [Bruin: mart_campaign_summary] [Bruin: mart_success_by_category] [Bruin: mart_duration_analysis] [Bruin: mart_goal_size_analysis] [Bruin: mart_monthly_trends]
  BigQuery analytics table        BigQuery analytics table       BigQuery analytics table       BigQuery analytics table      BigQuery analytics table
       │                                  │                              │                               │                             │
       └──────────┬───────────────────────┴──────────────────────────────┴───────────────────────────────┴─────────────────────────────┘
                  ▼
         Looker Studio Dashboard
```

---
## Project Structure

```
kickstarter-pipeline/
├── .env.example                    ← copy to .env, fill in project + bucket
├── .bruin.yml                      ← Bruin environment & GCP connection config
├── Makefile                        ← all commands with SA key guards
├── README.md                       ← this file
├── requirements.txt                ← Python dependencies
├── pipeline.yml                    ← pipeline schedule & variables
│
├── secrets/
│   └── sa.json                     ← YOUR GCP KEY HERE (not committed)
│
├── terraform/
│   ├── main.tf                     ← GCS + BQ resources
│   ├── variables.tf
│   ├── outputs.tf
│
├── assets/                         ← Bruin pipeline assets
│   ├── ingestion/                  ← Data ingestion layer (Python)
│   │   ├── ingest_raw.py           ├─ Download from HuggingFace → GCS
│   │   └── load_to_bq.py           └─ Load from GCS → BigQuery
│   │
│   ├── staging/                    ← Data cleaning & transformation (SQL)
│   │   └── stg_kickstarter.sql     └─ Clean, transform, validate data
│   │
│   └── mart/                       ← Analytics tables (SQL)
│       ├── mart_campaign_summary.sql        └─ Campaign metrics by country
│       ├── mart_success_by_category.sql     └─ Success rates by category
│       ├── mart_duration_analysis.sql       └─ Campaign duration impact analysis
│       ├── mart_goal_ size_analysis.sql     └─ Goal size vs success metrics
│       └── mart_monthly_trends.sql          └─ Monthly campaign trend analytics
│
└── dashboard/
   └── README.md                   ← Looker Studio setup guide
```

---
## Credential Setup

All GCP authentication uses a **service account key file** placed at:

```
secrets/sa.json
```

### How to get your sa.json

1. Go to [GCP Console → IAM & Admin → Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)
2. Create a service account (or use an existing one) with these roles:
   - `Storage Admin` (to create/write GCS buckets)
   - `BigQuery Admin` (to create datasets and load data)
   - `Editor` or custom role covering the above
3. Click the service account → **Keys** tab → **Add Key** → **Create new key** → JSON
4. Save the downloaded file as **`secrets/sa.json`** in this project root

> ⚠️ `secrets/sa.json` is in `.gitignore` — it will never be committed to version control.

---

## Quick Start

### 1. Clone and configure environment

```bash
git clone <your-repo>
cd kickstarter-pipeline

cp .env.example .env
# Edit .env with your GCP project ID and GCS bucket name
source .env
```

### 2. Place your service account key

```bash
# Download sa.json from GCP Console, then:
mv ~/Downloads/your-key.json secrets/sa.json

# Verify it's in place:
make check-sa
```

### 3. Install Python dependencies

```bash
make setup
```

### 4. Provision GCP infrastructure

```bash
make infra-apply
# Creates: GCS bucket, BigQuery datasets (kickstarter_raw + kickstarter_dbt)
```

### 5. Run the Bruin pipeline

```bash
# Run the entire pipeline
bruin run .

# Or use make convenience target
make pipeline
```

### 6. Build the dashboard

See [dashboard/README.md](dashboard/README.md) for Looker Studio setup instructions.

### Or run everything in one command

```bash
make all
```

---


## Bruin Pipeline Structure

The pipeline is organized into three layers:

### Layer 1: Ingestion
**Asset**: `kickstarter_dbt.ingest_raw` (Python)
- Downloads Kickstarter dataset from HuggingFace (2 parquet shards)
- Deduplicates on campaign ID
- Enriches with calculated fields
- Uploads to GCS: `gs://{bucket}/raw/kickstarter_2022-2021/kickstarter_raw.parquet`

**Asset**: `kickstarter_dbt.load_to_bq` (Python)
- Loads parquet file from GCS into BigQuery
- Table: `kickstarter_raw.kickstarter_raw`
- Partitioned by `launched_date` (MONTH)
- Clustered by `category`, `country`
- Depends on: `ingest_raw`

### Layer 2: Staging
**Asset**: `kickstarter_dbt.stg_kickstarter` (BigQuery SQL view)
- Cleans and validates raw data
- Type casting (int64, float64, bool)
- Category extraction (main + sub)
- Financial metrics (overfunded flag, avg pledge, etc.)
- Data quality checks:
  - `campaign_id`: unique, not_null
  - `is_successful`: not_null
  - `main_category`: not_null
  - `country_code`: not_null
  - `campaign_duration_days`: 1-90 days
- Depends on: `load_to_bq`

### Layer 3: Analytics (Marts)
**Asset**: `kickstarter_dbt.mart_campaign_summary` (BigQuery table)
- Campaign metrics grouped by country
- Metrics: count, avg goal, avg pledged
- Filter: countries with ≥10 campaigns
- Depends on: `stg_kickstarter`

**Asset**: `kickstarter_dbt.mart_success_by_category` (BigQuery table)
- Campaign metrics grouped by category
- Metrics: count, success rate %, avg pledged
- Depends on: `stg_kickstarter`

**Asset**: `kickstarter_dbt.mart_duration_analysis` (BigQuery table)
- Analysis of campaign duration vs success
- Metrics: avg duration, success rate, restaurant period cohorts
- Depends on: `stg_kickstarter`

**Asset**: `kickstarter_dbt.mart_goal_size_analysis` (BigQuery table)
- Analysis of goal size bands and success likelihood
- Metrics: goal quantiles, success rate by goal bracket
- Depends on: `stg_kickstarter`

**Asset**: `kickstarter_dbt.mart_monthly_trends` (BigQuery table)
- Monthly campaign performance and trend metrics
- Metrics: count, success rate, avg pledge by month
- Depends on: `stg_kickstarter`

---

## Running Bruin Commands

### Run entire pipeline
```bash
bruin run pipeline.yml
```

### Run specific layer
```bash
bruin run assets/ingestion/
bruin run assets/staging/
bruin run assets/mart/
```

### Run specific asset
```bash
bruin run assets/staging/stg_kickstarter.sql
bruin run assets/mart/mart_campaign_summary.sql
```

### Check data lineage
```bash
bruin lineage assets/staging/stg_kickstarter.sql
```

### Validate pipeline
```bash
bruin validate pipeline.yml
```

---

## Environment Variables

Required environment variables (auto-loaded from `.env` by Makefile):

```bash
export GCP_PROJECT_ID="your-gcp-project-id"
export GOOGLE_APPLICATION_CREDENTIALS="secrets/sa.json"
export GCS_BUCKET="your-gcs-bucket-name"
export BQ_DATASET_RAW="kickstarter_raw"       
export BQ_DATASET_DBT="kickstarter_dbt"       
export GCP_REGION="us-central1"               
```

All assets use the `gcp-kickstarter` connection defined in `bruin/.bruin.yml`, which reads credentials from `GOOGLE_APPLICATION_CREDENTIALS`.

---

## Data Warehouse Design

**Raw Table** (`kickstarter_raw.kickstarter_raw`):
- Partitioned by `DATE(launched_date)` — queries filtered by date scan only relevant partitions
- Clustered by `category`, `country` — analytical queries benefit from co-location

**Staging View** (`stg_kickstarter`):
- Cleaned, validated data with standardized types
- All transformations and computed fields applied
- Quality checks embedded in asset definition

**Analytics Tables** (marts):
- Pre-aggregated metrics for dashboard performance
- Materialized as BigQuery tables (not views)
- Ready for direct BI tool consumption

---

## Dashboard Tiles

[Dashboard](https://lookerstudio.google.com/reporting/bcc665e0-6d8c-4407-8f64-d095019291e0)



---

## Documentation
- **[dashboard/README.md](dashboard/README.md)** — Looker Studio dashboard setup
