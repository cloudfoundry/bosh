require_relative '../../spec_helper'

describe 'using director with nats server', type: :integration do

  # context 'when NATS ca cert path provided is not valid' do
  #   with_reset_sandbox_before_each(with_invalid_nats_server_ca_path: true)
  #
  #   it 'throws certificate validator error' do
  #     manifest_hash = Bosh::Spec::Deployments.simple_manifest
  #     output, exit_code = deploy_from_scratch(manifest_hash: manifest_hash, failure_expected: true, return_exit_code: true)
  #
  #     expect(exit_code).to_not eq(0)
  #     expect(output).to include('Error: An error has occurred while connecting to NATS: TLS Verification is enabled but ca_file /path/to/non/existent/certs is not readable')
  #   end
  # end
  #
  # context 'when NATS ca cert provided does not verify the NATS server certificates' do
  #   with_reset_sandbox_before_each(with_incorrect_nats_server_ca: true)
  #
  #   it 'throws certificate validator error' do
  #     manifest_hash = Bosh::Spec::Deployments.simple_manifest
  #
  #     _, exit_code = deploy_from_scratch(manifest_hash: manifest_hash, failure_expected: true, return_exit_code: true)
  #     expect(exit_code).to_not eq(0)
  #
  #     task_id = bosh_runner.get_most_recent_task_id
  #     debug_output = bosh_runner.run("task #{task_id} --debug", failure_expected: true)
  #     expect(debug_output).to include('NATS client error: TLS Verification failed checking issuer based on CA')
  #   end
  # end
end
