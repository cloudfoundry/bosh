require_relative '../../spec_helper'

describe 'run-errand success', type: :integration, with_tmp_dir: true do
  let(:manifest_hash) { Bosh::Spec::Deployments.manifest_with_errand_job_on_service_instance }
  let(:deployment_name) { manifest_hash['name'] }

  with_reset_sandbox_before_each

  it 'runs the errand referenced by the job name on a service lifecycle instance' do
    deploy_from_scratch(manifest_hash: manifest_hash)

    output = bosh_runner.run('run-errand errand1', deployment_name: deployment_name)

    expect(output).to match /fake-errand-stdout-service/
    expect(output).to match /Succeeded/
  end
end
