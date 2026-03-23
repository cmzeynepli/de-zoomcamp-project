# Makefile — Kickstarter Analytics Pipeline
# Usage: make <target>
#
# The Makefile auto-loads .env so you never need to run "source .env" manually.
# Just run: make <target>

SA_KEY   = secrets/sa.json
ENV_FILE = .env

# Auto-load .env if it exists — exports all variables into every make recipe
ifneq (,$(wildcard $(ENV_FILE)))
  include $(ENV_FILE)
  export $(shell sed 's/=.*//' $(ENV_FILE) | grep -v '^\#' | grep -v '^$$')
endif

.PHONY: help setup check-sa check-env infra-plan infra-apply infra-destroy pipeline clean all

help:
	@echo ""
	@echo "Kickstarter Analytics Pipeline — Commands"
	@echo "─────────────────────────────────────────"
	@echo "  make setup          Install Python dependencies"
	@echo "  make check-sa       Verify secrets/sa.json exists"
	@echo "  make infra-plan     Terraform plan (preview GCP resources)"
	@echo "  make infra-apply    Terraform apply (create GCP resources)"
	@echo "  make infra-destroy  Terraform destroy (teardown GCP resources)"
	@echo "  make pipeline       Run Bruin ingestion pipeline"
	@echo "  make all            Full run: infra + pipeline + dbt"
	@echo ""
	@echo "Setup:"
	@echo "  1. cp .env.example .env   then fill in your values"
	@echo "  2. Place your GCP key at: secrets/sa.json"
	@echo "  3. make all"
	@echo ""

# ─── Guards ──────────────────────────────────────────────────────────────────

check-env:
	@test -n "$(GCP_PROJECT_ID)" || ( \
		echo ""; \
		echo "ERROR: GCP_PROJECT_ID is not set."; \
		echo "  1. cp .env.example .env"; \
		echo "  2. Edit .env and fill in your values"; \
		echo "  Note: no need to run 'source .env' — make loads it automatically"; \
		echo ""; \
		exit 1 \
	)
	@echo "✓ GCP_PROJECT_ID = $(GCP_PROJECT_ID)"

check-sa:
	@test -f $(SA_KEY) || ( \
		echo ""; \
		echo "ERROR: $(SA_KEY) not found."; \
		echo "  1. Download your GCP service account key from the GCP Console"; \
		echo "  2. Save it as: secrets/sa.json"; \
		echo "  3. Re-run this command"; \
		echo ""; \
		exit 1 \
	)
	@echo "✓ $(SA_KEY) found"

# ─── Setup ───────────────────────────────────────────────────────────────────

setup:
	pip install -r requirements.txt
	@echo "✓ Python dependencies installed"

# ─── Infrastructure ──────────────────────────────────────────────────────────

infra-plan: check-env check-sa
	cd terraform && terraform init -upgrade && \
	terraform plan \
		-var="project_id=$(GCP_PROJECT_ID)" \
		-var="bucket_name=$(GCS_BUCKET)"

infra-apply: check-env check-sa
	cd terraform && terraform init && \
	terraform apply -auto-approve \
		-var="project_id=$(GCP_PROJECT_ID)" \
		-var="bucket_name=$(GCS_BUCKET)"
	@echo "✓ Infrastructure provisioned"

infra-destroy: check-env check-sa
	@echo "WARNING: This will delete GCS bucket and BigQuery datasets!"
	@read -p "Are you sure? [y/N] " ans && [ "$$ans" = "y" ]
	cd terraform && terraform destroy -auto-approve \
		-var="project_id=$(GCP_PROJECT_ID)" \
		-var="bucket_name=$(GCS_BUCKET)"

# ─── Pipeline ────────────────────────────────────────────────────────────────

pipeline: check-env check-sa
	@echo "--- Pipeline was started---"
	GOOGLE_APPLICATION_CREDENTIALS="$(SA_KEY)" \
	GCS_BUCKET="$(GCS_BUCKET)" \
	bruin run .
	@echo "✓ Pipeline complete"


# ─── Full run ────────────────────────────────────────────────────────────────

all: infra-apply pipeline
	@echo ""
	@echo "🎉 Full pipeline complete!"
	@echo "   → Open Looker Studio and follow dashboard/README.md"

# ─── Clean ───────────────────────────────────────────────────────────────────

clean:
	cd dbt && rm -rf  logs/
	@echo "✓  build artifacts removed"