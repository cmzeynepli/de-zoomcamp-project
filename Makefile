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

.PHONY: help prereqs setup check-sa check-env infra-plan infra-apply infra-destroy pipeline clean all

help:
	@echo ""
	@echo "Kickstarter Analytics Pipeline — Commands"
	@echo "─────────────────────────────────────────"
	@echo "  make prereqs        Install Terraform + Bruin (and ensure pip)"
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
	@test -n "$(GCS_BUCKET)" || ( \
		echo ""; \
		echo "ERROR: GCS_BUCKET is not set."; \
		echo "  1. cp .env.example .env"; \
		echo "  2. Edit .env and fill in your values"; \
		echo ""; \
		exit 1 \
	)
	@echo "✓ GCS_BUCKET = $(GCS_BUCKET)"
	@test -n "$(GCP_REGION)" || ( \
		echo ""; \
		echo "ERROR: GCP_REGION is not set."; \
		echo "  1. cp .env.example .env"; \
		echo "  2. Edit .env and fill in your values"; \
		echo ""; \
		exit 1 \
	)
	@echo "✓ GCP_REGION = $(GCP_REGION)"
	@test -n "$(BQ_LOCATION)" || ( \
		echo ""; \
		echo "ERROR: BQ_LOCATION is not set (example: US or EU)."; \
		echo "  1. cp .env.example .env"; \
		echo "  2. Edit .env and fill in your values"; \
		echo ""; \
		exit 1 \
	)
	@echo "✓ BQ_LOCATION = $(BQ_LOCATION)"
	@test -n "$(BQ_DATASET_RAW)" || ( \
		echo ""; \
		echo "ERROR: BQ_DATASET_RAW is not set."; \
		echo "  1. cp .env.example .env"; \
		echo "  2. Edit .env and fill in your values"; \
		echo ""; \
		exit 1 \
	)
	@echo "✓ BQ_DATASET_RAW = $(BQ_DATASET_RAW)"
	@test -n "$(BQ_DATASET_DBT)" || ( \
		echo ""; \
		echo "ERROR: BQ_DATASET_DBT is not set."; \
		echo "  1. cp .env.example .env"; \
		echo "  2. Edit .env and fill in your values"; \
		echo ""; \
		exit 1 \
	)
	@echo "✓ BQ_DATASET_DBT = $(BQ_DATASET_DBT)"

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

prereqs:
	@set -e; \
	OS="$$(uname -s)"; \
	echo "Detected OS: $$OS"; \
	if command -v python3 >/dev/null 2>&1; then \
		python3 -m pip --version >/dev/null 2>&1 || (echo "ERROR: pip not available for python3. Please install pip."; exit 1); \
		echo "✓ python3 + pip available"; \
	else \
		echo "ERROR: python3 not found. Please install Python 3 first."; \
		exit 1; \
	fi; \
	if command -v terraform >/dev/null 2>&1; then \
		echo "✓ terraform already installed"; \
	else \
		if [ "$$OS" = "Darwin" ]; then \
			if ! command -v brew >/dev/null 2>&1; then \
				echo "ERROR: Homebrew not found. Install it from https://brew.sh then re-run: make prereqs"; \
				exit 1; \
			fi; \
			brew install terraform; \
		elif [ "$$OS" = "Linux" ]; then \
			if command -v apt-get >/dev/null 2>&1; then \
				sudo apt-get update && sudo apt-get install -y terraform; \
			else \
				echo "ERROR: Unsupported Linux package manager. Please install Terraform manually: https://developer.hashicorp.com/terraform/install"; \
				exit 1; \
			fi; \
		else \
			echo "ERROR: Unsupported OS ($$OS). Please install Terraform manually."; \
			exit 1; \
		fi; \
		echo "✓ terraform installed"; \
	fi; \
	if command -v bruin >/dev/null 2>&1; then \
		echo "✓ bruin already installed"; \
	else \
		curl -LsSf https://getbruin.com/install/cli | sh; \
		echo "✓ bruin installed"; \
		echo "Note: make sure ~/.local/bin is on your PATH for new shells."; \
	fi

setup:
	python3 -m pip install -r requirements.txt
	@echo "✓ Python dependencies installed"

# ─── Infrastructure ──────────────────────────────────────────────────────────

infra-plan: check-env check-sa
	cd terraform && terraform init -upgrade && \
	terraform plan \
		-var="project_id=$(GCP_PROJECT_ID)" \
		-var="bucket_name=$(GCS_BUCKET)" \
		-var="region=$(GCP_REGION)" \
		-var="bq_location=$(BQ_LOCATION)" \
		-var="bq_dataset_raw=$(BQ_DATASET_RAW)" \
		-var="bq_dataset_dbt=$(BQ_DATASET_DBT)"

infra-apply: check-env check-sa
	cd terraform && terraform init && \
	terraform apply -auto-approve \
		-var="project_id=$(GCP_PROJECT_ID)" \
		-var="bucket_name=$(GCS_BUCKET)" \
		-var="region=$(GCP_REGION)" \
		-var="bq_location=$(BQ_LOCATION)" \
		-var="bq_dataset_raw=$(BQ_DATASET_RAW)" \
		-var="bq_dataset_dbt=$(BQ_DATASET_DBT)"
	@echo "✓ Infrastructure provisioned"

infra-destroy: check-env check-sa
	@echo "WARNING: This will delete GCS bucket and BigQuery datasets!"
	@read -p "Are you sure? [y/N] " ans && [ "$$ans" = "y" ]
	cd terraform && terraform destroy -auto-approve \
		-var="project_id=$(GCP_PROJECT_ID)" \
		-var="bucket_name=$(GCS_BUCKET)" \
		-var="region=$(GCP_REGION)" \
		-var="bq_location=$(BQ_LOCATION)" \
		-var="bq_dataset_raw=$(BQ_DATASET_RAW)" \
		-var="bq_dataset_dbt=$(BQ_DATASET_DBT)"

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