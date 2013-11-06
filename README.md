# BOSH CloudStack CPI from NTT

A CPI for CloudStack.

## Current Status

Working on merging source code from ZJU-SEL and NTT.

## Known Limitations

* Supports only Basic Zones (Floating IPs are not supported)
* Tested with CloudStack 4.0.0
* There might be some missing features (alpha state)

## How to deploy Micro BOSH

## Inception server

You need a VM on the CloudStack domain where you install a BOSH instance using this CPI. This VM is so-called "inception" server. Intall BOSH CLI and BOSH Deployer gems and run all operations on the VM.

### Set up sudo

The user you use as a

### Why do I need an inception server?

NTT CloudStack CPI creates stemcells, which are VM templates, by copying pre-composed disk images to data volumes which automatically attached by BOSH Deployer. This procedure is same as that of the AWS CPI and requires that the VM where BOSH Deployer works is running on the same domain where you want to deploy your BOSH instance.

## Security Groups

The inception server must have a security group which opens the TCP port 25889, which is used by the temporary BOSH Registry launched by BOSH Deployer.

You also need to create one or more security groups for VMs create by your BOSH instance. We recommend that you create a secrity group which opnes all the TCP and UDP ports for testing.

## Deployment Manifest

Describe the configuration for your MicroBOSH.

```yaml
---
name: firstbosh
logging:
  level: DEBUG
network:
  type: dynamic
resources:
  persistent_disk: 40960
  cloud_properties:
    instance_type: m1.medium
cloud:
  plugin: cloudstack
  properties:
    cloudstack:
      api_key: <your_api_key>
      secret_access_key: <your_secret_access_key>
      endpoint: <your_end_point_url>
      default_security_groups:
        - <security_groups_for_bosh>
      private_key: <path_to_your_private_key>
      state_timeout: 600
      stemcell_public_visibility: true
      default_zone: <default_zone_name>
      default_key_name: <default_keypair_name>
    registry:
      endpoint: http://admin:admin@<ip_address_of_your_inception_sever>:25889
      user: admin
      password: admin
```

## Stemcells

You can generate a stemcell for CloudStack using the `release:create_dev_releas` and `local:build_stemcell` tasks.

E.g.:

```sh
CANDIDATE_BUILD_NUMBER=3 bundle exec rake release:create_dev_release && sudo env PATH=$PATH CANDIDATE_BUILD_NUMBER=3 bundle exec rake "local:build_stemcell[cloudstack,ubuntu]"
```

`CANDIDATE_BUILD_NUMBER` is any number (>= 3) which you like.
