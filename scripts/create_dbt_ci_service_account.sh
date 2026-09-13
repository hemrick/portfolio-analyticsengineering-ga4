#!/usr/bin/env bash
set -euo pipefail

target_file="${1:-${TMPDIR:-/tmp}/dbt-ci-service-account.json}"
private_key_file="$(mktemp)"
trap 'rm -f "$private_key_file"' EXIT

openssl genrsa -out "$private_key_file" 2048 >/dev/null 2>&1

python3 - "$private_key_file" "$target_file" <<'PY'
import json
import pathlib
import sys

private_key_path = pathlib.Path(sys.argv[1])
target_path = pathlib.Path(sys.argv[2])
target_path.parent.mkdir(parents=True, exist_ok=True)

target_path.write_text(
    json.dumps(
        {
            "type": "service_account",
            "project_id": "ci-placeholder-project",
            "private_key_id": "ci-placeholder-private-key-id",
            "private_key": private_key_path.read_text(),
            "client_email": "dbt-ci@ci-placeholder-project.iam.gserviceaccount.com",
            "client_id": "000000000000000000000",
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
            "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/dbt-ci%40ci-placeholder-project.iam.gserviceaccount.com",
            "universe_domain": "googleapis.com",
        },
        indent=2,
    )
    + "\n"
)

print(target_path)
PY
