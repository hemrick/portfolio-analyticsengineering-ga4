#!/usr/bin/env bash
set -euo pipefail

copy_if_missing() {
  local source_file="$1"
  local target_file="$2"

  if [ -f "$target_file" ]; then
    echo "exists: $target_file"
  else
    cp "$source_file" "$target_file"
    echo "created: $target_file"
  fi
}

copy_if_missing ".env.example" ".env"
copy_if_missing "lightdash/.env.example" "lightdash/.env"

uv sync

cat <<'MESSAGE'

Next steps:
1. Save your real BigQuery service-account key as service-account.json.
2. Confirm DBT_BQ_PROJECT, DBT_BQ_DATASET, and DBT_BQ_LOCATION in .env.
3. Run: uv run dbt debug --project-dir dbt --profiles-dir dbt
MESSAGE
