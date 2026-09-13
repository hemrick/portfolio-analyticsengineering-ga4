# Lightdash

This folder contains Lightdash runtime and deployment files only. The dbt
project remains under `../dbt`, and Lightdash semantic definitions should be
added to the dbt model YAML files.

## Local Run

Create the ignored local environment file:

```bash
cp lightdash/.env.example lightdash/.env
```

The Lightdash app image should stay aligned with the local Lightdash CLI version
used for `validate`, `preview`, and `deploy`.

Keep `SCHEDULER_ENABLED=true` for local and Cloud Run Lightdash runtimes. The
CLI polls server-side scheduler jobs during validation and deployment.

Start Lightdash with an isolated Compose project name:

```bash
docker compose \
  --project-name analytics-engineering-ga4-lightdash \
  --env-file lightdash/.env \
  -f lightdash/docker-compose.yml \
  up --detach
```

Open:

```text
http://localhost:8080
```

MinIO console:

```text
http://localhost:9001
```

Stop the local stack:

```bash
docker compose \
  --project-name analytics-engineering-ga4-lightdash \
  --env-file lightdash/.env \
  -f lightdash/docker-compose.yml \
  down
```

## Development Workflow

Lightdash semantic definitions live in the dbt YAML files under `dbt/`. For
example, the checkout funnel semantic layer is defined next to the mart:

```text
dbt/models/marts/fct_checkout_funnel_sessions.yml
```

The local workflow is:

```text
edit dbt SQL/YAML
  -> validate dbt compilation and tests
  -> validate Lightdash semantic compilation
  -> preview or deploy to Lightdash
```

### 1. Validate dbt

From the repository root, first make sure dbt can parse and compile the project:

```bash
uv run dbt parse \
  --project-dir dbt \
  --profiles-dir dbt

uv run dbt compile \
  --project-dir dbt \
  --profiles-dir dbt \
  --select fct_checkout_funnel_sessions
```

Then build the model and its tests:

```bash
uv run dbt build \
  --project-dir dbt \
  --profiles-dir dbt \
  --select fct_checkout_funnel_sessions
```

If the model schema changed, for example new Lightdash dimensions were added as
new BigQuery columns, run an intentional full refresh:

```bash
uv run dbt build \
  --project-dir dbt \
  --profiles-dir dbt \
  --select fct_checkout_funnel_sessions \
  --full-refresh
```

This project keeps `on_schema_change='fail'` on the incremental checkout funnel
mart so dbt does not silently mutate the table shape.

### 2. Set Lightdash CLI Environment

The Lightdash CLI shells out to `dbt`, while this project installs dbt through
`uv`. From the repository root, source the helper script before running
Lightdash commands:

```bash
source lightdash/setup_cli_env.sh
```

The script exports:

```bash
export PATH="$(pwd)/.venv/bin:$PATH"
export GCP_SERVICE_ACCOUNT_LOAD_AND_DBT="${GCP_SERVICE_ACCOUNT_LOAD_AND_DBT:-$(pwd)/service-account.json}"
export DBT_BQ_PROJECT="${DBT_BQ_PROJECT:-your-gcp-project-id}"
export DBT_BQ_DATASET="${DBT_BQ_DATASET:-analytics_engineering_ga4}"
export DBT_BQ_LOCATION="${DBT_BQ_LOCATION:-US}"
```

Use an absolute service-account key path for Lightdash CLI commands. Do not
commit the real JSON key.

### 3. Validate Lightdash

Validate the semantic layer before previewing or deploying:

```bash
lightdash validate \
  --project-dir "$(pwd)/dbt" \
  --profiles-dir "$(pwd)/dbt" \
  --select fct_checkout_funnel_sessions \
  --only tables \
  --validate-warehouse-columns \
  --no-version-check
```

This checks that Lightdash can compile the dbt model into a Lightdash Table and
that referenced warehouse columns exist.

### 4. Preview Lightdash Changes

Use a preview project for a Looker Dev Mode style check:

```bash
lightdash preview \
  --project-dir "$(pwd)/dbt" \
  --profiles-dir "$(pwd)/dbt" \
  --validate-warehouse-columns \
  --no-version-check
```

Open the preview URL, confirm the Table, dimensions, metrics, and KPI numbers,
then stop the preview from the terminal when done.

### 5. Deploy Lightdash Changes

Deploy only after dbt and Lightdash validation pass:

```bash
lightdash deploy \
  --project-dir "$(pwd)/dbt" \
  --profiles-dir "$(pwd)/dbt" \
  --validate-warehouse-columns \
  --no-version-check \
  --assume-yes
```

`dbt build` updates the physical BigQuery tables. `lightdash deploy` publishes
the semantic-layer configuration from dbt YAML to Lightdash.

## Boundary

- Root `docker-compose.yml`: dbt runner only.
- `lightdash/docker-compose.yml`: Lightdash app, local metadata Postgres, and
  local MinIO object storage.
- `lightdash/cloud-run/cloud-run-flags.yaml`: readable static Cloud Run runtime
  settings such as CPU, memory, public access, and startup probe.
- `lightdash/cloud-run/deploy.sh`: GCP resource provisioning and dynamic Cloud
  Run deployment values such as image, service account, env vars, and secrets.
- `dbt/`: transformation logic and semantic layer YAML.
- Cloud Run: Lightdash app only, backed by Cloud SQL Postgres and Cloud Storage
  exposed through S3-compatible credentials.
