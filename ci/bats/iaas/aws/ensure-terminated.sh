#!/usr/bin/env bash

set -e

: ${AWS_ACCESS_KEY_ID:?}
: ${AWS_SECRET_ACCESS_KEY:?}
: ${AWS_DEFAULT_REGION:?}

if [ -n "${AWS_ROLE_ARN}" ]; then
  aws configure --profile creds_account set aws_access_key_id "${AWS_ACCESS_KEY_ID}"
  aws configure --profile creds_account set aws_secret_access_key "${AWS_SECRET_ACCESS_KEY}"
  aws configure --profile resource_account set source_profile "creds_account"
  aws configure --profile resource_account set role_arn "${AWS_ROLE_ARN}"
  aws configure --profile resource_account set region "${AWS_DEFAULT_REGION}"
  unset AWS_DEFAULT_REGION
  export AWS_PROFILE=resource_account
fi

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
