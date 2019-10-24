module Bosh::Director::Api
  class DeploymentCertificateProvider
    def initialize
      @config_server = Bosh::Director::ConfigServer::ClientFactory.create_default_client
    end

    def list_certificates_with_expiry(deployment)
      results = []

      variable_set = deployment.last_successful_variable_set
      Bosh::Director::Models::Variable.where(variable_set: variable_set).each do |variable|
        value = @config_server.get_variable_value_by_id(variable.variable_name, variable.variable_id)
        next unless value.is_a?(Hash) && value.key?('certificate')

        begin
          cert = OpenSSL::X509::Certificate.new(value['certificate'])
        rescue OpenSSL::X509::CertificateError => _
          next
        end

        results << {
          'name' => variable.variable_name,
          'id' => variable.variable_id,
          'expiry_date' => expiry(cert),
          'days_left' => days_left(cert),
        }
      end
      results
    end

    private

    def days_left(cert)
      ((cert.not_after.utc - Time.now.utc) / 60 / 60 / 24).floor
    end

    def expiry(cert)
      cert.not_after.utc.iso8601
    end
  end
end
