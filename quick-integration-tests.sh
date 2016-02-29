#!/usr/bin/env bash
#
# Generated at 2016-02-25 18:34:22 -0800 using:
# 'bosh-tools fly exec ci/pipeline.yml:integration-2.1-postgres -x'

set -e

: ${TEMP_FOLDER:=$(mktemp -d -t fly-exec)}
: ${CONCOURSE_TARGET:=}

[[ "$CONCOURSE_TARGET" != "" ]] && target="-t ${CONCOURSE_TARGET}" || target=""

echo "task outputs will be written to ${TEMP_FOLDER}"

echo "task: test-integration..."

export RUBY_VERSION=${RUBY_VERSION:-2.1.7}
export DB=${DB:-postgresql}
export LOG_LEVEL=${LOG_LEVEL:-INFO}
export NUM_GROUPS=${NUM_GROUPS:-8}
fly ${target} execute -c ci/tasks/test-integration.yml -x -i bosh-src=.

echo "outputs (${TEMP_FOLDER})..."
ls -l ${TEMP_FOLDER}
