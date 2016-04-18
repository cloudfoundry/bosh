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

ATTEMPTS=2
cmd="aws cloudformation delete-stack --stack-name ${stack_name}"

while [ $ATTEMPTS -gt 0 ]; do
  EXIT_STATUS=0
  echo "Running: ${cmd}"
  ${cmd}
  while : ; do
    stack_status=$(get_stack_status $stack_name)
    echo "StackStatus ${stack_status}"
    if [[ -z "$stack_status" ]]; then #get empty status due to stack not existed on aws
      echo "No stack found";
      ATTEMPTS=0
      break
    elif [ $stack_status == 'DELETE_IN_PROGRESS' ]; then
      echo "${stack_status}: sleeping 5s"; sleep 5s
    else
      echo "Expecting the stack to either be deleted or in the process of being deleted but was ${stack_status}"
      echo $(get_stack_info $stack_name)
      EXIT_STATUS=1
      break
    fi
  done
  ATTEMPTS=$(( $ATTEMPTS - 1 ))
done

exit $EXIT_STATUS
