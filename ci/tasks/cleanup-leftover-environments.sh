#!/usr/bin/env bash

set -euo pipefail

export BBL_GCP_SERVICE_ACCOUNT_KEY="gcp_service_account.json"
echo "${GCP_SERVICE_ACCOUNT_JSON}" > ${BBL_GCP_SERVICE_ACCOUNT_KEY}

go run github.com/genevieve/leftovers/cmd/leftovers@latest -- -n -i gcp -f "${LEFTOVERS_PREFIX}"
