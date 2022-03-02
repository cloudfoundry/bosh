require_relative '../../spec_helper'

describe 'using director with nats server', type: :integration do
  context 'when NATS ca cert provided does not verify the NATS server certificates' do
    with_reset_sandbox_before_each(with_incorrect_nats_server_ca: true)

    it 'throws certificate validator error' do
      # This test does not upload the specific release intentionally to force a failure
      upload_cloud_config
      output, exit_code = deploy_from_scratch(
        failure_expected: true,
        return_exit_code: true,
      )
      expect(exit_code).to_not eq(0)

      task_id = Bosh::Spec::OutputParser.new(output).task_id('*')

      debug_output = bosh_runner.run("task #{task_id} --debug", failure_expected: true)
      expect(debug_output).to match(/NATS client error: SSL_connect returned=1 errno=0 peeraddr=127.0.0.1:\d+ state=error: certificate verify failed/)
    end
  end
end
