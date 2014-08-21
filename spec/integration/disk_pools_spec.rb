require 'spec_helper'

describe 'disk pools', type: :integration do
  with_reset_sandbox_before_each

  it 'allows specifying a disk_pool' do
    manifest = Bosh::Spec::Deployments.simple_manifest
    manifest['disk_pools'] = [{
      'name' => 'fast_disks',
      'disk_size' => 3000,
    }]
    manifest['jobs'].first['persistent_disk_pool'] = 'fast_disks'

    deploy_simple(manifest_hash: manifest)

    director.vms.each do |vm|
      expect(vm.get_state['persistent_disk']).to eq(3000)
    end
  end

  it 'allows specifying persistent_disk size on a job' do
    manifest = Bosh::Spec::Deployments.simple_manifest
    manifest['jobs'].first['persistent_disk'] = 3000

    deploy_simple(manifest_hash: manifest)

    director.vms.each do |vm|
      expect(vm.get_state['persistent_disk']).to eq(3000)
    end
  end

  it 'allows NOT specifying a persistent_disk' do
    manifest = Bosh::Spec::Deployments.simple_manifest

    deploy_simple(manifest_hash: manifest)

    director.vms.each do |vm|
      expect(vm.get_state['persistent_disk']).to eq(0)
    end
  end
end
