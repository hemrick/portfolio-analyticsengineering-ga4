#!/usr/bin/env bash
set -euo pipefail

DBT_PROJECT_DIR="${DBT_PROJECT_DIR:-dbt}"
DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-dbt}"
DBT_SELECT="${DBT_SELECT:-}"
DBT_VARS="${DBT_VARS:-}"
DBT_FULL_REFRESH="${DBT_FULL_REFRESH:-false}"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

args=(
  build
  --project-dir "$DBT_PROJECT_DIR"
  --profiles-dir "$DBT_PROFILES_DIR"
)

if [ -n "$DBT_SELECT" ]; then
  args+=(--select "$DBT_SELECT")
fi

if [ -n "$DBT_VARS" ]; then
  args+=(--vars "$DBT_VARS")
fi

if [ "$DBT_FULL_REFRESH" = "true" ]; then
  args+=(--full-refresh)
fi

echo "== checking dbt BigQuery connection =="
uv run dbt debug --project-dir "$DBT_PROJECT_DIR" --profiles-dir "$DBT_PROFILES_DIR"

echo "== running dbt ${args[*]} =="
uv run dbt "${args[@]}"
