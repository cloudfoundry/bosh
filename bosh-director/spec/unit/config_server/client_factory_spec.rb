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
      let(:mock_interpolator) { double(Bosh::Director::ConfigServer::Interpolator) }

      before do
        allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(true)
      end

      it 'returns an instance of ConfigServer::Interpolator' do
        expect(Bosh::Director::ConfigServer::HTTPClient).to receive(:new).and_return(mock_http_client)
        expect(Bosh::Director::ConfigServer::Interpolator).to receive(:new).with(mock_http_client, anything).and_return(mock_interpolator)
        expect(Bosh::Director::ConfigServer::DummyInterpolator).to_not receive(:new)
        expect(subject.create_client).to eq(mock_interpolator)
      end
    end

    context 'when config server is enabled' do
      let(:mock_dummy_interpolator) { double(Bosh::Director::ConfigServer::DummyInterpolator) }

      before do
        allow(Bosh::Director::Config).to receive(:config_server_enabled).and_return(false)
      end

      it 'returns an instance of ConfigServer::Interpolator' do
        expect(Bosh::Director::ConfigServer::HTTPClient).to_not receive(:new)
        expect(Bosh::Director::ConfigServer::Interpolator).to_not receive(:new)
        expect(Bosh::Director::ConfigServer::DummyInterpolator).to receive(:new).and_return(mock_dummy_interpolator)
        expect(subject.create_client).to eq(mock_dummy_interpolator)
      end
    end
  end
end