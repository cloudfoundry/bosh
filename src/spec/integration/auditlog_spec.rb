require 'spec_helper'

describe 'Audit log', type: :integration do
  with_reset_sandbox_before_all(user_authentication: 'uaa')

  let(:audit_director_log) { File.join(current_sandbox.logs_path, 'audit.log') }
  let(:audit_worker_0_log) { File.join(current_sandbox.logs_path, 'audit_worker_0.log') }
  let(:audit_worker_1_log) { File.join(current_sandbox.logs_path, 'audit_worker_1.log') }
  let(:audit_worker_2_log) { File.join(current_sandbox.logs_path, 'audit_worker_2.log') }

  before(:all) do
    deploy_from_scratch(
      manifest_hash: Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups,
      cloud_config_hash: Bosh::Spec::DeploymentManifestHelper.simple_cloud_config,
      client: 'audit_log',
      client_secret: 'auditsecret',
    )
  end

  it 'writes audit logs' do
    expect(File).to exist(audit_director_log)
    expect(File).to exist(audit_worker_0_log)
    expect(File).to exist(audit_worker_1_log)
    expect(File).to exist(audit_worker_2_log)
  end

  it 'contains request logs' do
    audit_log_content = File.open(audit_director_log).read

    audit_log_entries = audit_log_content.scan(
      %r{^I.*CEF.*\|/deployments\|.*\|requestClientApplication=audit_log .*requestMethod=POST.*},
    )

    expect(audit_log_entries.size).to eq(1)
  end

  it 'contains event logs' do
    worker_logs_content = File.open(audit_worker_0_log).read +
                          File.open(audit_worker_1_log).read +
                          File.open(audit_worker_2_log).read

    audit_log_entries = worker_logs_content.scan(/I.*"user":"audit_log".*"action":"create".*"object_type":"deployment".*/)

    expect(audit_log_entries.size).to eq(2)
  end
end
