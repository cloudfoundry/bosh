require 'spec_helper'

describe 'ignore/unignore-instance', type: :integration do
  with_reset_sandbox_before_each

  it 'changes the ignore value of vms correctly' do
    manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
    cloud_config = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    director.instances.each do |instance|
      expect(instance.ignore).to eq('false')
    end

    initial_instances = director.instances
    instance1 = initial_instances[0]
    instance2 = initial_instances[1]
    instance3 = initial_instances[2]

    bosh_runner.run("ignore #{instance1.instance_group_name}/#{instance1.id}", deployment_name: 'simple')
    bosh_runner.run("ignore #{instance2.instance_group_name}/#{instance2.id}", deployment_name: 'simple')
    expect(director.instance(instance1.instance_group_name, instance1.id).ignore).to eq('true')
    expect(director.instance(instance2.instance_group_name, instance2.id).ignore).to eq('true')
    expect(director.instance(instance3.instance_group_name, instance3.id).ignore).to eq('false')

    bosh_runner.run("unignore #{instance2.instance_group_name}/#{instance2.id}", deployment_name: 'simple')
    expect(director.instance(instance1.instance_group_name, instance1.id).ignore).to eq('true')
    expect(director.instance(instance2.instance_group_name, instance2.id).ignore).to eq('false')
    expect(director.instance(instance3.instance_group_name, instance3.id).ignore).to eq('false')
  end

  it 'fails when deleting deployment that has ignored instances even when using force flag' do
    manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
    cloud_config = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config

    manifest_hash['instance_groups'].clear
    manifest_hash['instance_groups'] << Bosh::Spec::DeploymentManifestHelper.simple_instance_group(name: 'foobar1', instances: 2)

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    foobar1_instance1 = director.instances.first
    bosh_runner.run("ignore #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

    output, exit_code = bosh_runner.run(
      'delete-deployment',
      deployment_name: 'simple',
      failure_expected: true,
      return_exit_code: true,
    )
    expect(exit_code).to_not eq(0)
    expect(output).to include(
      "You are trying to delete deployment 'simple', which contains ignored instance(s). Operation not allowed.",
    )

    output, exit_code = bosh_runner.run(
      'delete-deployment --force',
      deployment_name: 'simple',
      failure_expected: true,
      return_exit_code: true,
    )
    expect(exit_code).to_not eq(0)
    expect(output).to include(
      "You are trying to delete deployment 'simple', which contains ignored instance(s). Operation not allowed.",
    )
  end

  it 'fails when trying to attach a disk to an ignored instance' do
    manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
    cloud_config = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config

    manifest_hash['instance_groups'].clear
    manifest_hash['instance_groups'] << Bosh::Spec::DeploymentManifestHelper.simple_instance_group(name: 'foobar1', instances: 2)

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    foobar1_instance1 = director.instances.first
    bosh_runner.run("stop #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id} --hard", deployment_name: 'simple')

    bosh_runner.run("ignore #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}", deployment_name: 'simple')

    output, exit_code = bosh_runner.run(
      "attach-disk #{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id} smurf-disk",
      deployment_name: 'simple',
      failure_expected: true,
      return_exit_code: true,
    )
    expect(exit_code).to_not eq(0)
    expect(output).to include(
      "Error: Instance '#{foobar1_instance1.instance_group_name}/#{foobar1_instance1.id}' " \
      "in deployment 'simple' is in 'ignore' state. " \
      'Attaching disks to ignored instances is not allowed.',
    )
  end
end
