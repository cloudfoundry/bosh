require 'spec_helper'

describe 'disk pools', type: :integration do
  with_reset_sandbox_before_each

  it 'allows specifying a disk_pool' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash['disk_pools'] = [
      {
        'name' => 'fast_disks',
        'disk_size' => 3000,
      }
    ]

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['persistent_disk_pool'] = 'fast_disks'

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

    director.vms.each do |vm|
      expect(vm.get_state['persistent_disk']).to eq(3000)
    end
  end

  it 'allows specifying persistent_disk size on a job' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['persistent_disk'] = 3000

    deploy_from_scratch(manifest_hash: manifest_hash)

    director.vms.each do |vm|
      expect(vm.get_state['persistent_disk']).to eq(3000)
    end
  end

  it 'allows NOT specifying a persistent_disk' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first.delete('persistent_disk')
    deploy_from_scratch(manifest_hash: manifest_hash)

    director.vms.each do |vm|
      expect(vm.get_state['persistent_disk']).to eq(0)
    end
  end
end
