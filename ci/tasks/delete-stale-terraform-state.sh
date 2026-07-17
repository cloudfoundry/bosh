#!/usr/bin/env bash
set -euo pipefail
set -x

echo "${GCP_JSON_KEY}" > /tmp/gcp-key.json
gcloud auth activate-service-account --key-file=/tmp/gcp-key.json

# A missing state file means it was already cleaned up by a prior successful
# terraform destroy, which is fine.
gcloud storage rm "${TERRAFORM_STATE_URI}" || true
