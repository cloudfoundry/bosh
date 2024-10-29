require 'spec_helper'

describe 'basic functionality', type: :integration do
  with_reset_sandbox_before_each

  it 'allows removing deployed jobs and adding new jobs at the same time' do
    manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['name'] = 'fake-name1'
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::DeploymentManifestHelper.simple_cloud_config)
    expect_running_vms_with_names_and_count('fake-name1' => 3)

    manifest_hash['instance_groups'].first['name'] = 'fake-name2'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('fake-name2' => 3)

    manifest_hash['instance_groups'].first['name'] = 'fake-name1'
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('fake-name1' => 3)
  end

  it 'deployment fails when starting task fails' do
    deploy_from_scratch(manifest_hash: Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups)
    director.instance('foobar', '0').fail_start_task
    _, exit_code = deploy(failure_expected: true, return_exit_code: true)
    expect(exit_code).to_not eq(0)
  end

  it 'supports scaling down and then scaling up' do
    manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
    cloud_config_hash = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config

    manifest_hash['instance_groups'].first['instances'] = 3
    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 3)

    manifest_hash['instance_groups'].first['instances'] = 2
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 2)

    manifest_hash['instance_groups'].first['instances'] = 4
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 4)
  end

  it 'supports dynamically sized resource pools' do
    cloud_config_hash = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config

    manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['instances'] = 3

    deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 3)

    # scale down
    manifest_hash['instance_groups'].first['instances'] = 1
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 1)

    # scale up, below original size
    manifest_hash['instance_groups'].first['instances'] = 2
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 2)

    # scale up, above original size
    manifest_hash['instance_groups'].first['instances'] = 4
    deploy_simple_manifest(manifest_hash: manifest_hash)
    expect_running_vms_with_names_and_count('foobar' => 4)
  end

  it 'outputs properly formatted deploy information' do
    # We need to keep this test since the output is not tested and keeps breaking.

    manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['instances'] = 1

    output = deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::DeploymentManifestHelper.simple_cloud_config)

    duration_regex = '\\d\\d:\\d\\d:\\d\\d'
    date_regex = '\\d\\d:\\d\\d:\\d\\d'
    expected_output = <<~EXPECTED_OUTPUT.strip
      #{date_regex} | Preparing deployment: Preparing deployment (#{duration_regex})
      #{date_regex} | Preparing deployment: Rendering templates (#{duration_regex})
      #{date_regex} | Preparing package compilation: Finding packages to compile (#{duration_regex})
      #{date_regex} | Compiling packages: foo/0ee95716c58cf7aab3ef7301ff907118552c2dda (#{duration_regex})
      #{date_regex} | Compiling packages: bar/f1267e1d4e06b60c91ef648fb9242e33ddcffa73 (#{duration_regex})
      #{date_regex} | Creating missing vms: foobar/82a2b496-35f7-4c82-8f6a-9f70af106798 (0) (#{duration_regex})
      #{date_regex} | Updating job foobar: foobar/82a2b496-35f7-4c82-8f6a-9f70af106798 (0) (canary) (#{duration_regex})
    EXPECTED_OUTPUT

    # order for creating missing vms is not guaranteed (running in parallel)
    expect(output).to match(expected_output)
  end

  it 'saves instance name, deployment name, az, and id to the file system on the instance' do
    manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['name'] = 'fake-name1'
    manifest_hash['instance_groups'].first['azs'] = ['zone-1']

    cloud_config_hash = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config
    cloud_config_hash['azs'] = [
      { 'name' => 'zone-1', 'cloud_properties' => {} },
    ]
    cloud_config_hash['compilation']['az'] = 'zone-1'
    cloud_config_hash['networks'].first['subnets'].first['az'] = 'zone-1'

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

    instance = director.instances.first
    agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(instance.vm_cid)

    instance_name = File.read("#{agent_dir}/instance/name")
    deployment_name = File.read("#{agent_dir}/instance/deployment")
    az_name = File.read("#{agent_dir}/instance/az")
    id = File.read("#{agent_dir}/instance/id")

    expect(instance_name).to eq('fake-name1')
    expect(deployment_name).to eq(Bosh::Spec::DeploymentManifestHelper::DEFAULT_DEPLOYMENT_NAME)
    expect(az_name).to eq('zone-1')
    expect(id).to eq(instance.id)
  end
end
