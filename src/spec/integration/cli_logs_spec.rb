require 'spec_helper'

describe 'cli: logs', type: :integration do
  with_reset_sandbox_before_each

  it 'can fetch logs' do
    manifest = Bosh::Spec::Deployments.simple_manifest_with_instance_groups
    manifest['instance_groups'] = [Bosh::Spec::Deployments.simple_instance_group(instances: 2, name: 'first-job')]
    manifest['instance_groups'] << {
      'name' => 'another-job',
      'jobs' => [{ 'name' => 'foobar', 'release' => 'bosh-release' }],
      'vm_type' => 'a',
      'instances' => 1,
      'networks' => [{ 'name' => 'a' }],
      'stemcell' => 'default',
    }

    manifest['instance_groups'] << {
      'name' => 'fake-errand-name',
      'jobs' => [{ 'name' => 'errand_without_package', 'release' => 'bosh-release' }],
      'vm_type' => 'a',
      'instances' => 1,
      'lifecycle' => 'errand',
      'networks' => [{ 'name' => 'a' }],
      'stemcell' => 'default',
    }
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    deploy_from_scratch(manifest_hash: manifest, cloud_config_hash: cloud_config)

    instances = director.instances
    instance0 = get_instance(instances, 'first-job', '0')
    instance1 = get_instance(instances, 'first-job', '1')
    instance2 = get_instance(instances, 'another-job', '0')

    deployment_name = manifest['name']

    expect(bosh_runner.run("-d #{deployment_name} logs first-job/1")).to match(/#{deployment_name}.first-job.*\.tgz/)

    expect(bosh_runner.run("-d #{deployment_name} logs first-job/'#{instance1.id}'")).to match(/#{deployment_name}.first-job.*\.tgz/)
    expect(bosh_runner.run("-d #{deployment_name} logs first-job/'#{instance1.id}'")).to include "Fetching logs for #{instance0.instance_group_name}/#{instance1.id} (1)"

    output_single_job = bosh_runner.run("-d #{deployment_name} logs first-job")
    expect(output_single_job).to match(/#{deployment_name}.first-job-.*\.tgz/)

    expect(output_single_job).to include "Fetching logs for #{instance0.instance_group_name}/#{instance0.id} (#{instance0.index})"
    expect(output_single_job).to include "Fetching logs for #{instance1.instance_group_name}/#{instance1.id} (#{instance1.index})"
    expect(output_single_job).to include 'Fetching group of logs: Packing log files together'

    output_deployment, exit_code = bosh_runner.run("-d #{deployment_name} logs", return_exit_code: true)
    expect(exit_code).to eq(0)
    expect(output_deployment).to match(/#{deployment_name}-.*\.tgz/)

    expect(output_deployment).to include "Fetching logs for #{instance0.instance_group_name}/#{instance0.id} (#{instance0.index})"
    expect(output_deployment).to include "Fetching logs for #{instance1.instance_group_name}/#{instance1.id} (#{instance1.index})"
    expect(output_deployment).to include "Fetching logs for #{instance2.instance_group_name}/#{instance2.id} (#{instance2.index})"
    expect(output_deployment).to include 'Fetching group of logs: Packing log files together'
  end

  private

  def get_instance(instances, name, index)
    instances.select { |instance| instance.instance_group_name == name && instance.index == index }.first
  end
end
