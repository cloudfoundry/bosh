require 'spec_helper'

describe 'cli: disks', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  it 'should return orphan disks' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(persistent_disk_pool: 'disk_a')]
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config['disk_pools'] = [Bosh::Spec::Deployments.disk_pool]
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
    bosh_runner.run('delete deployment simple')

    result = bosh_runner.run('disks --orphaned')
    result = scrub_random_ids(result)
    result = scrub_random_cids(result)
    result = scrub_time(result)

    expect(result).to include(<<DISKS)
+----------------------------------+-----------------+---------------------------------------------+-----------+-------------------+------------------+---------------------------+
| Disk CID                         | Deployment Name | Instance Name                               | Disk Size | Availability Zone | Cloud Properties | Orphaned At               |
+----------------------------------+-----------------+---------------------------------------------+-----------+-------------------+------------------+---------------------------+
| xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx | simple          | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 123       | n/a               | n/a              | 0000-00-00 00:00:00 -0000 |
| xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx | simple          | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 123       | n/a               | n/a              | 0000-00-00 00:00:00 -0000 |
| xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx | simple          | foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 123       | n/a               | n/a              | 0000-00-00 00:00:00 -0000 |
+----------------------------------+-----------------+---------------------------------------------+-----------+-------------------+------------------+---------------------------+
DISKS
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
    expect(result).to include "Deleted orphan disk #{orphaned_disk_cid}"

    result = bosh_runner.run('disks --orphaned')
    expect(result).not_to include orphaned_disk_cid
  end
end
