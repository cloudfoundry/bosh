require 'spec_helper'

module Bosh::Director::ConfigServer

  describe 'compatibility of Enabled and Disabled versions of ConfigServer HTTP Clients' do
    it 'ensures only same named methods are supported' do
      expect(ConfigServerEnabledHTTPClient.instance_methods - ConfigServerDisabledHTTPClient.instance_methods).to be_empty
      expect(ConfigServerDisabledHTTPClient.instance_methods - ConfigServerEnabledHTTPClient.instance_methods).to be_empty
    end

    it 'ensures same named methods support same number of arguments' do
      ConfigServerEnabledHTTPClient.instance_methods.each do |method_name|
        expect(ConfigServerEnabledHTTPClient.instance_method(method_name).arity).to eq(ConfigServerDisabledHTTPClient.instance_method(method_name).arity)
      end
    end
  end

  describe ConfigServerEnabledHTTPClient do
    subject { Bosh::Director::ConfigServer::ConfigServerEnabledHTTPClient.new(http_client) }
    let(:http_client) { instance_double('Net::HTTP') }
    let(:config_server_hash) do
      { 'url' => 'http://127.0.0.1:8080' }
    end

    before do
      allow(Bosh::Director::Config).to receive(:config_server).and_return(config_server_hash)
    end

    describe '#get_by_id' do
      it 'makes a GET call using "id" resource' do
        expect(http_client).to receive(:get).with('/v1/data/boo')
        subject.get_by_id('boo')
      end
    end

    describe '#get' do
      it "makes a GET call using 'name' query parameter for variable name and 'current' query parameter set to true" do
        expect(http_client).to receive(:get).with('/v1/data?name=smurf_key&current=true')
        subject.get('smurf_key')
      end
    end

    describe '#post' do
      let(:request_body) do
        { 'stuff' => 'hello' }
      end

      it 'makes a POST call to config server @ /v1/data/{key} with body and returns response' do
        expect(http_client).to receive(:post).with(anything, JSON.dump(request_body), {'Content-Type' => 'application/json'})
        subject.post(request_body)
      end
    end
  end

  describe ConfigServerDisabledHTTPClient do
    subject { described_class.new }

    describe '#get_by_id' do
      it 'raises an error' do
        expect {
          subject.get_by_id(1)
        }.to raise_error(Bosh::Director::ConfigServerDisabledError, "Failed to fetch variable with id '1' from config server: Director is not configured with a config server")
      end
    end

    describe '#get' do
      it 'raises an error' do
        expect {
          subject.get('name')
        }.to raise_error(Bosh::Director::ConfigServerDisabledError, "Failed to fetch variable 'name' from config server: Director is not configured with a config server")
      end
    end

    describe '#post' do
      it 'raises an error' do
        expect {
          subject.post({'name' => '/var_name', 'type' => 'password'})
        }.to raise_error(Bosh::Director::ConfigServerDisabledError, "Failed to generate variable '/var_name' from config server: Director is not configured with a config server")
      end
    end
  end
end
