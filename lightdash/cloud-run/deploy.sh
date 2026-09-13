#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

PROJECT_ID="${PROJECT_ID:?Set PROJECT_ID to your Google Cloud project id.}"
REGION="${REGION:-us-central1}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-analytics-engineering-ga4@$PROJECT_ID.iam.gserviceaccount.com}"
INSTANCE_NAME="${INSTANCE_NAME:-analytics-engineering-ga4-lightdash-postgres}"
DB_NAME="${DB_NAME:-lightdash}"
DB_USER="${DB_USER:-lightdash}"
SERVICE_NAME="${SERVICE_NAME:-analytics-engineering-ga4-lightdash}"
LIGHTDASH_IMAGE="${LIGHTDASH_IMAGE:-docker.io/lightdash/lightdash:2.17.0}"

PG_PASSWORD_SECRET="${PG_PASSWORD_SECRET:-lightdash-pg-password}"
LIGHTDASH_SECRET_NAME="${LIGHTDASH_SECRET_NAME:-lightdash-secret}"
GCS_BUCKET="${GCS_BUCKET:-${PROJECT_ID}-lightdash-storage}"
S3_ACCESS_KEY_SECRET="${S3_ACCESS_KEY_SECRET:-lightdash-s3-access-key}"
S3_SECRET_KEY_SECRET="${S3_SECRET_KEY_SECRET:-lightdash-s3-secret-key}"
CLOUD_RUN_FLAGS_FILE="${CLOUD_RUN_FLAGS_FILE:-$SCRIPT_DIR/cloud-run-flags.yaml}"

secret_has_latest_version() {
  local secret_name="$1"
  gcloud secrets versions access latest \
    --secret "$secret_name" \
    --project "$PROJECT_ID" >/dev/null 2>&1
}

upsert_secret_value() {
  local secret_name="$1"
  local secret_value="$2"

  if gcloud secrets describe "$secret_name" --project "$PROJECT_ID" >/dev/null 2>&1; then
    printf '%s' "$secret_value" | gcloud secrets versions add "$secret_name" \
      --project "$PROJECT_ID" \
      --data-file=-
  else
    printf '%s' "$secret_value" | gcloud secrets create "$secret_name" \
      --project "$PROJECT_ID" \
      --data-file=-
  fi
}

gcloud config set project "$PROJECT_ID"

gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  storage.googleapis.com

if ! gcloud sql instances describe "$INSTANCE_NAME" --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud sql instances create "$INSTANCE_NAME" \
    --project "$PROJECT_ID" \
    --database-version POSTGRES_15 \
    --region "$REGION" \
    --tier db-f1-micro \
    --edition ENTERPRISE
fi

if ! gcloud sql databases describe "$DB_NAME" --instance "$INSTANCE_NAME" --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud sql databases create "$DB_NAME" \
    --instance "$INSTANCE_NAME" \
    --project "$PROJECT_ID"
fi

if ! gcloud secrets describe "$PG_PASSWORD_SECRET" --project "$PROJECT_ID" >/dev/null 2>&1; then
  openssl rand -base64 32 | tr -d '\r\n' | gcloud secrets create "$PG_PASSWORD_SECRET" \
    --project "$PROJECT_ID" \
    --data-file=-
fi

if ! gcloud secrets describe "$LIGHTDASH_SECRET_NAME" --project "$PROJECT_ID" >/dev/null 2>&1; then
  openssl rand -hex 32 | tr -d '\r\n' | gcloud secrets create "$LIGHTDASH_SECRET_NAME" \
    --project "$PROJECT_ID" \
    --data-file=-
fi

if ! gcloud storage buckets describe "gs://$GCS_BUCKET" --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://$GCS_BUCKET" \
    --project "$PROJECT_ID" \
    --location US \
    --uniform-bucket-level-access
fi

gcloud storage buckets add-iam-policy-binding "gs://$GCS_BUCKET" \
  --project "$PROJECT_ID" \
  --member "serviceAccount:$SERVICE_ACCOUNT" \
  --role roles/storage.objectAdmin >/dev/null

if ! secret_has_latest_version "$S3_ACCESS_KEY_SECRET" || \
   ! secret_has_latest_version "$S3_SECRET_KEY_SECRET"; then
  TMP_HMAC_FILE="$(mktemp)"
  gcloud storage hmac create "$SERVICE_ACCOUNT" \
    --project "$PROJECT_ID" \
    --format=json > "$TMP_HMAC_FILE"
  S3_ACCESS_KEY="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["metadata"]["accessId"])' "$TMP_HMAC_FILE")"
  S3_SECRET_KEY="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["secret"])' "$TMP_HMAC_FILE")"

  upsert_secret_value "$S3_ACCESS_KEY_SECRET" "$S3_ACCESS_KEY"
  upsert_secret_value "$S3_SECRET_KEY_SECRET" "$S3_SECRET_KEY"

  rm -f "$TMP_HMAC_FILE"
fi

TMP_PASSWORD_FILE="$(mktemp)"
gcloud secrets versions access latest \
  --secret "$PG_PASSWORD_SECRET" \
  --project "$PROJECT_ID" > "$TMP_PASSWORD_FILE"
TMP_SANITIZED_PASSWORD_FILE="$(mktemp)"
tr -d '\r\n' < "$TMP_PASSWORD_FILE" > "$TMP_SANITIZED_PASSWORD_FILE"
if ! cmp -s "$TMP_PASSWORD_FILE" "$TMP_SANITIZED_PASSWORD_FILE"; then
  gcloud secrets versions add "$PG_PASSWORD_SECRET" \
    --project "$PROJECT_ID" \
    --data-file="$TMP_SANITIZED_PASSWORD_FILE"
  mv "$TMP_SANITIZED_PASSWORD_FILE" "$TMP_PASSWORD_FILE"
else
  rm -f "$TMP_SANITIZED_PASSWORD_FILE"
fi

if ! gcloud sql users list --instance "$INSTANCE_NAME" --project "$PROJECT_ID" --format="value(name)" | grep -qx "$DB_USER"; then
  gcloud sql users create "$DB_USER" \
    --instance "$INSTANCE_NAME" \
    --project "$PROJECT_ID" \
    --password="$(cat "$TMP_PASSWORD_FILE")"
else
  gcloud sql users set-password "$DB_USER" \
    --instance "$INSTANCE_NAME" \
    --project "$PROJECT_ID" \
    --password="$(cat "$TMP_PASSWORD_FILE")"
fi

rm -f "$TMP_PASSWORD_FILE"

INSTANCE_CONNECTION_NAME="$PROJECT_ID:$REGION:$INSTANCE_NAME"
SERVICE_URL="${SITE_URL:-}"
if [ -z "$SERVICE_URL" ]; then
  SERVICE_URL="$(gcloud run services describe "$SERVICE_NAME" \
    --project "$PROJECT_ID" \
    --region "$REGION" \
    --format='value(status.url)' 2>/dev/null || true)"
fi
if [ -z "$SERVICE_URL" ]; then
  SERVICE_URL="http://localhost:8080"
fi

gcloud run deploy "$SERVICE_NAME" \
  --project "$PROJECT_ID" \
  --image "$LIGHTDASH_IMAGE" \
  --region "$REGION" \
  --service-account "$SERVICE_ACCOUNT" \
  --add-cloudsql-instances "$INSTANCE_CONNECTION_NAME" \
  --flags-file "$CLOUD_RUN_FLAGS_FILE" \
  --set-env-vars "PGHOST=/cloudsql/$INSTANCE_CONNECTION_NAME,PGPORT=5432,PGUSER=$DB_USER,PGDATABASE=$DB_NAME,SITE_URL=$SERVICE_URL,SECURE_COOKIES=true,TRUST_PROXY=true,ALLOW_MULTIPLE_ORGS=false,SCHEDULER_ENABLED=true,GROUPS_ENABLED=true,S3_ENDPOINT=https://storage.googleapis.com,S3_BUCKET=$GCS_BUCKET,S3_REGION=us-east-1,S3_FORCE_PATH_STYLE=true" \
  --set-secrets "PGPASSWORD=$PG_PASSWORD_SECRET:latest,LIGHTDASH_SECRET=$LIGHTDASH_SECRET_NAME:latest,S3_ACCESS_KEY=$S3_ACCESS_KEY_SECRET:latest,S3_SECRET_KEY=$S3_SECRET_KEY_SECRET:latest"

SERVICE_URL="$(gcloud run services describe "$SERVICE_NAME" \
  --project "$PROJECT_ID" \
  --region "$REGION" \
  --format='value(status.url)')"

echo "Lightdash URL: $SERVICE_URL"
