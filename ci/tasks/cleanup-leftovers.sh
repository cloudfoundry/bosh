#!/usr/bin/env bash

set -euo pipefail
set -x

export BBL_GCP_SERVICE_ACCOUNT_KEY="gcp_service_account.json"

set +x # hide credentials
echo "${GCP_JSON_KEY}" > ${BBL_GCP_SERVICE_ACCOUNT_KEY}
set -x

go run "github.com/genevieve/leftovers/cmd/leftovers@${LEFTOVERS_VERSION}" -- \
  --debug \
  --no-confirm \
  --iaas gcp \
  --filter "${LEFTOVERS_PREFIX}"
