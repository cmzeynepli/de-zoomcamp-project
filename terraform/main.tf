terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file("${path.root}/../secrets/sa.json")
}

# ─────────────────────────────────────────
# GCS Bucket — Data Lake
# ─────────────────────────────────────────
resource "google_storage_bucket" "datalake" {
  name          = var.bucket_name
  location      = var.region
  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  uniform_bucket_level_access = true

  labels = {
    project     = "kickstarter-pipeline"
    environment = "production"
  }
}

# GCS folder structure (placeholder object to create the raw/ prefix)
resource "google_storage_bucket_object" "raw_folder" {
  name    = "raw/kickstarter_2022-2021/.gitkeep"
  bucket  = google_storage_bucket.datalake.name
  content = "placeholder"
}

# ─────────────────────────────────────────
# BigQuery Dataset — Raw ingestion
# ─────────────────────────────────────────
resource "google_bigquery_dataset" "raw" {
  dataset_id                 = var.bq_dataset_raw
  friendly_name              = "Kickstarter Raw"
  description                = "Raw ingested data from Kickstarter 2021-2022 dataset"
  location                   = var.bq_location
  delete_contents_on_destroy = true

  labels = {
    project = "kickstarter-pipeline"
    layer   = "raw"
  }
}

# ─────────────────────────────────────────
# BigQuery Dataset — dbt transformations
# ─────────────────────────────────────────
resource "google_bigquery_dataset" "dbt" {
  dataset_id                 = var.bq_dataset_dbt
  friendly_name              = "Kickstarter dbt"
  description                = "Transformed dbt models for Kickstarter analytics"
  location                   = var.bq_location
  delete_contents_on_destroy = true

  labels = {
    project = "kickstarter-pipeline"
    layer   = "transformed"
  }
}

# ─────────────────────────────────────────
# BigQuery Table — Raw with partitioning + clustering
# ─────────────────────────────────────────
resource "google_bigquery_table" "kickstarter_raw" {
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = "kickstarter_raw"
  deletion_protection = false

  description = "Raw Kickstarter campaigns loaded from GCS parquet"

  time_partitioning {
    type  = "MONTH"
    field = "launched_date"
  }

  clustering = ["category", "country"]

  schema = jsonencode([
    { name = "id",                         type = "INT64",   mode = "NULLABLE" },
    { name = "name",                       type = "STRING",  mode = "NULLABLE" },
    { name = "blurb",                      type = "STRING",  mode = "NULLABLE" },
    { name = "category",                   type = "STRING",  mode = "NULLABLE" },
    { name = "country",                    type = "STRING",  mode = "NULLABLE" },
    { name = "country_displayable_name",   type = "STRING",  mode = "NULLABLE" },
    { name = "state",                      type = "INT64",   mode = "NULLABLE" },
    { name = "goal",                       type = "FLOAT64", mode = "NULLABLE" },
    { name = "pledged",                    type = "FLOAT64", mode = "NULLABLE" },
    { name = "usd_pledged",               type = "FLOAT64", mode = "NULLABLE" },
    { name = "converted_pledged_amount",   type = "INT64",   mode = "NULLABLE" },
    { name = "currency",                   type = "STRING",  mode = "NULLABLE" },
    { name = "backers_count",              type = "INT64",   mode = "NULLABLE" },
    { name = "launched_at",               type = "INT64",   mode = "NULLABLE" },
    { name = "launched_date",             type = "DATE",    mode = "NULLABLE" },
    { name = "deadline",                  type = "INT64",   mode = "NULLABLE" },
    { name = "created_at",               type = "INT64",   mode = "NULLABLE" },
    { name = "staff_pick",               type = "BOOL",    mode = "NULLABLE" },
    { name = "spotlight",                type = "BOOL",    mode = "NULLABLE" },
    { name = "fx_rate",                  type = "FLOAT64", mode = "NULLABLE" },
    { name = "static_usd_rate",          type = "FLOAT64", mode = "NULLABLE" },
    { name = "ratio",                    type = "FLOAT64", mode = "NULLABLE" },
    { name = "language",                 type = "STRING",  mode = "NULLABLE" },
    { name = "slug",                     type = "STRING",  mode = "NULLABLE" },
  ])

  labels = {
    project = "kickstarter-pipeline"
  }

  depends_on = [google_bigquery_dataset.raw]
}
