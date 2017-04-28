#!/usr/bin/env bash

source /etc/profile.d/chruby.sh
chruby 2.1.7

set -e

function cp_artifacts {
  mv $HOME/.bosh director-state/
  cp director.yml director-creds.yml director-state.json director-state/
}
trap cp_artifacts EXIT

mv bosh-cli/bosh-cli-* /usr/local/bin/bosh-cli
chmod +x /usr/local/bin/bosh-cli

export AWS_ACCESS_KEY_ID=$BOSH_access_key_id
export AWS_SECRET_ACCESS_KEY=$BOSH_secret_access_key
export AWS_DEFAULT_REGION=$BOSH_region
aws_keypair_name=$(cat environment/metadata | jq --raw-output .BlobstoreBucket | rev | cut -d '-' -f1,2 | rev)
aws ec2 delete-key-pair --key-name $aws_keypair_name

function fromEnvironment() {
  local key="$1"
  local environment=environment/metadata
  cat $environment | jq -r "$key"
}

export BOSH_internal_cidr=$(fromEnvironment '.PublicCIDR')
export BOSH_az=$(fromEnvironment '.AvailabilityZone')
export BOSH_internal_gw=$(fromEnvironment '.PublicGateway')
export BOSH_reserved_range="[$(fromEnvironment '.ReservedRange')]"
export BOSH_subnet_id=$(fromEnvironment '.PublicSubnetID')
export BOSH_default_security_groups="[$(fromEnvironment '.SecurityGroupID')]"
export BOSH_default_key_name="${aws_keypair_name}"

cat > director-creds.yml <<EOF
internal_ip: $(fromEnvironment '.DirectorStaticIP')
external_ip: $(fromEnvironment '.DirectorEIP')
EOF

bosh-cli interpolate bosh-deployment/bosh.yml \
  -o bosh-deployment/aws/cpi.yml \
  -o bosh-deployment/external-ip-with-registry-not-recommended.yml \
  -o bosh-deployment/powerdns.yml \
  -o bosh-deployment/local-bosh-release.yml \
  --vars-store director-creds.yml \
  -v local_bosh_release=$(realpath bosh-release/*.tgz) \
  -v dns_recursor_ip=8.8.8.8 \
  -v director_name=bats-director \
  --var-file private_key=<(aws ec2 create-key-pair --key-name $aws_keypair_name | jq --raw-output .KeyMaterial) \
  --vars-env "BOSH" > director.yml


bosh-cli create-env --state director-state.json director.yml -l director-creds.yml

# todo cloud-config?
