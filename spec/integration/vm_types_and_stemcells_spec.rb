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

end
