variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "bucket_name" {
  description = "Name of the GCS data lake bucket"
  type        = string
}

variable "region" {
  description = "GCP region for GCS"
  type        = string
  default     = "europe-north1"
}

variable "bq_location" {
  description = "BigQuery dataset location"
  type        = string
  default     = "EU"
}

variable "bq_dataset_raw" {
  description = "BigQuery dataset name for raw data"
  type        = string
  default     = "kickstarter_raw"
}

variable "bq_dataset_dbt" {
  description = "BigQuery dataset name for dbt models"
  type        = string
  default     = "kickstarter_dbt"
}
