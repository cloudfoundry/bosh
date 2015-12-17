require 'spec_helper'

describe 'vm_types and stemcells', type: :integration do
  with_reset_sandbox_before_each

  it 'deploys with vm_types and stemcells and env' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash.delete('resource_pools')

    cloud_config_hash['vm_types'] = [Bosh::Spec::Deployments.vm_type]

    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash.delete('resource_pools')
    manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]

    env_hash = {
      'env1' => 'env_value1',
      'env2' => 'env_value2'
    }

    manifest_hash['jobs'] = [{
      'name' => 'foobar',
      'templates' => ['name' => 'foobar'],
      'vm_type' => 'vm-type-name',
      'stemcell' => 'default',
      'instances' => 1,
      'networks' => [{ 'name' => 'a' }],
      'properties' => {},
      'env' => env_hash
    }]
    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

    create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
    expect(create_vm_invocations.last.inputs['env']).to eq(env_hash)
    expect(bosh_runner.run('deployments')).to match_output  %(
+--------+----------------------+-------------------+--------------+
| Name   | Release(s)           | Stemcell(s)       | Cloud Config |
+--------+----------------------+-------------------+--------------+
| simple | bosh-release/0+dev.1 | ubuntu-stemcell/1 | latest       |
+--------+----------------------+-------------------+--------------+
    )
  end

  context 'when env on a job changes' do
    it 'should re-deploy' do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config_hash.delete('resource_pools')

      cloud_config_hash['vm_types'] = [Bosh::Spec::Deployments.vm_type]

      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash.delete('resource_pools')
      manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]

      env_hash = {
        'env1' => 'env_value1',
        'env2' => 'env_value2'
      }

      manifest_hash['jobs'] = [{
          'name' => 'foobar',
          'templates' => ['name' => 'foobar'],
          'vm_type' => 'vm-type-name',
          'stemcell' => 'default',
          'instances' => 1,
          'networks' => [{ 'name' => 'a' }],
          'properties' => {},
          'env' => env_hash
        }]
      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

      create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(create_vm_invocations.last.inputs['env']).to eq(env_hash)

      env_hash['env2'] = 'new_env_value'
      manifest_hash['jobs'].first['env'] = env_hash

      deploy_simple_manifest(manifest_hash: manifest_hash)

      new_create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(new_create_vm_invocations.count).to be > create_vm_invocations.count
      expect(new_create_vm_invocations.last.inputs['env']).to eq(env_hash)

    end
  end

  context 'when instance is deployed originally with stemcell specified with name' do
    it 'should not re-deploy if the stemcell is the same one' do
      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      deploy_from_scratch(manifest_hash: manifest_hash)

      create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(create_vm_invocations.count).to be > 0

      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
      vm_type1 = Bosh::Spec::Deployments.vm_type
      vm_type1['name'] = 'a'
      cloud_config_hash['vm_types'] = [vm_type1]
      cloud_config_hash.delete('resource_pools')
      upload_cloud_config(cloud_config_hash: cloud_config_hash)

      manifest_hash.delete('resource_pools')
      manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]

      manifest_hash['jobs'] = [{
        'name' => 'foobar',
        'templates' => ['name' => 'foobar'],
        'vm_type' => 'a',
        'stemcell' => 'default',
        'instances' => 3,
        'networks' => [{ 'name' => 'a' }],
        'properties' => {},
      }]

      deploy_simple_manifest(manifest_hash: manifest_hash)

      new_create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(new_create_vm_invocations.count).to eq(create_vm_invocations.count)
    end
  end

  it 'recreates instance when with vm_type changes' do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash.delete('resource_pools')

    vm_type1 = Bosh::Spec::Deployments.vm_type
    vm_type2 = Bosh::Spec::Deployments.vm_type
    vm_type2['name'] = 'renamed-vm-type'
    vm_type3 = Bosh::Spec::Deployments.vm_type
    vm_type3['name'] = 'changed-vm-type-cloud-properties'
    vm_type3['cloud_properties']['blarg'] = ['ful']
    cloud_config_hash['vm_types'] = [vm_type1, vm_type2, vm_type3]

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

    create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
    expect(create_vm_invocations.count).to be > 0

    manifest_hash['jobs'].first['vm_type'] = 'renamed-vm-type'

    deploy_simple_manifest(manifest_hash: manifest_hash)

    new_create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
    expect(new_create_vm_invocations.count).to eq(create_vm_invocations.count)

    manifest_hash['jobs'].first['vm_type'] = 'changed-vm-type-cloud-properties'

    deploy_simple_manifest(manifest_hash: manifest_hash)

    new_create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
    expect(new_create_vm_invocations.count).to be > create_vm_invocations.count

  end

  #TODO Remove this test when backward compatibility of resource pool is no longer required
  context 'when migrating from resource pool to vm_type and stemcell' do
    it 'should not recreate instance when with vm_type and stemcell do not change' do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
      env_hash = {
        'env1' => 'env_value1',
        'env2' => 'env_value2'
      }
      cloud_config_hash['resource_pools'].first['env'] = env_hash

      manifest_hash = Bosh::Spec::Deployments.simple_manifest

      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

      create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(create_vm_invocations.count).to be > 0
      expect(create_vm_invocations.last.inputs['env']).to eq(env_hash)

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
          'env' => env_hash
        }]

      deploy_simple_manifest(manifest_hash: manifest_hash)

      new_create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
      expect(new_create_vm_invocations.count).to eq(create_vm_invocations.count)
    end
  end
end
