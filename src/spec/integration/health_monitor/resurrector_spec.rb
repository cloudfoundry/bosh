require 'spec_helper'

describe 'resurrector', type: :integration, hm: true do
  with_reset_sandbox_before_each

  before do
    create_and_upload_test_release
    upload_stemcell
  end

  let(:cloud_config_hash) do
    cloud_config_hash = SharedSupport::DeploymentManifestHelper.simple_cloud_config

    cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11']
    cloud_config_hash
  end

  let(:simple_manifest) do
    manifest_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['instances'] = 1
    manifest_hash
  end

  it 'resurrects vms based on resurrection config' do
    resurrection_config_enabled = yaml_file('config.yml', SharedSupport::DeploymentManifestHelper.resurrection_config_enabled)
    resurrection_config_disabled = yaml_file('config.yml', SharedSupport::DeploymentManifestHelper.resurrection_config_disabled)
    bosh_runner.run("update-config --type resurrection --name enabled #{resurrection_config_enabled.path}")
    bosh_runner.run("update-config --type resurrection --name disabled #{resurrection_config_disabled.path}")
    current_sandbox.reconfigure_health_monitor

    deployment_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
    deployment_hash['instance_groups'][0]['instances'] = 1
    deployment_hash_enabled = deployment_hash.merge('name' => 'simple_enabled')
    deployment_hash_disabled = deployment_hash.merge('name' => 'simple_disabled')
    job_opts = {
      name: 'foobar_without_packages',
      jobs: [{ 'name' => 'foobar_without_packages', 'release' => 'bosh-release' }],
      instances: 1,
    }
    deployment_hash_disabled['instance_groups'][1] = SharedSupport::DeploymentManifestHelper.simple_instance_group(job_opts)
    bosh_runner.run("upload-release #{asset_path('dummy2-release.tgz')}")
    upload_cloud_config(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)

    # deploy simple_enabled
    deploy_simple_manifest(manifest_hash: deployment_hash_enabled)
    orig_instance_enabled = director.instance('foobar', '0', deployment_name: 'simple_enabled')
    resurrected_instance = director.kill_vm_and_wait_for_resurrection(orig_instance_enabled, deployment_name: 'simple_enabled')
    expect(resurrected_instance.vm_cid).to_not eq(orig_instance_enabled.vm_cid)

    # deploy simple_disabled
    deploy_simple_manifest(manifest_hash: deployment_hash_disabled)
    instances = director.instances(deployment_name: 'simple_disabled')
    orig_instance_enabled = director.find_instance(instances, 'foobar_without_packages', '0')
    disabled_instance = director.find_instance(instances, 'foobar', '0')

    resurrected_instance = director.kill_vm_and_wait_for_resurrection(orig_instance_enabled, deployment_name: 'simple_disabled')
    expect(resurrected_instance.vm_cid).to_not eq(orig_instance_enabled.vm_cid)

    disabled_instance.kill_agent
    expect(director.wait_for_vm('foobar', '0', 150, deployment_name: 'simple_disabled')).to be_nil
  end

  it "respects 'serial' property" do
    current_sandbox.reconfigure_health_monitor

    deployment_hash = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups
    deployment_hash['update']['serial'] = true
    deployment_hash['update']['max_in_flight'] = 2

    deployment_hash['instance_groups'][0]['instances'] = 2
    deployment_hash['instance_groups'][0]['name'] = 'ig_1'

    ig2 = {
      name: 'ig_2',
      jobs: [{ 'name' => 'foobar', 'release' => 'bosh-release' }],
      instances: 2,
    }
    deployment_hash['instance_groups'][1] = SharedSupport::DeploymentManifestHelper.simple_instance_group(ig2)

    upload_cloud_config(cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config)
    deploy_simple_manifest(manifest_hash: deployment_hash)

    instances = director.instances
    ig1_instances = instances.select { |i| i.instance_group_name == 'ig_1' }
    ig2_instances = instances.select { |i| i.instance_group_name == 'ig_2' }

    bosh_runner.run('update-resurrection off')
    ig2_instances.each(&:kill_agent)
    ig1_instances.each(&:kill_agent)
    bosh_runner.run('update-resurrection on')

    ig2_instances.each { |i| director.wait_for_vm('ig_2', i.index, 300) }
    ig1_instances.each { |i| director.wait_for_vm('ig_1', i.index, 300) }

    director.wait_for_resurrection_to_finish
    resurrection_task = director.tasks.filter(
      username: 'hm',
      description: 'scan and fix',
      state: 'done',
      event_output: /Applying problem resolutions/,
    ).first

    resurrection_order = /.*ig_2.*ig_1.*/m
    expect(resurrection_task[:event_output]).to_not match(resurrection_order)
  end
end
