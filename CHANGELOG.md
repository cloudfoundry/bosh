## 2749

Improvements:

  * director: Do not run the first errand if there is only one errand [7c37a8a]

## 2748

Improvements:

  * director: Add configurable ssl options for the director nginx [6e497ef]
  * agent: Bump bosh-agent to disable SSLv3 support (agent's micro server) [9ec67d5]

Bug Fixes:

  * director: Correct invalid default value for config_drive for OpenStack [9e2d9db]

## 2745

Improvements:

  * stemcell: aws: Resume producing light stemcells for non hvm virtualization [c10fb93]

## 2744

New Features:

  * cli: Added `bosh errands` command to list for deployment [PR 625]

Improvements:

  * director: update bosh_vcloud_cpi gem version 0.7.1
       to pull in fixes for missing CPI methods [f32af44]
  * director: Refactored NatsRpc to handle all director NATS calls
       to fix occasional worker hangs [870dd6f]
  * director: Run NATS.connect on EM thread to fix occasional worker hangs [94e7d6a]

## 2743

New Features:

  * cpi: openstack: Add openstack CPI multiple manual networks support
       for Ubuntu 14.04 using BOSH agent [c239db2]

Improvements:

  * director: Refactored transitive dependency resolution to fix bug
       with importing releases [80aade1]
  * cpi: Bosh::Registry#update_settings considers 2xx successful
       to be compatible with new registry used by bosh-micro cli [01f26f2]
  * cpi: Add bin/aws_cpi to bosh_aws_cpi as preparation for externalizing AWS CPI [8c31679]

## 2739

New Features:

  * cpi: openstack: Make config drive config optional for open stack [0d77bd4]
  * cpi: openstack: Allow to configure CPI to use either cdrom or disk
       for config-drive mechanism [2696cdb]
  * stemcell: aws: Build hvm light aws stemcell in addition to PV [2754b45]

## 2732

New Features:

  * cpi: openstack: Add use_config_drive [6a444ae]

Improvements:

  * stemcell: Lock down os_image_version in code [9de9ed3]
  * stemcell: openstack: Convert openstack image to qcow2 0.10 compat [679f670]
  * stemcell: ubuntu: Symlink vim to vim.tiny on Ubuntu [27f0d1a]
  * director: Require disk_size to be set on a disk_pool in manifest [7b85b28]
  * cpi: vsphere: Creates VM even when multi-tenant folder already exists [191c889]
  * cpi: openstack: Added openstack_region property for volumes [73af42c]

## 2719

Improvements:

  * cpi: vsphere: Remove drs rule attribute cleaner [4348d0d]
  * cpi: vsphere: Use datacenter name from config in configure_networks [f580676]

## 2717

New Features:

  * agent: Use remaining space on root disk for ephemeral storage and swap
      if OpenStack flavor does not include separate ephemeral disk [250d15a]

Improvements:

  * director: upgraded bosh components to use Ruby 2.1.2p95 [14e4702]
  * cpi: openstack: updated fog to 1.23.0 [245e086]
  * director: Set content-type while creating blobs on s3 [e69beab]
  * stemcell: openstack: Reduce OpenStack root partition to 3 GB [e9681a7]
  * stemcell: lucid: Remove lucid stemcells [2124ed4]
  * agent: Try running monit stop/unmonitor for longer period of time
      to handle 503 Service Unavailable error from monit [250d15a]

## 2710

New Features:

  * director: allow to configure compiled packages cache
      to use local blobstore [9e99ea9]

## 2707

New Features:

  * cpi: aws: allow to specify EBS volume type (supports gp2 and standard) [b79f37e]
  * cpi: pass in cloud_properties to CPI create_disk method to support
      custom disk types [675c4c0]
  * cli: show deployment changes in non-interactive mode [da70f67]
  * cli: retry director requests on OpenSSL::SSL::SSLError [3e8bee4]
  * director: control the number of PowerDNS backend db connections [c4e0b28]
  * director: Added support for disk_pools in the deployment [7499c0b]

Improvements:

  * stemcell: build: allow to set proxy username/password for downloading [4b3c6f0]
  * spec: remove ci-reporter [beb2709]

Bug Fixes:

  * agent: Make sure dav-blobstore cli performs proper
      http error checking when uploading blobs from the agent [7dc191a]

## 2693

New Features:

  * cpi: vsphere: experimental support for specifying VM anti-affinity rules
      on BOSH resource pools [76fa819]

Improvements:

  * cpi: openstack: `bosh task X --cpi` displays detailed OpenStack CPI logs [55ef66d]
  * stemcell: trusty: upgraded to `linux-image-3.13.0-34-generic` kernel [66a5e34]
  * spec: added scripts for running BOSH integration tests in Docker container [193a563]

## 2690

Bug Fixes:

  * director: fixed IP allocation when number of VMs matches number of IPs [82c1ee9]

## 2686

Bug Fixes:

  * cli: open temp file as binary to suppress LF->CRLF conversion on Windows [992c921]
  * stemcell: clean up `/etc/resolconf/resolv.conf.d` files [a3d5902]

## 2685

New Features:

  * cpi: vsphere: allow users to delete persistent disks via `bosh cck` [95cb126]
  * cli: support specifying director port 443 [98a2d5f]
  * cli: removed percent sign from non-percent load averages [17fd4e4]

Improvements:

  * director: updated controller routing to speed up responses [ccfa737]
  * agent: bumped yagnats to catch NATS subscription failures [44bc312]

## 2682

Improvements:

  * cli: update `bosh upload release X --skip-if-exists` to support uploading
      semi-semantic releases [480f5f2]
  * cli: retry downloading if SHA mismatches during release building [bbd4a13]
