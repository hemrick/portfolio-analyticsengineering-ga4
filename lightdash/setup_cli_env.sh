if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

export PATH="$(pwd)/.venv/bin:$PATH"
export GCP_SERVICE_ACCOUNT_LOAD_AND_DBT="${GCP_SERVICE_ACCOUNT_LOAD_AND_DBT:-$(pwd)/service-account.json}"
export DBT_BQ_PROJECT="${DBT_BQ_PROJECT:-your-gcp-project-id}"
export DBT_BQ_DATASET="${DBT_BQ_DATASET:-analytics_engineering_ga4}"
export DBT_BQ_LOCATION="${DBT_BQ_LOCATION:-US}"

case "$GCP_SERVICE_ACCOUNT_LOAD_AND_DBT" in
  /*) ;;
  *) export GCP_SERVICE_ACCOUNT_LOAD_AND_DBT="$(pwd)/${GCP_SERVICE_ACCOUNT_LOAD_AND_DBT#./}" ;;
esac
