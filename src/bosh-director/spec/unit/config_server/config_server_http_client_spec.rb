require 'spec_helper'
require 'httpclient'

describe Bosh::Director::ConfigServer::ConfigServerHTTPClient do
  subject { Bosh::Director::ConfigServer::ConfigServerHTTPClient.new(http_client) }
  let(:http_client) { instance_double('Net::HTTP') }
  let(:config_server_hash) { {'url' => 'http://127.0.0.1:8080'} }

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
    let(:request_body) { {'stuff' => 'hello'} }

    it 'makes a POST call to config server @ /v1/data/{key} with body and returns response' do
      expect(http_client).to receive(:post).with(anything, Yajl::Encoder.encode(request_body), {'Content-Type' => 'application/json'})
      subject.post(request_body)
    end
  end
end