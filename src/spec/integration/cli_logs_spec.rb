require 'spec_helper'

describe 'cli: logs', type: :integration do
  with_reset_sandbox_before_each

  it 'can fetch logs by id or index' do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'] = [Bosh::Spec::Deployments.simple_job(instances: 3, name: 'first-job')]
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
    id = director.vms.first.instance_uuid

    expect(bosh_runner.run('logs first-job 1')).to match /first-job\.1\..*\.tgz/

    expect(bosh_runner.run("logs first-job '#{id}'")).to match /first-job\.#{id}\..*\.tgz/
    expect(bosh_runner.run("logs first-job '#{id}'")).to include "Started fetching logs for first-job/#{id} (0)"
  end
end
