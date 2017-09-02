require 'spec_helper'

describe Bosh::Director::ConfigServer::ClientFactory do

  it 'has a static method to create itself' do
    factory = Bosh::Director::ConfigServer::ClientFactory.create(Bosh::Director::Config.logger)
    expect(factory.kind_of? Bosh::Director::ConfigServer::ClientFactory).to eq(true)
  end

  describe '#create_client' do
    subject(:client_factory) { Bosh::Director::ConfigServer::ClientFactory.create(Bosh::Director::Config.logger) }

    let(:mock_auth_http_client) { double(Bosh::Director::ConfigServer::AuthHTTPClient) }
    let(:mock_retryable_http_client) { double(Bosh::Director::ConfigServer::RetryableHTTPClient) }
    let(:mock_enabled_client) { double(Bosh::Director::ConfigServer::ConfigServerClient) }

    before do
      allow(Bosh::Director::Config).to receive(:name).and_return('my-director-name')
    end

    context 'when config server is enabled' do
      let(:mock_config_server_http_client) { double(Bosh::Director::ConfigServer::ConfigServerEnabledHTTPClient) }

      before do
        allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
      end

      it 'returns an instance of ConfigServer::ConfigServerClient' do
        expect(Bosh::Director::ConfigServer::AuthHTTPClient).to receive(:new).and_return(mock_auth_http_client)
        expect(Bosh::Director::ConfigServer::RetryableHTTPClient).to receive(:new).with(mock_auth_http_client).and_return(mock_retryable_http_client)
        expect(Bosh::Director::ConfigServer::ConfigServerEnabledHTTPClient).to receive(:new).with(mock_retryable_http_client).and_return(mock_config_server_http_client)
        expect(Bosh::Director::ConfigServer::ConfigServerClient).to receive(:new).with(mock_config_server_http_client, 'my-director-name', anything).and_return(mock_enabled_client)
        expect(subject.create_client).to eq(mock_enabled_client)
      end
    end

    context 'when config server is disabled' do
      let(:mock_config_server_disabled_http_client) { double(Bosh::Director::ConfigServer::ConfigServerDisabledHTTPClient) }

      before do
        allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
      end

      it 'returns an instance of ConfigServer::ConfigServerClient which uses the ConfigServerDisabledHTTPClient' do
        expect(Bosh::Director::ConfigServer::AuthHTTPClient).to_not receive(:new)
        expect(Bosh::Director::ConfigServer::RetryableHTTPClient).to_not receive(:new)
        expect(Bosh::Director::ConfigServer::ConfigServerEnabledHTTPClient).to_not receive(:new)

        expect(Bosh::Director::ConfigServer::ConfigServerDisabledHTTPClient).to receive(:new).and_return(mock_config_server_disabled_http_client)
        expect(Bosh::Director::ConfigServer::ConfigServerClient).to receive(:new).with(mock_config_server_disabled_http_client, 'my-director-name', anything).and_return(mock_enabled_client)
        expect(subject.create_client).to eq(mock_enabled_client)
      end
    end
  end
end
