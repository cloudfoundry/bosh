require 'spec_helper'

describe 'shared network', type: :integration do
  with_reset_sandbox_before_each

  before do
    target_and_login
    create_and_upload_test_release
    upload_stemcell

    cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
    # remove size from resource pools due to bug #94220432
    # where resource pools with specified size reserve extra IPs
    cloud_config_hash['resource_pools'].first.delete('size')
    upload_cloud_config(cloud_config_hash: cloud_config_hash)
  end

  it 'deployments with shared manual network get next available IP from range' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1

    deploy_simple_manifest(manifest_hash: manifest_hash)
    first_deployment_vms = director.vms
    expect(first_deployment_vms.size).to eq(1)
    expect(first_deployment_vms.first.ips).to eq('192.168.1.2')

    second_manifest_hash = Bosh::Spec::Deployments.simple_manifest
    second_manifest_hash['name'] = 'second_deployment'
    second_manifest_hash['jobs'].first['instances'] = 1

    deploy_simple_manifest(manifest_hash: second_manifest_hash)
    second_deployment_vms = director.vms('second_deployment')
    expect(second_deployment_vms.size).to eq(1)
    expect(second_deployment_vms.first.ips).to eq('192.168.1.3')
  end
end
