require_relative '../../spec_helper'

describe 'tasks config', type: :integration do
  with_reset_sandbox_before_each

  let(:config_limit_1) { yaml_file('config', Bosh::Spec::NewDeployments.tasks_config) }
  let(:config_limit_2) { yaml_file('config', Bosh::Spec::NewDeployments.tasks_config(limit: 2)) }

  it 'applies rate_limit number for delayed job groups' do
    create_and_upload_test_release
    upload_stemcell

    cloud_config = Bosh::Spec::NewDeployments.simple_cloud_config
    upload_cloud_config(cloud_config_hash: cloud_config)
    first_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(
      name: 'first', instances: 1,
      job: 'foobar_without_packages'
    )
    second_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(
      name: 'second', instances: 1,
      job: 'foobar_without_packages'
    )

    bosh_runner.run("update-config --type tasks --name default #{config_limit_1.path}")
    first_task_id = Bosh::Spec::DeployHelper.start_deploy(first_deployment_manifest)
    second_task_id = Bosh::Spec::DeployHelper.start_deploy(second_deployment_manifest)

    Bosh::Spec::DeployHelper.wait_for_task_to_succeed(first_task_id)
    Bosh::Spec::DeployHelper.wait_for_task_to_succeed(second_task_id)

    output = bosh_runner.run('events --object-type=deployment', json: true)
    data = table(output)

    # with rate_limit = 1 firstly first deployment, then the second one
    expect(data[0]['deployment']).to eq(data[1]['deployment'])

    bosh_runner.run("update-config --type tasks --name default #{config_limit_2.path}")

    first_deployment_manifest['instance_groups'] = [Bosh::Spec::NewDeployments.simple_instance_group(
      instances: 2,
      job: 'foobar_without_packages',
    )]
    second_deployment_manifest['instance_groups'] = [Bosh::Spec::NewDeployments.simple_instance_group(
      instances: 2,
      job: 'foobar_without_packages',
    )]

    first_task_id = Bosh::Spec::DeployHelper.start_deploy(first_deployment_manifest)
    second_task_id = Bosh::Spec::DeployHelper.start_deploy(second_deployment_manifest)

    Bosh::Spec::DeployHelper.wait_for_task_to_succeed(first_task_id)
    Bosh::Spec::DeployHelper.wait_for_task_to_succeed(second_task_id)

    output = bosh_runner.run('events --object-type=deployment --action=update', json: true)
    data = table(output)

    # with rate_limit = 2 two deployments are in parallel
    expect(data[0]['deployment']).not_to eq(data[1]['deployment'])
  end
end
