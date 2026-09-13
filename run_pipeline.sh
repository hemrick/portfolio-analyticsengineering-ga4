#!/usr/bin/env bash
set -euo pipefail

echo "== 1/2: checking dbt BigQuery connection =="
dbt debug --project-dir dbt --profiles-dir dbt

echo "== 2/2: building dbt project =="
dbt build --project-dir dbt --profiles-dir dbt

