## 2941

New Features:

  * cpi: aws: Light stemcells can be booted in all regions [8d21386]

Improvements:

  * stemcell: Bump OS images [5b7e612]
        - reduce daily and weekly cron load
        - randomize cron start times to reduce congestion
        - remove unnecessary packages to make OS image smaller
  * director: Made gateway a mandatory param for manual network subnets [1145448]

## 2922

New Features:

  * cli: Ignore non-existent deployment in `delete deployment` cmd
        to make CLI automation easier [dd6801e]
  * cli: Add cloud config into to 'bosh deployments' output
        to know if deployment is using latest cloud config [bcf1d4d]

Improvements:

  * stemcell: ubuntu: Do not configure eth0 since the Agent
        should configure networking during its start up [e481b4a]
  * director: Flush DNS cache after modifying DNS records [2137b55]
  * stemcell: Change rake tasks to start producting CentOS 7 stemcells [e5bceba]
  * agent: Bump agent [752ff10]
        - set permissions on config files
        - more changes to network bootstrapping

## 2915

New Features:

  * cli: Allow passing --all flag to `bosh cleanup`
          to delete all unused releases and stemcells [2bc5e62]
  * cli: Modified cck --auto so that it recreated VMs
          if they are missing [05ee580]

Improvements:

  * cpi: aws: Retry attaching disk for upto 10 mins if disk is in
          VolumeInUse state, since sometimes AWS is slow
          to propagate disk's true state. [f654c5f]
  * cli: Permit creation of dev release with version [5d433d6]
  * director: Bump nokogiri to 1.6.6, vcloud to 0.7.3 [39c6cdf]
  * stemcell: Ensure stemcell stages run as UID 1000
          (vcap's UID on stemcells) so that vcap owned files
          are still owned by vcap when stemcell boots up [56dd84c]
  * stemcell: Add hmac-sha1 back as an allowed sshd MAC.
          Needed by golang and java ssh libraries. [a99c833]
  * stemcell: Add syslog user to vcap group so rsyslog
          can write to /var/vcap/sys/log/ [b4fea21]
  * cpi: openstack: Stop artificially limiting volume sizes to 1TiB [9bda2ae]
  * agent: Bump agent to pull-in set of changes to networking [c4f211a]

## 2905

Improvements:

  * stemcell: rhel: Introduced 'rhel' OS type, supporting only version 7 [5491fec]
  * stemcell: rhel: Unsubscribe system from RHN once OS image has been built [259e787]
  * cpi: vsphere: Log and print more info when we can't find a datastore for a disk [b5488e1]

## 2902

New Features:

  * cli: Introduce UAA authentication

Improvements:

  * stemcell: Do not verify exact kernel version to ease development workflow [b1f7afc]

Bug Fixes:

  * cpi: vsphere: Don't raise an exception when finding a disk
          if the folder doesn't exist since cpi can be configured
          with multiple folders [f7c46db]
  * cli: Compiling a release now places LICENSE/NOTICE at the root [9bbb51d]

## 2891

Improvements:

  * stemcell: ubuntu: Bump libssl [f690d2e]
  * stemcell: ubuntu: Bump libgnutls26 [622ffe8]

Bug Fixes:

  * cli: Compiling a release places LICENSE/NOTICE at the root [58f9848]

## 2881

Improvements:

  * cpi: vsphere: Removed CPI specific database to allow greater
          mobility of persistent disks (e.g. moved to a different datastore)
          and to prepare for externalizing vSphere CPI

## 2859

Improvements:

  * stemcell: ubuntu: Bump to get 3.16 kernel
        and get libc6 from 2.19-0ubuntu6.6 [5154430]
        [story](https://www.pivotaltracker.com/story/show/89216658)
  * director: Provide better Director job configuration f
        or external CPIs [3634979]

## 2858

Bug Fixes:

  * director: Correctly save long manifests with MySQL DB [a091114]

## 2855

New Features:

  * stemcell: ubuntu: Updated Ubuntu Trusty to 14.04.2 [7108831]
  * director: Allow UAA as use management provider configuration [8ac86a2]

Improvements:

  * cpi: openstack: Write the networks configuration to the config drive
        in preparation for allowing to use non-dhcp OpenStack networking [298fe2f]
  * stemcell: ubuntu: Bump to 14.04.2 [7108831]
  * cli: Add warning when loading cli takes longer than 5 secs [8aca1d8]

## 2852

Improvements:

  * stemcell: ubuntu: Bump unzip to 6.0-9ubuntu1.3 [bd3182a]

## 2849

New Features:

  * cli: Include license in release [c63287a]

## 2847

Improvements:

  * stemcell: harden sshd config, and remove postfix and tripwire [1f4dd4a]
  * stemcell: remove all traces of lucid stemcell [4559a69]
  * agent: Bump agent to clean after compiling bits [cd3fcb9]
  * cli: Store release jobs/packages tarballs in ~/.bosh/cache [c2f7ac1]

## 2839

Improvements:

  * stemcell: Enable console output for openstack in kernel [f4f1cdd/c89b61e]
  * stemcell: ubuntu: Upgrade ubuntu unzip version [9481cd4]

## 2831

Improvements:

  * agent: Bump agent so that it waits for monit
        to start up during bootstrapping [4cf37f4]

## 2830

Bug Fixes:

  * stemcell: Stemcell names include bosh prefix once again [fbb2016]

## 2829

Improvements:

  * director: Update fog to 1.27 [08e9edc]
  * stemcell: centos: Bump CentOS to resolve CVE-2015-0235 (ghost) [b7ebec5]

## 2827

New Features:

  * stemcell: openstack: Publish raw stemcells in addition to qcow2 [382e448]

Improvements:

  * director: Follow redirects when downloading remote stemcells/releases [5d2bb05]
  * stemcell: Agent is responsible for creating /var/vcap/sys symlink [7563294]

## 2824

New Features:

  * cpi: openstack: Permit volumes to default to the default availability zone,
        ignoring the AZ of the server. This allows multiple compute AZs with a
        single storage AZ configuration backed by Ceph to operate [e1b6e14]
  * stemcell: upgrade libssl to 1.0.1f-1ubuntu2.8 for USN-2459-1 [35799c7]
        [story](https://www.pivotaltracker.com/story/show/86540636)

Improvements:

  * cli: Don't confirm release upload [c1e4886]

## 2820

Improvements:

  * cpi: vsphere: Automatically create VMs/Templates folders
        _of any depth_ if they are not found when VMs are created [c752e39]

## 2818

New Features:

  * cpi: aws: Support encryption of persistent disks that are EBS volumes [1f8b6fc]

Improvements:

  * agent: Bump agent so that it fails if it cannot find ephemeral disk or cannot
        paritition root disk to add ephemeral data partition [f3e86a8]

## 2811

Bug Fixes:

  * stemcell: aws: Define block device mapping on aws stemcells
        so that older versions of the Director can still deploy them [a3d0ca1]

## 2810

New Features:

  * cpi: aws: allow to request EBS backed ephemeral disk for any instance type
        by specifying `ephemeral_disk` on the resource_pool's cloud_properties. [e7ae973]

Improvements:

  * stemcell: Run logrotate hourly instead of daily [5e841be]
  * stemcell: Rotate /var/log files based on size [5e841be]

Bug Fixes:

  * cpi: openstack: Use volume attachment id instead of just volume id
        when detaching volumes [41e69dc]

## 2809

Bug Fixes:

  * director: Denormalize Task => User association so Tasks have username
        so that operator can delete Director users even if there are tasks
        associated with that user [11a8c7a]

## 2807

New Features:

  * cpi: vsphere: Automatically create Datastore folders
        if they are not found when persistent disks are created [c2b5a51]

Improvements:

  * cpi: aws: Explicitly request ephemeral disk for m3 instances on AWS
        because sometimes AWS fails to honor the AMI's block_device_mappings [83c6aef]

## 2798

Improvements:

  * agent: Bump bosh-agent so that it can look up persistent disks
        by their OpenStack UUID instead of a device path [7d6c56c]

## 2797

New Features:

  * cpi: openstack: Add support for OpenStack Nova scheduler hints.
        scheduler_hints can be now specified on the resource_pool's
        cloud_properties. [a32e62e]
  * cpi: vsphere: Automatically create VMs/Templates folders
        if they are not found when VMs are created [9221ece]
  * cli: added `--parallel X` option so that `bosh sync blobs`
        can download blobs in parallel [458180b]

Improvements:

  * cli: fix issue with having empty release_versions array in release parameters
        so that `bosh releases` command still shows other uploaded releases [f3c9662]
  * stemcell: monit should be started by the agent to make sure agent
        has time to mount `/var/vcap/sys/run` on tmpfs [ed7b8e1]

## 2792

New Features:

  * monitor: adding graphite plugin to bosh-monitor [91c1836]

Improvements:

  * cli: Blobstore config is no longer required to create a dev release [d0aa917]

## 2789

New Features:

  * cli: add `--redact-diff` option to `bosh deploy` cli command [3b22d7a]

## 2788

Improvements:

  * cpi: vsphere: Check for attached disk by disk_cid instead of full path
        because vCenter sometimes returns internal vSAN path
        instead of pretty UI path [ff3cedf]
  * monitor: Log when health monitor is returning 500 from /healthz [bcc9dec]

## 2786

New Features:

  * director: Add `--keep-alive` flag for `bosh run errand` command.
        With this flag errand VM is not deleted after errand completes.
        Could be used for debugging or to avoid spinning up and
        spinning down errand VM periodically. [59be4fe]

## 2785

Improvements:

  * monitor: Change /healthz to return 500 if worker pool
        has been have been occupied for 3 minutes so that health monitor
        is restarted when it cannot process any more events [03e116e]
  * director: Merge #698 Use ec2_endpoint from krumts [a4547a5]
  * director: Default NTP servers to pool.ntp.org [2c7888e]

## 2781

Improvements:

  * stemcell: Disable reverse DNS resolution for sshd to speed up ssh access [f4f5319]
  * stemcell: vcloud: Start producing vcloud stemcells on regular schedule

Bug Fixes:

  * director: Remember persistent disk cloud properties
        to avoid unnecessarily migrating data persistent disk [ccb2ca5]
  * director: Fix leaking debug logs fds [e000906]
  * director: Use gc_thresh1 set in stemcell in nats job
        to fix interemittent connectivity issues [be690e4]
  * director: Bump bosh_vcloud_cpi gem to 0.7.2
        to support persistent disk pools [9a73928]

## 2780

Improvements:

  * agent: Bump bosh-agent to include root device partition fixes such that
        partitioning of root disk works on more configurations  [436154f]

## 2778

New Features:

  * cpi: openstack: Support specifying volume type for persistent disks [43aba09]
  * cpi: openstack: Support specifying AZ and volume type for boot volume [43aba09]

## 2776

Improvements:

  * stemcell: centos: Bump CentOS to 6.6 [e9d8776]
  * stemcell: ubuntu: Turn on rsyslog.d kernel logging for trusty [7060389]

## 2765

Improvements:

  * stemcell: ubuntu: Updated Ubuntu Trusty kernel to 3.13.0-39-generic [3cce75e]
  * director: Honor --skip-if-exists when uploading remote releases [822f67e]
  * cpi: aws: Support for additional AWS configuration properties [64b1d22]
  * cpi: openstack: Add support for additional glance properties to the stemcell
       that can be set when using VMware hypervisor with OpenStack [d32d847]
  * agent: Bump bosh-agent [9ec67d5]
       - uploading of compiled package blob is retried
       - correct capture swap disk sizes returned from gosigar

Bug Fixes:

  * director: Switched bosh-registry to use bundler to install DB gems
       which should bring back faster compilation times for bosh-registry [34b36a3]

## 2754 (stemcells & release yanked)

Improvements:

  * cli: Adding persistent disk type configuration for Micro BOSH
       via `persistent_disk_cloud_properties` [828df74]

## 2751

Improvements:

  * director: Re-add director deployment events for operator
       to be notified about deloyment start/finish/failure [b63c8f7]
  * agent: Bump bosh-agent [d5218ef]
       - Add FileRegistry for warden inf. for e2e testing of new bosh-micro-cli

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
