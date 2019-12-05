#!/bin/sh
bosh create-env \
  ${BBL_STATE_DIR}/bosh-deployment/bosh.yml \
  --state  ${BBL_STATE_DIR}/vars/bosh-state.json \
  --vars-store  ${BBL_STATE_DIR}/vars/director-vars-store.yml \
  --vars-file  ${BBL_STATE_DIR}/vars/director-vars-file.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/gcp/cpi.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/jumpbox-user.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/uaa.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/local-bosh-release.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/credhub.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/experimental/bpm.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/experimental/blobstore-https.yml \
  -o  ${BBL_STATE_DIR}/bbl-ops-files/gcp/bosh-director-ephemeral-ip-ops.yml \
  -o  ${BBL_STATE_DIR}/bbl-ops-files/enable-hm-alerts.yml \
  -o  ${BBL_STATE_DIR}/bosh-deployment/enable-signed-urls.yml \
  --var-file  gcp_credentials_json="${BBL_GCP_SERVICE_ACCOUNT_KEY_PATH}" \
  -v project_id="${BBL_GCP_PROJECT_ID}" \
  -v zone="${BBL_GCP_ZONE}" \
  -v local_bosh_release="$(echo ${BBL_STATE_DIR}/../../candidate-release/*.tgz)"
