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
