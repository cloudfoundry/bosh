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
      let(:mock_client) { double(Bosh::Director::ConfigServer::Client) }

      before do
        allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
      end

      it 'returns an instance of ConfigServer::Client' do
        expect(Bosh::Director::ConfigServer::HTTPClient).to receive(:new).and_return(mock_http_client)
        expect(Bosh::Director::ConfigServer::Client).to receive(:new).with(mock_http_client, anything).and_return(mock_client)
        expect(Bosh::Director::ConfigServer::DummyClient).to_not receive(:new)
        expect(subject.create_client).to eq(mock_client)
      end
    end

    context 'when config server is enabled' do
      let(:mock_dummy_client) { double(Bosh::Director::ConfigServer::DummyClient) }

      before do
        allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
      end

      it 'returns an instance of ConfigServer::Client' do
        expect(Bosh::Director::ConfigServer::HTTPClient).to_not receive(:new)
        expect(Bosh::Director::ConfigServer::Client).to_not receive(:new)
        expect(Bosh::Director::ConfigServer::DummyClient).to receive(:new).and_return(mock_dummy_client)
        expect(subject.create_client).to eq(mock_dummy_client)
      end
    end
  end
end