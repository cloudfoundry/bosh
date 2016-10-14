require_relative '../spec_helper'

describe 'cli: logs', type: :integration do
  with_reset_sandbox_before_each

  it 'can fetch logs' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(instances: 2, name: 'first-job')]
    manifest_hash['jobs']<< {
        'name' => 'another-job',
        'template' => 'foobar',
        'resource_pool' => 'a',
        'instances' => 1,
        'networks' => [{'name' => 'a'}],
    }
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
    vms = director.vms
    vm_0 = get_vm(vms, 'first-job', "0")
    vm_1 = get_vm(vms, 'first-job', "1")
    vm_2 = get_vm(vms, 'another-job', "0")

    deployment_name = manifest_hash['name']

    expect(bosh_runner.run("-d #{deployment_name} logs first-job/1")).to match /#{deployment_name}.first-job.*\.tgz/

    expect(bosh_runner.run("-d #{deployment_name} logs first-job/'#{vm_1.instance_uuid}'")).to match /#{deployment_name}.first-job.*\.tgz/
    expect(bosh_runner.run("-d #{deployment_name} logs first-job/'#{vm_1.instance_uuid}'")).to include "Fetching logs for #{vm_0.job_name}/#{vm_1.instance_uuid} (1)"

    output_single_job = bosh_runner.run("-d #{deployment_name} logs first-job")
    expect(output_single_job).to match /#{deployment_name}.first-job-.*\.tgz/

    expect(output_single_job).to include "Fetching logs for #{vm_0.job_name}/#{vm_0.instance_uuid} (#{vm_0.index})"
    expect(output_single_job).to include "Fetching logs for #{vm_1.job_name}/#{vm_1.instance_uuid} (#{vm_1.index})"
    expect(output_single_job).to include "Fetching group of logs: Packing log files together"

    output_deployment = bosh_runner.run("-d #{deployment_name} logs")
    expect(output_deployment).to match /#{deployment_name}-.*\.tgz/

    expect(output_deployment).to include "Fetching logs for #{vm_0.job_name}/#{vm_0.instance_uuid} (#{vm_0.index})"
    expect(output_deployment).to include "Fetching logs for #{vm_1.job_name}/#{vm_1.instance_uuid} (#{vm_1.index})"
    expect(output_deployment).to include "Fetching logs for #{vm_2.job_name}/#{vm_2.instance_uuid} (#{vm_2.index})"
    expect(output_deployment).to include "Fetching group of logs: Packing log files together"
  end

  private

  def get_vm(vms, name, index)
    vms.select{|vm| vm.job_name == name && vm.index == index}.first
  end
end
