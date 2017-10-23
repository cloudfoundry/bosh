require_relative '../../spec_helper'

describe 'using director with nats server', type: :integration do
  context 'when NATS ca cert provided does not verify the NATS server certificates' do
    with_reset_sandbox_before_each(with_incorrect_nats_server_ca: true)

    it 'throws certificate validator error' do
      # This test does not upload the specific release intentionally to force a failure
      upload_cloud_config(cloud_config_hash: Bosh::Spec::Deployments.simple_cloud_config)

      output = deploy_simple_manifest(manifest_hash: Bosh::Spec::Deployments.simple_manifest, no_track: true)
      task_id = Bosh::Spec::OutputParser.new(output).task_id('*')

      debug_output = bosh_runner.run("task #{task_id} --debug", failure_expected: true)
      expect(debug_output).to include('NATS client error: TLS Verification failed checking issuer based on CA')
    end
  end
end
