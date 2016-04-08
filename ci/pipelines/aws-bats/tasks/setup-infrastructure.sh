#!/usr/bin/env bash

set -e

source bosh-src/ci/pipelines/aws-bats/tasks/utils.sh

check_param aws_access_key_id
check_param aws_secret_access_key
check_param region_name
check_param stack_name

export AWS_ACCESS_KEY_ID=${aws_access_key_id}
export AWS_SECRET_ACCESS_KEY=${aws_secret_access_key}
export AWS_DEFAULT_REGION=${region_name}

cmd="aws cloudformation create-stack \
    --stack-name      ${stack_name} \
    --template-body   file:///${PWD}/bosh-src/ci/pipelines/aws-bats/assets/cloudformation-${stack_name}.template.json \
    --capabilities    CAPABILITY_IAM"

echo "Running: ${cmd}"; ${cmd}
while true; do
  stack_status=$(get_stack_status $stack_name)
  echo "StackStatus ${stack_status}"
  if [ $stack_status == 'CREATE_IN_PROGRESS' ]; then
    echo "sleeping 5s"; sleep 5s
  else
    break
  fi
done

if [ $stack_status != 'CREATE_COMPLETE' ]; then
  echo "cloudformation failed stack info:\n$(get_stack_info $stack_name)"
  exit 1
fi
