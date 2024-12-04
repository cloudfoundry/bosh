#!/usr/bin/env bash

set -euo pipefail

export BBL_GCP_SERVICE_ACCOUNT_KEY="gcp_service_account.json"

echo "${GCP_JSON_KEY}" > ${BBL_GCP_SERVICE_ACCOUNT_KEY}

go run "github.com/genevieve/leftovers/cmd/leftovers@${LEFTOVERS_VERSION}" -- \
  --no-confirm \
  --iaas gcp \
  --filter "${LEFTOVERS_PREFIX}"
