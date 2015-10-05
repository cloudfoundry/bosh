require 'spec_helper'

describe 'vm_types and stemcells', type: :integration do
  with_reset_sandbox_before_each

  it 'deploys with vm_types and stemcells' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash.delete('resource_pools')

    cloud_config_hash['vm_types'] = [Bosh::Spec::Deployments.vm_type]

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash.delete('resource_pools')
    manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]

    manifest_hash['jobs'] = [{
      'name' => 'foobar',
      'templates' => ['name' => 'foobar'],
      'vm_type' => 'vm-type-name',
      'stemcell' => 'default',
      'instances' => 3,
      'networks' => [{ 'name' => 'a' }],
      'properties' => {},
    }]
    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
  end

  it 're-creates instance when with vm_type changes' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash.delete('resource_pools')

    vm_type1 = Bosh::Spec::Deployments.vm_type
    vm_type2 = Bosh::Spec::Deployments.vm_type
    vm_type2['name'] = 'new-vm-type-name'
    cloud_config_hash['vm_types'] = [vm_type1, vm_type2]

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash.delete('resource_pools')
    manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]

    manifest_hash['jobs'] = [{
        'name' => 'foobar',
        'templates' => ['name' => 'foobar'],
        'vm_type' => 'vm-type-name',
        'stemcell' => 'default',
        'instances' => 3,
        'networks' => [{ 'name' => 'a' }],
        'properties' => {},
      }]

    puts manifest_hash.pretty_inspect

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

    create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
    expect(create_vm_invocations.count).to be > 0

    manifest_hash['jobs'].first['vm_type'] = 'new-vm-type-name'

    puts manifest_hash.pretty_inspect

    deploy_simple_manifest(manifest_hash: manifest_hash)

    new_create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
    expect(new_create_vm_invocations.count).to be > create_vm_invocations.count

  end

  #TODO Remove this test when backward compatibility of resource pool is no longer required
  context 'when migrating from resource pool to vm_type and stemcell' do
    it 'should not re-creates instance when with vm_type and stemcell do not change' do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config

      manifest_hash = Bosh::Spec::Deployments.simple_manifest

      puts manifest_hash.pretty_inspect

      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

      create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      puts create_vm_invocations.pretty_inspect


      expect(create_vm_invocations.count).to be > 0

      stemcell_hash = cloud_config_hash['resource_pools'].first['stemcell']
      stemcell_hash['alias'] = 'default'
      manifest_hash['stemcells'] = [stemcell_hash]

      cloud_config_hash.delete('resource_pools')
      vm_type1 = Bosh::Spec::Deployments.vm_type
      vm_type2 = Bosh::Spec::Deployments.vm_type
      vm_type2['name'] = 'a'
      cloud_config_hash['vm_types'] = [vm_type1, vm_type2]
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      manifest_hash.delete('resource_pools')

      manifest_hash['jobs'] = [{
          'name' => 'foobar',
          'templates' => ['name' => 'foobar'],
          'vm_type' => 'a',
          'stemcell' => 'default',
          'instances' => 3,
          'networks' => [{ 'name' => 'a' }],
          'properties' => {},
        }]

      puts manifest_hash.pretty_inspect

      deploy_simple_manifest(manifest_hash: manifest_hash)

      new_create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      puts new_create_vm_invocations.pretty_inspect

      expect(new_create_vm_invocations.count).to eq(create_vm_invocations.count)

    end
  end
end
