require 'spec_helper'

describe 'vm state', type: :integration do
  with_reset_sandbox_before_each

  describe 'detached' do
    it 'removes vm but keeps its disk' do
      deploy_from_scratch

      vms = director.vms
      vm_with_index_0 = vms.find{ |vm| vm.index == '0'}
      disks_before_detaching = current_sandbox.cpi.disk_cids

      expect(bosh_runner.run('stop foobar 0 --hard')).to match %r{foobar/0 has been detached}
      expect(current_sandbox.cpi.disk_cids).to eq(disks_before_detaching)

      expect(director.vms.map(&:instance_id)).to eq(vms.map(&:instance_id) - [vm_with_index_0.instance_id])

      bosh_runner.run('start foobar 0')

      expect(director.vms.map(&:instance_id)).to eq(vms.map(&:instance_id))
      expect(current_sandbox.cpi.disk_cids).to eq(disks_before_detaching)
    end

    it 'keeps IP reservation' do
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_from_scratch(manifest_hash: manifest_hash)
      deployed_vms = director.vms
      expect(deployed_vms.size).to eq(1)
      expect(deployed_vms.first.ips).to eq('192.168.1.2')

      expect(bosh_runner.run('stop foobar 0 --hard')).to match %r{foobar/0 has been detached}
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

      expect(bosh_runner.run('stop foobar 0 --hard')).to match %r{foobar/0 has been detached}
      expect(director.vms('simple').size).to eq(0)

      first_manifest_hash['jobs'].first['networks'].first['static_ips'] = ['192.168.1.10']
      set_deployment(manifest_hash: first_manifest_hash)

      # this stop should do nothing, but right now bosh does a full deploy,
      # which changes the instance IP
      expect(bosh_runner.run('stop foobar 0 --hard --force')).to match %r{foobar/0 has been detached}
      expect(director.vms('simple').size).to eq(0)

      second_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(
        name: 'second',
        instances: 1,
        template: 'foobar_without_packages'
      )
      # this deploy takes the newly freed IP
      deploy_simple_manifest(manifest_hash: second_manifest_hash)
      expect(director.vms('second').map(&:ips)).to eq(['192.168.1.2'])

      set_deployment(manifest_hash: first_manifest_hash)
      bosh_runner.run('start foobar 0')
      expect(director.vms('simple').map(&:ips)).to eq(['192.168.1.10'])
    end
  end
end
