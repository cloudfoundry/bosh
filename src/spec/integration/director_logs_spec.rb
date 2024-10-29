require 'spec_helper'

describe 'director logs', type: :integration do
  with_reset_sandbox_before_each

  it 'redacts them' do
    deploy_from_scratch(manifest_hash: Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups)
    expect(current_sandbox.director_service.read_log).to match(/UPDATE .*? <redacted>/)
    expect(current_sandbox.director_service.read_log).to match(/INSERT INTO .*? <redacted>/)
  end
end
