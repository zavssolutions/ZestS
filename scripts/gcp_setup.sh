#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/gcp_setup.sh <PROJECT_ID> <BUCKET_NAME> <SERVICE_ACCOUNT_NAME>

PROJECT_ID="${1:?project id required}"
BUCKET_NAME="${2:?bucket name required}"
SA_NAME="${3:-zests-storage-sa}"

# Requires authenticated gcloud session with project owner/editor access.
gcloud config set project "$PROJECT_ID"

gcloud services enable \
  storage.googleapis.com \
  iam.googleapis.com \
  firebase.googleapis.com \
  cloudresourcemanager.googleapis.com

if ! gsutil ls -b "gs://${BUCKET_NAME}" >/dev/null 2>&1; then
  gsutil mb -l asia-south1 "gs://${BUCKET_NAME}"
fi

gcloud iam service-accounts create "$SA_NAME" --display-name "ZestS Storage Service Account" || true

SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gsutil iam ch "serviceAccount:${SA_EMAIL}:objectAdmin" "gs://${BUCKET_NAME}"

gcloud iam service-accounts keys create zests-storage-key.json --iam-account "$SA_EMAIL"

echo "Created service account key: zests-storage-key.json"
echo "Set this JSON in Render env var: GCP_STORAGE_CREDENTIALS_JSON"
