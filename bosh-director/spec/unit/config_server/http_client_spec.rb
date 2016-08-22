require 'spec_helper'

describe Bosh::Director::ConfigServer::HTTPClient do
  class MockSuccessResponse < Net::HTTPSuccess
    attr_accessor :body

    def initialize
      super(nil, Net::HTTPOK, nil)
    end
  end

  class MockFailedResponse < Net::HTTPClientError
    def initialize
      super(nil, Net::HTTPNotFound, nil)
    end
  end

  let(:mock_config_store) do
    {
        'value' => {value: 123},
        'instance_val' => {value: 'test1'},
        'job_val' => {value: 'test2'},
        'env_val' => {value: 'test3'},
        'name_val' => {value: 'test4'}
    }
  end

  let(:config_server_hash) do
    {
        'url' => 'http://127.0.0.1:8080',
    }
  end

  let(:mock_http) { double('Net::HTTP') }

  before do
    expect(mock_http).to receive(:use_ssl=)
    expect(mock_http).to receive(:verify_mode=)
    allow(mock_http).to receive(:cert_store=)

    allow(Net::HTTP).to receive(:new) { mock_http }

    allow(Bosh::Director::Config).to receive(:config_server).and_return(config_server_hash)

    auth_provider_double = instance_double(Bosh::Director::UAAAuthProvider)
    allow(auth_provider_double).to receive(:auth_header).and_return('fake-auth-header')
    allow(Bosh::Director::UAAAuthProvider).to receive(:new).and_return(auth_provider_double)
  end

  describe '#initialize' do

    shared_examples 'cert_store' do
      store_double = nil

      before do
        store_double = instance_double(OpenSSL::X509::Store)
        allow(store_double).to receive(:set_default_paths)
        allow(OpenSSL::X509::Store).to receive(:new).and_return(store_double)
      end

      it 'uses default cert_store' do
        expect(mock_http).to receive(:cert_store=)
        expect(store_double).to receive(:set_default_paths)

        subject
      end
    end

    context 'ca_cert file does not exist' do
      before do
        config_server_hash['ca_cert_path'] = nil
      end

      it_behaves_like 'cert_store'
    end

    context 'ca_cert file exists and is empty' do
      before do
        config_server_hash['ca_cert_path'] = '/root/cert.crt'
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:read).and_return('')
      end

      it_behaves_like 'cert_store'
    end

    it 'should raise an error message when the certificate is invalid' do
      allow(mock_http).to receive(:get).and_raise(OpenSSL::SSL::SSLError)
      expect{ subject.get('anything') }.to raise_error(
                                       Bosh::Director::ConfigServerSSLError,
                                       'Config Server SSL error'
                                   )
    end
  end

  describe '#get' do
    context 'when successful' do
      let(:mock_response) do
        response = MockSuccessResponse.new
        response.body = 'some_response'
        response
      end

      it 'makes a GET call to config server @ /v1/data/{key} and returns response' do
        expect(mock_http).to receive(:get).with('/v1/data/smurf_key', {'Authorization' => 'fake-auth-header'}).and_return(mock_response)
        expect(subject.get('smurf_key')).to eq(mock_response)
      end
    end

    context 'when a OpenSSL::SSL::SSLError error is raised' do
      it 'it throws a Bosh::Director::ConfigServerSSLError error' do
        allow(mock_http).to receive(:get).with('/v1/data/smurf_key', {'Authorization' => 'fake-auth-header'}).and_raise(OpenSSL::SSL::SSLError)
        expect{subject.get('smurf_key')}.to raise_error(Bosh::Director::ConfigServerSSLError, 'Config Server SSL error')
      end
    end
  end

  describe '#get_value_for_key' do
    context 'when successful' do
      let(:value) { {'value'=> 'very_secret'} }
      let(:mock_response) do
        response = MockSuccessResponse.new
        response.body = value.to_json
        response
      end

      it 'makes a GET call to config server @ /v1/data/{key} and returns value' do
        expect(subject).to receive(:get).with('smurf_password').and_return(mock_response)
        expect(subject.get_value_for_key('smurf_password')).to eq('very_secret')
      end
    end

    context 'when it cannot find the key' do
      let(:mock_response) do
        response = MockFailedResponse.new
        response.body = 'some_bad_response'
        response
      end

      it 'raises a Bosh::Director::ConfigServerMissingKeys error' do
        allow(subject).to receive(:get).with('smurf_password').and_return(mock_response)
        expect{
          subject.get_value_for_key('smurf_password')
        }. to raise_error(
          Bosh::Director::ConfigServerMissingKeys,
          "Failed to find key 'smurf_password' in the config server"
        )
      end
    end
  end

  describe '#post' do
    let(:request_body) do
      {
        'stuff'=> 'hello'
      }
    end

    context 'when successful' do
      let(:mock_response) do
        response = MockSuccessResponse.new
        response.body = 'some_response'
        response
      end

      it 'makes a POST call to config server @ /v1/data/{key} with body and returns response' do
        expect(mock_http).to receive(:post).with('/v1/data/smurf_key', Yajl::Encoder.encode(request_body), {'Authorization' => 'fake-auth-header'}).and_return(mock_response)
        expect(subject.post('smurf_key', request_body)).to eq(mock_response)
      end
    end

    context 'when a OpenSSL::SSL::SSLError error is raised' do
      it 'it throws a Bosh::Director::ConfigServerSSLError error' do
        allow(mock_http).to receive(:post).with('/v1/data/smurf_key', Yajl::Encoder.encode(request_body), {'Authorization' => 'fake-auth-header'}).and_raise(OpenSSL::SSL::SSLError)
        expect{subject.post('smurf_key', request_body)}.to raise_error(Bosh::Director::ConfigServerSSLError, 'Config Server SSL error')
      end
    end
  end

  describe '#generate_password' do
    context 'when successful' do
      let(:request_body) do
        {
          'type' => 'password'
        }
      end

      it 'makes a call to post with key and body with type password and returns response' do
        expect(subject).to receive(:post).with('smurf_password', request_body).and_return(MockSuccessResponse.new)
        subject.generate_password('smurf_password')
      end
    end

    context 'when it cannot generate a password' do
      let(:request_body) do
        {
          'type' => 'password'
        }
      end

      let(:mock_response) do
        response = MockFailedResponse.new
        response.body = 'some_bad_response'
        response
      end

      it 'raises a Bosh::Director::ConfigServerPasswordGenerationError error' do
        allow(subject).to receive(:post).with('smurf_password', request_body).and_return(mock_response)
        expect{
          subject.generate_password('smurf_password')
        }. to raise_error(
          Bosh::Director::ConfigServerPasswordGenerationError,
          'Config Server failed to generate password'
        )
      end
    end
  end
end