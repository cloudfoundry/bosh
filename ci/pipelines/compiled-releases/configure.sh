#!/usr/bin/env bash

set -eu

fly -t production set-pipeline \
 -p compiled-releases \
 -c ./pipeline.yml \
 -l <(lpass show --note "concourse:production pipeline:compiled-releases")
