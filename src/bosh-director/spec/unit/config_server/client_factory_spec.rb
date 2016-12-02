require 'spec_helper'

describe Bosh::Director::ConfigServer::ClientFactory do

  it 'has a static method to create itself' do
    factory = Bosh::Director::ConfigServer::ClientFactory.create(Bosh::Director::Config.logger)
    expect(factory.kind_of? Bosh::Director::ConfigServer::ClientFactory).to eq(true)
  end

  describe '#create_client' do
    subject(:client_factory) { Bosh::Director::ConfigServer::ClientFactory.create(Bosh::Director::Config.logger) }

    context 'when config server is enabled' do
      let(:mock_http_client) { double(Bosh::Director::ConfigServer::HTTPClient) }
      let(:mock_enabled_client) { double(Bosh::Director::ConfigServer::EnabledClient) }

      before do
        allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
        allow(Bosh::Director::Config).to receive(:name).and_return('my-director-name')
      end

      it 'returns an instance of ConfigServer::EnabledClient' do
        expect(Bosh::Director::ConfigServer::HTTPClient).to receive(:new).and_return(mock_http_client)
        expect(Bosh::Director::ConfigServer::EnabledClient).to receive(:new).with(mock_http_client, 'my-director-name', anything).and_return(mock_enabled_client)
        expect(Bosh::Director::ConfigServer::DisabledClient).to_not receive(:new)
        expect(subject.create_client).to eq(mock_enabled_client)
      end

      context 'when there is a deployment context for the config server' do
        let(:mock_deployment_http_client) { double(Bosh::Director::ConfigServer::DeploymentHTTPClient) }
        let(:deployment_name) { "cool_deployment_bro" }
        let!(:deployment_model) { Bosh::Director::Models::Deployment.make(name: deployment_name) }

        it 'returns an instance of ConfigServer::EnabledClient with a deploymentHTTPclient' do
          expect(Bosh::Director::ConfigServer::HTTPClient).to receive(:new).and_return(mock_http_client)

          expect(Bosh::Director::ConfigServer::DeploymentHTTPClient).to receive(:new).
            with(deployment_name, mock_http_client).
            and_return(mock_deployment_http_client)

          expect(Bosh::Director::ConfigServer::EnabledClient).to receive(:new).
            with(mock_deployment_http_client, 'my-director-name', anything).
            and_return(mock_enabled_client)

          expect(subject.create_client(deployment_name)).to eq(mock_enabled_client)
        end

        context 'when the deployment name does not exist in the db' do
          let(:missing_deployment_name) { 'deployment_name_that_does_not_exist' }

          it 'throws an error' do
            expect{subject.create_client(missing_deployment_name)}.
              to raise_error(
                Bosh::Director::DeploymentNotFound,
                "no deployment found with name #{missing_deployment_name}"
              )
          end
        end
      end
    end

    context 'when config server is disabled' do
      let(:mock_disabled_client) { double(Bosh::Director::ConfigServer::DisabledClient) }

      before do
        allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
      end

      it 'returns an instance of ConfigServer::DisabledClient' do
        expect(Bosh::Director::ConfigServer::HTTPClient).to_not receive(:new)
        expect(Bosh::Director::ConfigServer::EnabledClient).to_not receive(:new)
        expect(Bosh::Director::ConfigServer::DisabledClient).to receive(:new).and_return(mock_disabled_client)
        expect(subject.create_client).to eq(mock_disabled_client)
      end
    end
  end
end
