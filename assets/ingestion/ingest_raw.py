"""@bruin
name: kickstarter_dbt.ingest_raw
type: python
connection: gcp-kickstarter
@bruin"""

import io
import os
import tempfile

import pandas as pd
import requests
from google.cloud import storage
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

# All parquet shards for bitmorse/kickstarter_2022-2021
# Dataset has 203k rows split across 2 shards
HF_BASE = (
    "https://huggingface.co/datasets/bitmorse/kickstarter_2022-2021"
    "/resolve/refs%2Fconvert%2Fparquet/default/train"
)
HF_SHARDS = [
    f"{HF_BASE}/0000.parquet",
    f"{HF_BASE}/0001.parquet",
]


def _gcs_client():
    credentials = service_account.Credentials.from_service_account_file(
        SA_KEY_PATH,
        scopes=["https://www.googleapis.com/auth/cloud-platform"],
    )
    return storage.Client(credentials=credentials)


def download_all(shards: list) -> pd.DataFrame:
    frames = []
    for i, url in enumerate(shards, 1):
        print(f"[ingest_raw] Downloading shard {i}/{len(shards)}: {url}")
        r = requests.get(url, timeout=300)
        if r.status_code == 404:
            print(f"[ingest_raw] Shard {i} not found (404) — skipping")
            continue
        r.raise_for_status()
        df = pd.read_parquet(io.BytesIO(r.content))
        print(f"[ingest_raw] Shard {i}: {len(df):,} rows")
        frames.append(df)

    combined = pd.concat(frames, ignore_index=True)
    print(f"[ingest_raw] Total downloaded: {len(combined):,} rows")
    return combined


def enrich(df: pd.DataFrame) -> pd.DataFrame:
    keep = [
        "id", "name", "blurb", "category", "country",
        "country_displayable_name", "state", "goal", "pledged",
        "usd_pledged", "converted_pledged_amount", "currency",
        "backers_count", "launched_at", "deadline", "created_at",
        "staff_pick", "spotlight", "fx_rate", "static_usd_rate",
        "ratio", "language", "slug",
    ]
    df = df[[c for c in keep if c in df.columns]].copy()
    df = df.drop_duplicates(subset=["id"])
    if "launched_at" in df.columns:
        df["launched_date"] = (
            pd.to_datetime(df["launched_at"], unit="s", errors="coerce").dt.date
        )
    print(f"[ingest_raw] After dedup: {len(df):,} rows, {len(df.columns)} columns")
    return df


def upload(df: pd.DataFrame, bucket_name: str, gcs_path: str):
    client = _gcs_client()
    blob = client.bucket(bucket_name).blob(gcs_path)
    with tempfile.NamedTemporaryFile(suffix=".parquet", delete=False) as tmp:
        df.to_parquet(tmp.name, index=False, engine="pyarrow")
        tmp_path = tmp.name
    print(f"[ingest_raw] Uploading to gs://{bucket_name}/{gcs_path} ...")
    blob.upload_from_filename(tmp_path)
    os.unlink(tmp_path)
    print(f"[ingest_raw] ✓ Upload complete ({blob.size / 1e6:.1f} MB)")


def run():
    gcs_bucket = os.environ.get("GCS_BUCKET")
    if not gcs_bucket:
        raise ValueError("GCS_BUCKET env var is required")
    if not os.path.exists(SA_KEY_PATH):
        raise FileNotFoundError(f"SA key not found: {SA_KEY_PATH}")

    df = download_all(HF_SHARDS)
    df = enrich(df)
    upload(df, gcs_bucket, GCS_PATH)
    print("[ingest_raw] ✓ Done")


def main(context, parameters):
    run()


if __name__ == "__main__":
    run()