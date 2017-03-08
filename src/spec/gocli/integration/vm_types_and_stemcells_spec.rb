require_relative '../spec_helper'

describe 'vm_types and stemcells', type: :integration do
  with_reset_sandbox_before_each

  let(:cloud_config_hash) do
    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    cloud_config_hash.delete('resource_pools')

    cloud_config_hash['vm_types'] = [Bosh::Spec::Deployments.vm_type]
    cloud_config_hash
  end

  let(:env_hash) do
    {
      'env1' => 'env_value1',
      'env2' => 'env_value2',
      'bosh' => {
        'group' => 'testdirector-simple-foobar',
        'groups' =>['testdirector', 'simple', 'foobar', 'testdirector-simple', 'simple-foobar', 'testdirector-simple-foobar']
      },
    }
  end

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash.delete('resource_pools')
    manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]
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
    manifest_hash
  end

  it 'deploys with vm_types and stemcells and env' do
    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

    create_vm_invocations = current_sandbox.cpi.invocations_for_method('create_vm')
    expect(create_vm_invocations.last.inputs['env']).to eq(env_hash)
    expect(table(bosh_runner.run('deployments', json: true))).to eq([
      {
        'name' => 'simple',
        'release_s' => 'bosh-release/0+dev.1',
        'stemcell_s' => 'ubuntu-stemcell/1',
        'team_s' => '',
        'cloud_config' => 'latest'
      }
    ])
  end

  it 'saves manifest with resolved latest stemcell versions' do
    manifest_hash['stemcells'].first['version'] = 'latest'
    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    expect(bosh_runner.run('download-manifest', deployment_name: 'simple')).to match_output %(
stemcells:
- alias: default
  os: toronto-os
  version: '1'
    )
  end

  context 'when env on a job changes' do
    it 'should re-deploy' do
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
        'env' => {"bosh"=>{"password"=>"foobar"}}
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
        'env2' => 'env_value2',
        'bosh' => {
          'group' => 'testdirector-simple-foobar',
          'groups' =>['testdirector', 'simple', 'foobar', 'testdirector-simple', 'simple-foobar', 'testdirector-simple-foobar']
        },
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

  context 'cloud config has vm_extensions and compilation consuming some vm extensions' do

    let(:vm_extension_1) do {
          'name' => 'vm-extension-1-name',
          'cloud_properties' => {'prop1' => 'val1', 'prop2' => 'val2'}
    } end

    let(:vm_extension_2) do {
        'name' => 'vm-extension-2-name',
        'cloud_properties' => {'prop3' => 'val3', 'prop2' => 'val4'}
    } end

    let(:vm_extension_3) do {
        'name' => 'vm-extension-3-name',
        'cloud_properties' => {'prop1' => 'val8', 'prop3' => 'val3'}
    } end

    let(:vm_type_1) do {
        'name' => 'vm-type-1-name',
        'cloud_properties' => {'prop1' => 'val5', 'prop4' => 'val6'}
    } end

    let(:az_1) do {
        'name' => 'a',
        'cloud_properties' => {'prop5' => 'val7', 'prop1' => 'val1_overwritten', 'prop4' => 'val2_overwritten'}
    } end

    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config_hash.delete('resource_pools')
      cloud_config_hash['vm_extensions'] = [vm_extension_1, vm_extension_2, vm_extension_3]
      cloud_config_hash['vm_types'] = [vm_type_1]
      cloud_config_hash['azs'] = [az_1]
      cloud_config_hash['networks'].first['subnets'].first['az'] = 'a'
      cloud_config_hash['compilation']['az'] = 'a'
      cloud_config_hash['compilation']['vm_extensions'] = ['vm-extension-1-name', 'vm-extension-3-name']
      cloud_config_hash['compilation']['vm_type'] = 'vm-type-1-name'
      cloud_config_hash
    end

    context 'deployment instance group uses other vm_extensions' do
      let(:manifest_hash) do
        manifest_hash = Bosh::Spec::Deployments.simple_manifest
        manifest_hash.delete('resource_pools')
        manifest_hash['stemcells'] = [Bosh::Spec::Deployments.stemcell]
        manifest_hash['jobs'] = [{
            'name' => 'foobar',
            'templates' => ['name' => 'foobar'],
            'vm_type' => 'vm-type-1-name',
            'vm_extensions' => ['vm-extension-1-name', 'vm-extension-2-name'],
            'azs' => ['a'],
            'stemcell' => 'default',
            'instances' => 1,
            'networks' => [{ 'name' => 'a' }],
            'properties' => {},
            'env' => env_hash
          }]
        manifest_hash
      end

      it 'deploys with merged cloud_properties for compiled and non-compiled vms' do
        deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

        create_compiled_vm_invocation = current_sandbox.cpi.invocations_for_method('create_vm').first
        expect(create_compiled_vm_invocation.inputs['cloud_properties']).to eq({'prop1' => 'val8', 'prop2' => 'val2', 'prop3' => 'val3', 'prop4' => 'val6', 'prop5' => 'val7'})

        create_instance_vm_invocation = current_sandbox.cpi.invocations_for_method('create_vm').last
        expect(create_instance_vm_invocation.inputs['cloud_properties']).to eq({'prop1' => 'val1', 'prop2' => 'val4', 'prop3' => 'val3', 'prop4' => 'val6', 'prop5' => 'val7'})
      end
    end
  end
end
