require 'spec_helper'

describe 'vm state', type: :integration do
  with_reset_sandbox_before_each

  describe 'detached' do
    it 'removes vm but keeps its disk' do
      deploy_from_scratch

      vms = director.vms
      vm_with_index_0 = vms.find{ |vm| vm.index == '0'}
      disks_before_detaching = current_sandbox.cpi.disk_cids

      expect(bosh_runner.run('stop foobar 0 --hard')).to match %r{foobar/0 detached}
      expect(current_sandbox.cpi.disk_cids).to eq(disks_before_detaching)

      expect(director.vms.map(&:instance_uuid)).to eq(vms.map(&:instance_uuid) - [vm_with_index_0.instance_uuid])

      bosh_runner.run('start foobar 0')

      expect(director.vms.map(&:instance_uuid)).to eq(vms.map(&:instance_uuid))
      expect(current_sandbox.cpi.disk_cids).to eq(disks_before_detaching)
    end

    it 'keeps IP reservation' do
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_from_scratch(manifest_hash: manifest_hash)
      deployed_vms = director.vms
      expect(deployed_vms.size).to eq(1)
      expect(deployed_vms.first.ips).to eq('192.168.1.2')

      expect(bosh_runner.run('stop foobar 0 --hard')).to match %r{foobar/0 detached}
      expect(director.vms.size).to eq(0)

      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 2)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      deployed_vms = director.vms
      expect(deployed_vms.size).to eq(1)
      expect(deployed_vms.first.ips).to eq('192.168.1.3')

      bosh_runner.run('start foobar 0')
      deployed_vms = director.vms
      expect(deployed_vms.size).to eq(2)
      expect(deployed_vms.map(&:ips)).to match_array(['192.168.1.2', '192.168.1.3'])
    end

    it 'releases previously reserved IP when state changed with new static IP' do
      first_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_from_scratch(manifest_hash: first_manifest_hash)
      expect(director.vms('simple').map(&:ips)).to eq(['192.168.1.2'])

      expect(bosh_runner.run('stop foobar 0 --hard')).to match %r{foobar/0 detached}
      expect(director.vms('simple').size).to eq(0)

      first_manifest_hash['jobs'].first['networks'].first['static_ips'] = ['192.168.1.10']
      deploy_simple_manifest(manifest_hash: first_manifest_hash)

      second_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(
        name: 'second',
        instances: 1,
        template: 'foobar_without_packages'
      )
      # this deploy takes the newly freed IP
      deploy_simple_manifest(manifest_hash: second_manifest_hash)
      expect(director.vms('second').map(&:ips)).to eq(['192.168.1.2'])

      set_deployment(manifest_hash: first_manifest_hash)
      bosh_runner.run('start foobar 0 --force')
      vms = director.vms('simple')
      expect(vms.size).to eq(1)
      expect(vms.map(&:ips)).to eq(['192.168.1.10'])
    end
  end

  context 'instances have gaps in indexes' do
    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
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
      simple_manifest = Bosh::Spec::Deployments.simple_manifest
      simple_manifest['jobs'].first['instances'] = 3
      simple_manifest['jobs'].first['networks'].first['static_ips'] = ['192.168.1.51', '192.168.2.51', '192.168.2.52']

      simple_manifest['jobs'].first['azs'] = ['my-az', 'my-az2']
      deploy_from_scratch(manifest_hash: simple_manifest, cloud_config_hash: cloud_config_hash)

      simple_manifest['jobs'].first['instances'] = 2
      simple_manifest['jobs'].first['networks'].first['static_ips'] = ['192.168.2.51', '192.168.2.52']
      simple_manifest['jobs'].first['azs'] = ['my-az2']
      deploy_simple_manifest(manifest_hash: simple_manifest)

      vms = director.vms
      prev_foobar_1_vm = director.find_vm(vms, 'foobar', '1')
      prev_foobar_2_vm = director.find_vm(vms, 'foobar', '2')

      bosh_runner.run('recreate foobar 1')
      vms = director.vms
      new_foobar_1_vm = director.find_vm(vms, 'foobar', '1')
      new_foobar_2_vm = director.find_vm(vms, 'foobar', '2')
      expect(prev_foobar_1_vm.cid).to_not eq(new_foobar_1_vm.cid)
      expect(prev_foobar_2_vm.cid).to eq(new_foobar_2_vm.cid)
      prev_foobar_1_vm, prev_foobar_2_vm = new_foobar_1_vm, new_foobar_2_vm

      bosh_runner.run('recreate foobar 2')
      vms = director.vms
      new_foobar_1_vm = director.find_vm(vms, 'foobar', '1')
      new_foobar_2_vm = director.find_vm(vms, 'foobar', '2')
      expect(prev_foobar_1_vm.cid).to eq(new_foobar_1_vm.cid)
      expect(prev_foobar_2_vm.cid).to_not eq(new_foobar_2_vm.cid)

      bosh_runner.run('stop foobar 1')
      vms = director.vms
      new_foobar_1_vm = director.find_vm(vms, 'foobar', '1')
      new_foobar_2_vm = director.find_vm(vms, 'foobar', '2')
      expect(new_foobar_1_vm.last_known_state).to eq('stopped')
      expect(new_foobar_2_vm.last_known_state).to eq('running')

      bosh_runner.run('start foobar 1')
      vms = director.vms
      new_foobar_1_vm = director.find_vm(vms, 'foobar', '1')
      new_foobar_2_vm = director.find_vm(vms, 'foobar', '2')
      expect(new_foobar_1_vm.last_known_state).to eq('running')
      expect(new_foobar_2_vm.last_known_state).to eq('running')

      bosh_runner.run('stop foobar 2')
      vms = director.vms
      new_foobar_1_vm = director.find_vm(vms, 'foobar', '1')
      new_foobar_2_vm = director.find_vm(vms, 'foobar', '2')
      expect(new_foobar_1_vm.last_known_state).to eq('running')
      expect(new_foobar_2_vm.last_known_state).to eq('stopped')

      bosh_runner.run('start foobar 2')
      vms = director.vms
      new_foobar_1_vm = director.find_vm(vms, 'foobar', '1')
      new_foobar_2_vm = director.find_vm(vms, 'foobar', '2')
      expect(new_foobar_1_vm.last_known_state).to eq('running')
      expect(new_foobar_2_vm.last_known_state).to eq('running')

      bosh_runner.run('restart foobar 1')
      event_log = bosh_runner.run('task last --event --raw')
      expect(event_log).to match(/foobar\/1 \(.*\)/)
      expect(event_log).to_not match(/foobar\/2 \(.*\)/)

      bosh_runner.run('restart foobar 2')
      event_log = bosh_runner.run('task last --event --raw')
      expect(event_log).to_not match(/foobar\/1 \(.*\)/)
      expect(event_log).to match(/foobar\/2 \(.*\)/)
    end
  end

  describe 'recreate' do
    it 'does not update deployment on recreate' do
      deploy_from_scratch

      bosh_runner.run('recreate foobar 1')

      deploy_simple_manifest

      event_log = bosh_runner.run('task last --event --raw')
      expect(event_log).to_not match(/Updating job/)
    end
  end

  it 'changes a single job instance state when referenced by id' do
    deploy_from_scratch
    expect(director.vms.map(&:last_known_state).uniq).to match_array(['running'])
    bosh_runner.run('stop')
    expect(director.vms.map(&:last_known_state).uniq).to match_array(['stopped'])

    test_vm = director.vms[1]
    instance_id = test_vm.instance_uuid
    expect(bosh_runner.run("start foobar #{instance_id}")).to match %r{foobar/#{instance_id} started}

    vms = director.vms
    test_vm = director.find_vm(vms, 'foobar', instance_id)
    expect(test_vm.last_known_state).to eq('running')
    other_vms = vms.select { |vm| vm.instance_uuid != instance_id }
    expect(other_vms.map(&:last_known_state).uniq).to eq(['stopped'])

    expect(bosh_runner.run("stop foobar #{instance_id}")).to match %r{foobar/#{instance_id} stopped}
    expect(director.vm('foobar', instance_id).last_known_state).to eq('stopped')

    expect(bosh_runner.run("recreate foobar #{instance_id}")).to match %r{foobar/#{instance_id} recreated}
    vms = director.vms
    recreated_vm = director.find_vm(vms, 'foobar', instance_id)
    expect(recreated_vm.cid).to_not eq(test_vm.cid)
    new_other_vms = vms.select { |vm| vm.instance_uuid != instance_id }
    expect(new_other_vms.map(&:cid)).to match_array(other_vms.map(&:cid))

    expect(bosh_runner.run("restart foobar #{instance_id}")).to match %r{foobar/#{instance_id} restarted}
  end
end
