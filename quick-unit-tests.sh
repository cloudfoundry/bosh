#!/usr/bin/env bash
#
# Generated at 2016-02-25 18:26:07 -0800 using:
# 'bosh-tools fly exec ci/pipeline.yml:unit-1.9 ci/pipeline.yml:unit-2.1 -x'

set -e

: ${TEMP_FOLDER:=$(mktemp -d -t fly-exec)}
: ${CONCOURSE_TARGET:=}

[[ "$CONCOURSE_TARGET" != "" ]] && target="-t ${CONCOURSE_TARGET}" || target=""

echo "task outputs will be written to ${TEMP_FOLDER}"

echo "task: test-unit..."

export RUBY_VERSION=${RUBY_VERSION:-1.9.3}
fly ${target} execute -c ci/tasks/test-unit.yml -x -i bosh-src=.

echo "task: test-unit..."

export RUBY_VERSION=${RUBY_VERSION:-2.1.7}
fly ${target} execute -c ci/tasks/test-unit.yml -x -i bosh-src=.

echo "outputs (${TEMP_FOLDER})..."
ls -l ${TEMP_FOLDER}
