require_relative '../spec_helper'

describe 'vm state', type: :integration do
  let(:deployment_name) { 'simple' }

  with_reset_sandbox_before_each

  describe 'detached' do
    it 'removes vm but keeps its disk' do
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      manifest_hash['instance_groups'].first['persistent_disk'] = 3000
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      instances = director.instances.select { |instance|
        !instance.vm_cid.empty?
      }
      instance_with_index_0 = instances.find{ |instance| instance.index == '0'}
      disks_before_detaching = current_sandbox.cpi.disk_cids

      expect(bosh_runner.run('stop foobar/0 --hard', deployment_name: deployment_name)).to match %r{Updating instance foobar}
      expect(current_sandbox.cpi.disk_cids).to eq(disks_before_detaching)

      expect(director.instances.select { |instance|
        !instance.vm_cid.empty?
      }.map(&:id)).to eq(instances.map(&:id) - [instance_with_index_0.id])

      bosh_runner.run('start foobar/0', deployment_name: deployment_name)

      expect(director.instances.select { |instance|
        !instance.vm_cid.empty?
      }.map(&:id)).to eq(instances.map(&:id))
      expect(current_sandbox.cpi.disk_cids).to eq(disks_before_detaching)
    end

    it 'keeps IP reservation' do
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      deployed_vms = director.vms
      expect(deployed_vms.size).to eq(1)
      expect(deployed_vms.first.ips).to eq(['192.168.1.2'])

      expect(bosh_runner.run('stop foobar/0 --hard', deployment_name: deployment_name)).to match %r{Updating instance foobar}
      expect(director.vms.size).to eq(0)

      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 2)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      deployed_vms = director.vms
      expect(deployed_vms.size).to eq(1)
      expect(deployed_vms.first.ips).to eq(['192.168.1.3'])

      bosh_runner.run('start foobar/0', deployment_name: deployment_name)
      deployed_vms = director.vms
      expect(deployed_vms.size).to eq(2)
      expect(deployed_vms.map(&:ips)).to match_array([['192.168.1.2'], ['192.168.1.3']])
    end

    it 'releases previously reserved IP when state changed with new static IP' do
      first_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_from_scratch(manifest_hash: first_manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      expect(director.vms.map(&:ips)).to eq([['192.168.1.2']])

      expect(bosh_runner.run('stop foobar/0 --hard', deployment_name: deployment_name)).to match %r{Updating instance foobar}
      expect(director.vms.size).to eq(0)

      first_manifest_hash['instance_groups'].first['networks'].first['static_ips'] = ['192.168.1.10']
      deploy_simple_manifest(manifest_hash: first_manifest_hash)
      expect(director.vms.map(&:ips)).to eq([])

      second_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(
        name: 'second',
        instances: 1,
        job: 'foobar_without_packages'
      )
      # this deploy takes the newly freed IP
      deploy_simple_manifest(manifest_hash: second_manifest_hash)
      expect(director.vms.map(&:ips)).to eq([['192.168.1.2']])

      bosh_runner.run('start foobar/0 --force', deployment_name: deployment_name)
      vms = director.vms
      expect(vms.size).to eq(2)
      expect(vms.map(&:ips)).to match_array([['192.168.1.10'], ['192.168.1.2']])
    end
  end

  context 'instances have gaps in indexes' do
    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['azs'] = [{'name' => 'my-az'}, {'name' => 'my-az2'}]
      cloud_config_hash['networks'].first['subnets'] = [
        {
          'range' => '192.168.1.0/24',
          'gateway' => '192.168.1.1',
          'dns' => ['8.8.8.8'],
          'static' => ['192.168.1.51', '192.168.1.52'],
          'az' => 'my-az'
        },
        {
          'range' => '192.168.2.0/24',
          'gateway' => '192.168.2.1',
          'dns' => ['8.8.8.8'],
          'static' => ['192.168.2.51', '192.168.2.52'],
          'az' => 'my-az2'
        }
      ]
      cloud_config_hash['compilation']['az'] = 'my-az'
      cloud_config_hash
    end

    it 'it keeps instances with left static IP and deletes instances with removed IPs' do
      simple_manifest = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      simple_manifest['instance_groups'].first['instances'] = 3
      simple_manifest['instance_groups'].first['networks'].first['static_ips'] = ['192.168.1.51', '192.168.2.51', '192.168.2.52']

      simple_manifest['instance_groups'].first['azs'] = ['my-az', 'my-az2']
      deploy_from_scratch(manifest_hash: simple_manifest, cloud_config_hash: cloud_config_hash)

      simple_manifest['instance_groups'].first['instances'] = 2
      simple_manifest['instance_groups'].first['networks'].first['static_ips'] = ['192.168.2.51', '192.168.2.52']
      simple_manifest['instance_groups'].first['azs'] = ['my-az2']
      deploy_simple_manifest(manifest_hash: simple_manifest)

      instances = director.instances
      prev_foobar_1_instance = director.find_instance(instances, 'foobar', '1')
      prev_foobar_2_instance = director.find_instance(instances, 'foobar', '2')

      bosh_runner.run('recreate foobar/1', deployment_name: deployment_name)
      instances = director.instances
      new_foobar_1_instance = director.find_instance(instances, 'foobar', '1')
      new_foobar_2_instance = director.find_instance(instances, 'foobar', '2')
      expect(prev_foobar_1_instance.vm_cid).to_not eq(new_foobar_1_instance.vm_cid)
      expect(prev_foobar_2_instance.vm_cid).to eq(new_foobar_2_instance.vm_cid)
      prev_foobar_1_instance, prev_foobar_2_instance = new_foobar_1_instance, new_foobar_2_instance

      bosh_runner.run('recreate foobar/2', deployment_name: deployment_name)
      instances = director.instances
      new_foobar_1_instance = director.find_instance(instances, 'foobar', '1')
      new_foobar_2_instance = director.find_instance(instances, 'foobar', '2')
      expect(prev_foobar_1_instance.vm_cid).to eq(new_foobar_1_instance.vm_cid)
      expect(prev_foobar_2_instance.vm_cid).to_not eq(new_foobar_2_instance.vm_cid)

      bosh_runner.run('stop foobar/1', deployment_name: deployment_name)
      instances = director.instances
      new_foobar_1_instance = director.find_instance(instances, 'foobar', '1')
      new_foobar_2_instance = director.find_instance(instances, 'foobar', '2')
      expect(new_foobar_1_instance.last_known_state).to eq('stopped')
      expect(new_foobar_2_instance.last_known_state).to eq('running')

      bosh_runner.run('start foobar/1', deployment_name: deployment_name)
      instances = director.instances
      new_foobar_1_instance = director.find_instance(instances, 'foobar', '1')
      new_foobar_2_instance = director.find_instance(instances, 'foobar', '2')
      expect(new_foobar_1_instance.last_known_state).to eq('running')
      expect(new_foobar_2_instance.last_known_state).to eq('running')

      bosh_runner.run('stop foobar/2', deployment_name: deployment_name)
      instances = director.instances
      new_foobar_1_instance = director.find_instance(instances, 'foobar', '1')
      new_foobar_2_instance = director.find_instance(instances, 'foobar', '2')
      expect(new_foobar_1_instance.last_known_state).to eq('running')
      expect(new_foobar_2_instance.last_known_state).to eq('stopped')

      bosh_runner.run('start foobar/2', deployment_name: deployment_name)
      instances = director.instances
      new_foobar_1_instance = director.find_instance(instances, 'foobar', '1')
      new_foobar_2_instance = director.find_instance(instances, 'foobar', '2')
      expect(new_foobar_1_instance.last_known_state).to eq('running')
      expect(new_foobar_2_instance.last_known_state).to eq('running')

      bosh_runner.run('restart foobar/1', deployment_name: deployment_name)
      task_id = bosh_runner.get_most_recent_task_id
      event_log = bosh_runner.run("task #{task_id} --event")
      expect(event_log).to match(/foobar\/[a-z0-9\-]+ \(1\)/)
      expect(event_log).to_not match(/foobar\/[a-z0-9\-]+ \(2\)/)

      bosh_runner.run('restart foobar/2', deployment_name: deployment_name)
      task_id = bosh_runner.get_most_recent_task_id
      event_log = bosh_runner.run("task #{task_id} --event")
      expect(event_log).to_not match(/foobar\/[a-z0-9\-]+ \(1\)/)
      expect(event_log).to match(/foobar\/[a-z0-9\-]+ \(2\)/)
    end
  end

  describe 'recreate' do
    it 'does not update deployment on recreate' do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      bosh_runner.run('recreate foobar/1', deployment_name: deployment_name)

      deploy_simple_manifest(manifest_hash: manifest_hash)

      task_id = bosh_runner.get_most_recent_task_id
      event_log = bosh_runner.run("task #{task_id} --event")
      expect(event_log).to_not match(/Updating job/)
    end
  end

  it 'changes a single instance group instance state when referenced by id' do
    deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
    expect(director.instances.map(&:last_known_state).uniq).to match_array(['running'])
    bosh_runner.run('stop', deployment_name: deployment_name)
    expect(director.instances.map(&:last_known_state).uniq).to match_array(['stopped'])

    test_instance = director.instances[1]
    instance_id = test_instance.id
     expect(bosh_runner.run("start foobar/#{instance_id}", deployment_name: deployment_name)).to match %r{Updating instance foobar: foobar/#{instance_id}}

    instances = director.instances
    test_instance = director.find_instance(instances, 'foobar', instance_id)
    expect(test_instance.last_known_state).to eq('running')
    other_instances = instances.select { |instance| instance.id != instance_id }
    expect(other_instances.map(&:last_known_state).uniq).to eq(['stopped'])

    expect(bosh_runner.run("stop foobar/#{instance_id}", deployment_name: deployment_name)).to match %r{Updating instance foobar: foobar/#{instance_id}}
    expect(director.instance('foobar', instance_id).last_known_state).to eq('stopped')

    expect(bosh_runner.run("recreate foobar/#{instance_id}", deployment_name: deployment_name)).to match %r{Updating instance foobar: foobar/#{instance_id}}
    instances = director.instances
    recreated_instance = director.find_instance(instances, 'foobar', instance_id)
    expect(recreated_instance.vm_cid).to_not eq(test_instance.vm_cid)
    new_other_instances = instances.select { |instance| instance.id != instance_id }
    expect(new_other_instances.map(&:vm_cid)).to match_array(other_instances.map(&:vm_cid))

    expect(bosh_runner.run("restart foobar/#{instance_id}", deployment_name: deployment_name)).to match %r{Updating instance foobar: foobar/#{instance_id}}
  end
end
