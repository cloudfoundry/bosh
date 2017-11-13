require_relative '../spec_helper'

describe 'orphaned disks', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  it 'should return orphan disks' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['name'] = 'first-deployment'
    manifest_hash['instance_groups'] = [Bosh::Spec::NewDeployments.simple_instance_group(persistent_disk_type: 'disk_a', instances: 1, name: 'first-instance-group')]
    cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
    disk_type = Bosh::Spec::Deployments.disk_type
    disk_type['cloud_properties'] = {'my' => 'property'}
    cloud_config['disk_types'] = [disk_type]
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    manifest_hash['name'] = 'second-deployment'
    manifest_hash['instance_groups'] = [Bosh::Spec::NewDeployments.simple_instance_group(persistent_disk_type: 'disk_a', instances: 1, name: 'second-instance-group')]
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    bosh_runner.run('delete-deployment', deployment_name: 'first-deployment')
    bosh_runner.run('delete-deployment', deployment_name: 'second-deployment')

    result = table(bosh_runner.run('disks --orphaned', json: true))
    result = scrub_random_ids(result)
    result = scrub_random_cids(result)
    result = scrub_event_time(result)

    expect(result).to contain_exactly(
      {
        'disk_cid' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'size' => '123 MiB',
        'deployment' => 'second-deployment',
        'instance' => 'second-instance-group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
        'az' => '',
        'orphaned_at' => 'xxx xxx xx xx:xx:xx UTC xxxx',
      },
      {
        'disk_cid' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
        'size' => '123 MiB',
        'deployment' => 'first-deployment',
        'instance' => 'first-instance-group/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
        'az' => '',
        'orphaned_at' => 'xxx xxx xx xx:xx:xx UTC xxxx',
      },
    )
  end

  context 'when there are no orphaned disks' do
    it 'should indicated that there are no orphaned disks' do
      result = bosh_runner.run('disks --orphaned')

      expect(result).to include '0 disks'
      expect(result).to include 'Succeeded'
    end
  end

  it 'should delete an orphaned disk' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'] = [Bosh::Spec::NewDeployments.simple_instance_group(persistent_disk_type: 'disk_a')]
    cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
    cloud_config['disk_types'] = [Bosh::Spec::Deployments.disk_type]
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
    bosh_runner.run('delete-deployment', deployment_name: 'simple')

    result = bosh_runner.run('disks --orphaned')
    orphaned_disk_cid = /([0-9a-f]{32})/.match(result)[1]

    result = bosh_runner.run("delete-disk #{orphaned_disk_cid}")
    expect(result).to include "Deleting orphaned disk #{orphaned_disk_cid}"
    expect(result).to include 'Succeeded'

    result = bosh_runner.run('disks --orphaned')
    expect(result).not_to include orphaned_disk_cid
  end

  it 'does not detach and reattach disks unnecessarily' do
    cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['persistent_disk'] = 3000
    manifest_hash['instance_groups'].first['instances'] = 1

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    first_deploy_invocations = current_sandbox.cpi.invocations

    disk_cids = director.instances.first.disk_cids

    cloud_config_hash['vm_types'].first['cloud_properties']['foo'] = 'bar'
    manifest_hash['instance_groups'].first.delete('persistent_disk')

    upload_cloud_config(cloud_config_hash: cloud_config_hash)
    deploy_simple_manifest(manifest_hash: manifest_hash)

    expect(director.instances.first.disk_cids).to eq([])

    orphaned_output = table(bosh_runner.run('disks --orphaned', json: true))
    expect(orphaned_output[0]['disk_cid']).to eq(disk_cids.first)

    cpi_invocations = current_sandbox.cpi.invocations.drop(first_deploy_invocations.size)

    # does not attach disk again, delete_vm
    expect(cpi_invocations.map(&:method_name)).to eq(['snapshot_disk', 'delete_vm', 'create_vm', 'set_vm_metadata', 'detach_disk'])
  end

  it 'should orhpan disk' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['persistent_disk'] = 3000
    manifest_hash['instance_groups'].first['instances'] = 1
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
    disk_cid = director.instances.first.disk_cids.first

    result = bosh_runner.run('disks --orphaned')
    expect(result).to include '0 disks'

    result = bosh_runner.run("orphan-disk #{disk_cid}")
    expect(result).to match /Orphan disk: [0-9a-f]{32}/
    expect(result).to include("Succeeded")
    expect(director.instances.first.disk_cids).to eq([])

    orphaned_output = table(bosh_runner.run('disks --orphaned', json: true))
    expect(orphaned_output[0]['disk_cid']).to eq(disk_cid)

    #no disk to orphan
    result = bosh_runner.run("orphan-disk #{disk_cid}")

    expect(result).to match /Orphan disk: [0-9a-f]{32}/
    expect(result).to match /Disk [0-9a-f]{32} does not exist. Orphaning is skipped/
    expect(result).to include("Succeeded")
  end
end
