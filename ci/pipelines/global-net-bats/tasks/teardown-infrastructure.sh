#!/usr/bin/env bash

set -e

source bosh-src/ci/pipelines/global-net-bats/tasks/utils.sh

check_param aws_access_key_id
check_param aws_secret_access_key
check_param region_name
check_param stack_name

export AWS_ACCESS_KEY_ID=${aws_access_key_id}
export AWS_SECRET_ACCESS_KEY=${aws_secret_access_key}
export AWS_DEFAULT_REGION=${region_name}

cmd="aws cloudformation delete-stack --stack-name ${stack_name}"
echo "Running: ${cmd}"; ${cmd}

while true; do
  stack_status=$(get_stack_status $stack_name)
  echo "StackStatus ${stack_status}"
  if [[ -z "$stack_status" ]]; then #get empty status due to stack not existed on aws
    echo "No stack found"; break
    break
  elif [ $stack_status == 'DELETE_IN_PROGRESS' ]; then
    echo "${stack_status}: sleeping 5s"; sleep 5s
  else
    echo "Expecting the stack to either be deleted or in the process of being deleted but was ${stack_status}"
    echo $(get_stack_info $stack_name)
    exit 1
  fi
done
