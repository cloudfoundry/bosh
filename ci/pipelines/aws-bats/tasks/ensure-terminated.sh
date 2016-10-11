#!/usr/bin/env bash

set -e

: ${AWS_ACCESS_KEY_ID:?}
: ${AWS_SECRET_ACCESS_KEY:?}
: ${AWS_DEFAULT_REGION:?}

metadata=$(cat environment/metadata)
vpc_id=$(echo ${metadata} | jq --raw-output ".VPCID")

if [ ! -z "${vpc_id}" ] ; then
  instances=$(aws ec2 describe-instances --query "Reservations[*].Instances[*].InstanceId[]" --filters "Name=vpc-id,Values=${vpc_id}" | jq '.[]' --raw-output)
  instance_list=$(echo ${instances} | sed "s/[\n\r]+/ /g")

  # if it's not an empty string (of any length)...
  if [ ! -z "${instance_list// }" ] ; then
    aws ec2 terminate-instances --instance-ids ${instance_list}
  fi
fi
