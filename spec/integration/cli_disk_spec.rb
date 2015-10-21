require 'spec_helper'

describe 'cli: disks', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  it 'should return orphan disks' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['name'] = 'first-deployment'
    manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(persistent_disk_pool: 'disk_a', instances: 1, name: 'first-job')]
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    disk_pool = Bosh::Spec::Deployments.disk_pool
    disk_pool['cloud_properties'] = {'my' => 'property'}
    cloud_config['disk_pools'] = [disk_pool]
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    manifest_hash['name'] = 'second-deployment'
    manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(persistent_disk_pool: 'disk_a', instances: 1, name: 'second-job')]
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    bosh_runner.run('delete deployment first-deployment')
    bosh_runner.run('delete deployment second-deployment')

    result = bosh_runner.run('disks --orphaned')
    result = scrub_random_ids(result)
    result = scrub_random_cids(result)
    result = scrub_time(result)

    expect(result).to include(<<DISKS)
+----------------------------------+------------+-------------------+-------------------------------------------------+-----+---------------------------+
| Disk CID                         | Size (MiB) | Deployment Name   | Instance Name                                   | AZ  | Orphaned At               |
+----------------------------------+------------+-------------------+-------------------------------------------------+-----+---------------------------+
| xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx | 123        | second-deployment | second-job/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | n/a | 0000-00-00 00:00:00 -0000 |
| xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx | 123        | first-deployment  | first-job/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  | n/a | 0000-00-00 00:00:00 -0000 |
+----------------------------------+------------+-------------------+-------------------------------------------------+-----+---------------------------+
DISKS
  end

  context 'when there are no orphaned disks' do
    it 'should err with no orphaned disks' do
      target_and_login
      result = bosh_runner.run('disks --orphaned')

      expect(result).to include 'No orphaned disks'
    end
  end

  it 'should delete an orphaned disk' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(persistent_disk_pool: 'disk_a')]
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config['disk_pools'] = [Bosh::Spec::Deployments.disk_pool]
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
    bosh_runner.run('delete deployment simple')

    result = bosh_runner.run('disks --orphaned')
    orphaned_disk_cid = /([0-9a-f]{32})/.match(result)[1]

    result = bosh_runner.run("delete disk #{orphaned_disk_cid}")
    expect(result).to include "Deleted orphaned disk #{orphaned_disk_cid}"

    result = bosh_runner.run('disks --orphaned')
    expect(result).not_to include orphaned_disk_cid
  end
end
