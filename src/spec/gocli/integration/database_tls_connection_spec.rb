require_relative '../spec_helper'

describe 'when director try to connect database using TLS', type: :integration, skip_for_db_tls_ci: true do
  # db_tls: :disabled is just a filter flag to skip this test if TLS is enabled on database

  let(:manifest) { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }

  context "when database doesn't support TLS" do
    xit 'fails during migration' do
      error = nil
      begin
        reset_sandbox(nil, tls_enabled: true)
      rescue StandardError => err
        error = err
      end

      ssl_error_list = ['Mysql2::Error: SSL connection error', 'PG::ConnectionBad: server does not support SSL']

      expect(error).not_to be_nil

      error_found = ssl_error_list.any? do |ssl_error_message|
        error.message.include? ssl_error_message
      end

      expect(error_found).to be_truthy, "Did not error for SSL reasons, error: #{error}"
    end
  end
end
