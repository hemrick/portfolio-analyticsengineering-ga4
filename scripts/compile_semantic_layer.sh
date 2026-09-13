#!/usr/bin/env bash
set -euo pipefail

DBT_PROJECT_DIR="${DBT_PROJECT_DIR:-$(pwd)/dbt}"
DBT_PROFILES_DIR="${DBT_PROFILES_DIR:-$(pwd)/dbt}"
LIGHTDASH_SELECT="${LIGHTDASH_SELECT:-fct_checkout_funnel_sessions}"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

uv run dbt parse \
  --project-dir "$DBT_PROJECT_DIR" \
  --profiles-dir "$DBT_PROFILES_DIR" \
  --no-populate-cache

uv run dbt compile \
  --project-dir "$DBT_PROJECT_DIR" \
  --profiles-dir "$DBT_PROFILES_DIR" \
  --select "$LIGHTDASH_SELECT" \
  --no-populate-cache

if command -v lightdash >/dev/null 2>&1; then
  lightdash validate \
    --project-dir "$DBT_PROJECT_DIR" \
    --profiles-dir "$DBT_PROFILES_DIR" \
    --select "$LIGHTDASH_SELECT" \
    --only tables \
    --validate-warehouse-columns \
    --no-version-check
else
  echo "lightdash CLI not found; dbt parse and compile completed."
fi
