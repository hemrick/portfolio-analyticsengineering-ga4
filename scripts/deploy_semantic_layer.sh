#!/usr/bin/env bash
set -euo pipefail

DBT_PROJECT_DIR="${DBT_PROJECT_DIR:-$(pwd)/dbt}"
DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-$(pwd)/dbt}"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

if ! command -v lightdash >/dev/null 2>&1; then
  echo "lightdash CLI is required for semantic-layer deployment." >&2
  exit 1
fi

lightdash deploy \
  --project-dir "$DBT_PROJECT_DIR" \
  --profiles-dir "$DBT_PROFILES_DIR" \
  --validate-warehouse-columns \
  --no-version-check \
  --assume-yes
