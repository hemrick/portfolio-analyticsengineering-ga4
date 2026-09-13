# GA4 Analytics Engineering Portfolio Project

This public portfolio project shows an end-to-end analytics engineering workflow:
raw Google Analytics 4 ecommerce events in BigQuery become a tested dbt mart,
then a governed semantic layer and dashboard metrics in Lightdash.

The use case is intentionally concrete: monitor the Google Merch Store checkout
funnel and expose session conversion KPIs that business users can slice by time
and acquisition source.

Read the full portfolio article:
[Analytics Engineering Use Case](https://www.emerictrossat.com/analytics-engineering-usecase)

## What It Demonstrates

- BigQuery modeling on the public GA4 ecommerce export:
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
- dbt Core transformations with source tests, model tests, incremental
  partition overwrite, and explicit run windows
- Lightdash semantic-layer definitions stored in dbt YAML next to the model
- DataOps practices: Dockerized execution, separate local app runtime, CI
  validation, deployment scripts, and secret-safe templates

## Repository Map

```text
dbt/                         dbt project, marts, source tests, semantic YAML
lightdash/                   Lightdash local runtime and Cloud Run deployment
scripts/                     first-time setup and recurring operation helpers
docs/                        setup, run, architecture, and feature notes
.github/workflows/ci.yml     public CI checks that do not require real secrets
Dockerfile                   reproducible dbt runner image
docker-compose.yml           dbt job runner only
```

The project deliberately separates the two deployable workloads:

```text
dbt
  -> builds and tests BigQuery tables

Lightdash
  -> runs the BI app and publishes the semantic layer compiled from dbt YAML
```

## Breakdown of the Analytics Workflow Starting From the Dashboard

This project is documented from the business-facing layer backward, because
that is how analytics work is usually consumed and debugged.

1. Dashboard KPI in Lightdash

   The dashboard starts with a business metric: purchase session rate. A user
   can slice it by date or traffic source without rewriting SQL.

2. Semantic layer in dbt YAML

   Metric logic is defined in
   `dbt/models/marts/fct_checkout_funnel_sessions.yml`, next to the model
   contract. Lightdash reads this YAML to create dimensions and metrics such as:

   ```text
   sessions
   purchase sessions
   purchase session rate = SAFE_DIVIDE(${purchase_sessions}, ${sessions})
   checkout to purchase rate
   ```

3. dbt transformation logic

   The SQL model
   `dbt/models/marts/fct_checkout_funnel_sessions.sql` transforms raw GA4
   events into one row per session. It creates binary funnel flags such as
   `has_begin_checkout`, `has_add_payment_info`, and `has_purchase`, which makes
   BI metrics simple and consistent.

4. BigQuery source modeling

   The source is the public GA4 ecommerce export, stored as daily wildcard
   tables. dbt run variables compile into `_TABLE_SUFFIX` filters so each run
   scans only the requested date window.

5. DataOps layer

   Docker, scripts, env templates, and CI make the workflow reproducible:
   first-time setup is separate from recurring dbt jobs, and dbt model builds
   are separate from Lightdash app deployment and semantic-layer deployment.

## Quick Start

First-time local setup:

```bash
./scripts/first_time_setup.sh
```

Then place a real BigQuery service-account key at:

```text
service-account.json
```

Run the dbt pipeline:

```bash
./scripts/run_dbt_job.sh
```

Validate the Lightdash semantic layer:

```bash
./scripts/compile_semantic_layer.sh
```

Deploy the semantic layer to an already-running Lightdash instance:

```bash
./scripts/deploy_semantic_layer.sh
```

## Environment

Copy the example env files before running the project:

```bash
cp .env.example .env
cp lightdash/.env.example lightdash/.env
```

The root `.env` configures dbt and BigQuery:

```bash
GCP_SERVICE_ACCOUNT_LOAD_AND_DBT=./service-account.json
DBT_BQ_PROJECT=your-gcp-project-id
DBT_BQ_DATASET=analytics_engineering_ga4
DBT_BQ_LOCATION=US
```

The real `service-account.json` file is required only for workflows that compile
or run dbt against BigQuery. It must stay local and uncommitted.

`lightdash/.env` configures the local Lightdash app, metadata Postgres database,
and MinIO object storage. It is for local app runtime only and does not replace
the root dbt `.env`.

## Script Requirements

| Script | Requires GCP? | Purpose |
| --- | --- | --- |
| `scripts/first_time_setup.sh` | No, except dependency install network access | Creates local env files and installs Python/dbt dependencies. |
| `scripts/run_dbt_job.sh` | Yes | Runs `dbt debug` and `dbt build` against BigQuery. |
| `scripts/compile_semantic_layer.sh` | Yes for dbt profile credential loading; Lightdash CLI optional | Parses and compiles dbt, then validates Lightdash semantics when the CLI is installed. |
| `scripts/deploy_semantic_layer.sh` | Yes | Publishes dbt YAML semantic definitions to an already-running Lightdash project. |
| `lightdash/cloud-run/deploy.sh` | Yes | Provisions and deploys the self-hosted Lightdash app on Google Cloud Run. |

## Public Safety

This repository is designed to be public. Real service-account keys, local
`.env` files, virtual environments, dbt build artifacts, and logs are ignored by
git. Commit only `*.example` files for credentials and configuration.
