require_relative '../spec_helper'

describe 'cli: logs', type: :integration do
  with_reset_sandbox_before_each

  it 'can fetch logs by id or index' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(instances: 3, name: 'first-job')]
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    vms = director.instances
    id = vms.first.id
    index = vms.first.index

    deployment_name = manifest_hash['name']

    expect(bosh_runner.run("-d #{deployment_name} logs first-job/#{index}")).to match /first-job\..*\.tgz/

    expect(bosh_runner.run("-d #{deployment_name} logs first-job/'#{id}'")).to match /first-job\..*\.tgz/
    expect(bosh_runner.run("-d #{deployment_name} logs first-job/'#{id}'")).to include "Fetching logs for first-job/#{id} (#{index})"
  end
end
