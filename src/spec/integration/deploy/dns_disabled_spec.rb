require 'spec_helper'

describe 'dns disabled', type: :integration do
  with_reset_sandbox_before_each(dns_enabled: false)

  it 'allows removing deployed jobs and adding new jobs at the same time' do
    manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['name'] = 'fake-name1'
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
    expect_running_vms_with_names_and_count('fake-name1' => 3)

    manifest_hash['instance_groups'].first['name'] = 'fake-name2'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('fake-name2' => 3)

    manifest_hash['instance_groups'].first['name'] = 'fake-name1'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('fake-name1' => 3)
  end
end
