"""@bruin
name: kickstarter_dbt.load_to_bq
type: python
connection: gcp-kickstarter
depends:
  - kickstarter_dbt.ingest_raw
@bruin"""

import os

from google.cloud import bigquery
from google.oauth2 import service_account

# Load .env file if it exists
env_file = os.path.join(os.path.dirname(__file__), '..', '..', '.env')
if os.path.exists(env_file):
    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                if '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key] = value

SA_KEY_PATH = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
GCS_PATH    = "raw/kickstarter_2022-2021/kickstarter_raw.parquet"


def _bq_client():
    credentials = service_account.Credentials.from_service_account_file(
        SA_KEY_PATH,
        scopes=["https://www.googleapis.com/auth/cloud-platform"],
    )
    return bigquery.Client(credentials=credentials)


def run():
    gcs_bucket = os.environ.get("GCS_BUCKET")
    bq_project = os.environ.get("GCP_PROJECT_ID")
    bq_dataset = os.environ.get("BQ_DATASET_RAW")
    bq_table   = os.environ.get("BQ_DATASET_RAW")

    if not gcs_bucket:
        raise ValueError("GCS_BUCKET env var is required")
    if not os.path.exists(SA_KEY_PATH):
        raise FileNotFoundError(f"SA key not found: {SA_KEY_PATH}")

    source_uri = f"gs://{gcs_bucket}/{GCS_PATH}"
    table_ref  = f"{bq_project}.{bq_dataset}.{bq_table}"

    print(f"[load_to_bq] Loading {source_uri} → {table_ref}")

    client = _bq_client()

    # MONTH partitioning stays within BigQuery's 4000-partition limit.
    # DAY across multi-year data exceeds it.
    job_config = bigquery.LoadJobConfig(
        source_format     = bigquery.SourceFormat.PARQUET,
        write_disposition = bigquery.WriteDisposition.WRITE_TRUNCATE,
        autodetect        = False,
        time_partitioning = bigquery.TimePartitioning(
            type_          = bigquery.TimePartitioningType.MONTH,
            field          = "launched_date",
        ),
        clustering_fields = ["category", "country"],
    )

    job = client.load_table_from_uri(source_uri, table_ref, job_config=job_config)
    print(f"[load_to_bq] Job {job.job_id} running...")
    job.result()

    rows = client.get_table(table_ref).num_rows
    print(f"[load_to_bq] ✓ Done — {rows:,} rows loaded into {table_ref}")


def main(context, parameters):
    run()


if __name__ == "__main__":
    run()