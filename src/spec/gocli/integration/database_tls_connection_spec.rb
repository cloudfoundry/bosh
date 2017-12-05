require_relative '../spec_helper'

describe 'When director try to connect database using TLS', type: :integration, skip_for_db_tls_ci: :true do
  # db_tls: :disabled is just a filter flag to skip this test if TLS is enabled on database

  let(:manifest)  { Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups }

  context "when database doesn't support TLS" do
    let(:ssl_error) {}

    it 'fails during migration' do
      begin
        reset_sandbox({}, {:tls_enabled => true})
      rescue => err
        ssl_error = err
      end

      puts ssl_error.inspect
      ssl_error_list = ["Mysql2::Error: SSL connection error", "PG::ConnectionBad: server does not support SSL"]

      error_found = false
      for err in ssl_error_list
        if ssl_error.message.include? (err)
          error_found = true
        end
      end

      expect(error_found).to be_truthy
    end
  end
end
