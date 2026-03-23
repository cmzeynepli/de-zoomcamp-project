output "gcs_bucket_name" {
  description = "GCS bucket for data lake"
  value       = google_storage_bucket.datalake.name
}

output "gcs_bucket_url" {
  description = "GCS bucket URL"
  value       = google_storage_bucket.datalake.url
}

output "bq_raw_dataset" {
  description = "BigQuery raw dataset ID"
  value       = google_bigquery_dataset.raw.dataset_id
}

output "bq_dbt_dataset" {
  description = "BigQuery dbt dataset ID"
  value       = google_bigquery_dataset.dbt.dataset_id
}

output "bq_raw_table" {
  description = "BigQuery raw table full ID"
  value       = "${var.project_id}.${google_bigquery_dataset.raw.dataset_id}.kickstarter_raw"
}
