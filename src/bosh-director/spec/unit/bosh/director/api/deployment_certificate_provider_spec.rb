require 'spec_helper'

module Bosh::Director::Api
  describe DeploymentCertificateProvider do
    subject { described_class.new }
    let(:mock_config_server) { instance_double(Bosh::Director::ConfigServer::ConfigServerClient) }
    let(:variables) {}
    let(:deployment) { instance_double(Bosh::Director::Models::Deployment) }
    let(:certificate_value) do
      {
        'certificate' => '',
        'ca' => '',
        'private_key' => '',
      }
    end
    let(:other_value) { 'some password' }

    let(:variables) do
      [
        Bosh::Director::Models::Variable.new(variable_name: 'var1', variable_id: '1'),
        Bosh::Director::Models::Variable.new(variable_name: 'var2', variable_id: '2'),
      ]
    end

    before(:each) do
      allow(deployment).to receive(:last_successful_variable_set)
      allow(Bosh::Director::ConfigServer::ClientFactory).to receive(:create_default_client).and_return(mock_config_server)
      allow(Bosh::Director::Models::Variable).to receive(:where).and_return(variables)
    end

    context 'when there are certificate variables' do
      let(:expire_time) { Time.now.utc + 10.days }
      let(:mock_x509) { instance_double(OpenSSL::X509::Certificate) }

      before(:each) do
        allow(OpenSSL::X509::Certificate).to receive(:new).and_return(mock_x509)
        allow(mock_x509).to receive(:not_after).and_return(expire_time)

        allow(mock_config_server).to receive(:get_variable_value_by_id).with('var1', '1').and_return(certificate_value)
        allow(mock_config_server).to receive(:get_variable_value_by_id).with('var2', '2').and_return(other_value)
      end

      it 'calculates expiry dates' do
        list = subject.list_certificates_with_expiry(deployment)
        expect(list.count).to eq(1)
        expect(list.first['expiry_date']).to eq(expire_time.utc.iso8601)
        expect(list.first['name']).to eq('var1')
        expect(list.first['id']).to eq('1')
        expect(list.first['days_left']).to eq(9)
      end
    end

    context 'when there are no certificate variables' do
      before(:each) do
        allow(mock_config_server).to receive(:get_variable_value_by_id).with('var1', '1').and_return(other_value)
        allow(mock_config_server).to receive(:get_variable_value_by_id).with('var2', '2').and_return(other_value)
      end

      it 'should return an empty list' do
        list = subject.list_certificates_with_expiry(deployment)
        expect(list.count).to eq(0)
      end
    end

    context 'when there an invalid certificate' do
      let(:variables) do
        [Bosh::Director::Models::Variable.new(variable_name: 'config', variable_id: '1')]
      end

      before(:each) do
        allow(mock_config_server).to receive(:get_variable_value_by_id).with(anything, '1')
                                                                       .and_return('certificate' => other_value)
      end

      it 'does not cause error' do
        expect { subject.list_certificates_with_expiry(deployment) }.to_not raise_exception
      end
    end
  end
end
