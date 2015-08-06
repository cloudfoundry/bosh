require 'spec_helper'

describe 'vm state', type: :integration do
  with_reset_sandbox_before_each

  describe 'detached' do
    it 'removes vm but keeps its disk' do
      deploy_from_scratch

      expect(director.vms.map(&:job_name_index)).to contain_exactly('foobar/0', 'foobar/1', 'foobar/2')

      disks_before_detaching = current_sandbox.cpi.disk_cids

      expect(bosh_runner.run('stop foobar 0 --hard')).to match %r{foobar/0 has been detached}
      expect(current_sandbox.cpi.disk_cids).to eq(disks_before_detaching)

      expect(director.vms.map(&:job_name_index)).to contain_exactly('foobar/1', 'foobar/2')

      bosh_runner.run('start foobar 0')

      expect(director.vms.map(&:job_name_index)).to contain_exactly('foobar/0', 'foobar/1', 'foobar/2')
      expect(current_sandbox.cpi.disk_cids).to eq(disks_before_detaching)
    end

    it 'keeps IP reservation' do
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_from_scratch(manifest_hash: manifest_hash)
      deployed_vms = director.vms
      expect(deployed_vms.size).to eq(1)
      expect(deployed_vms.first.ips).to eq('192.168.1.2')

      expect(bosh_runner.run('stop foobar 0 --hard')).to match %r{foobar/0 has been detached}
      expect( director.vms.size).to eq(0)

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
  end
end
