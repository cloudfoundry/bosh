require 'spec_helper'
require 'rack/test'

describe Bosh::Director::ConfigServer::AuthHTTPClient do
  subject { Bosh::Director::ConfigServer::AuthHTTPClient.new }
  let(:http_client) { instance_double('Net::HTTP') }
  let(:config_server_hash) do
    { 'url' => 'http://127.0.0.1:8080' }
  end
  let(:uaa_auth_provider) { instance_double('Bosh::Director::ConfigServer::UAAAuthProvider') }
  let(:uaa_token) { instance_double('Bosh::Director::ConfigServer::UAAToken') }
  let(:successful_response) { Net::HTTPSuccess.new(nil, "200", nil) }
  let(:unauthorized_response) { Net::HTTPUnauthorized.new(nil, "401", nil) }

  before do
    allow(Net::HTTP).to receive(:new) { http_client }
    allow(Bosh::Director::Config).to receive(:config_server).and_return(config_server_hash)

    allow(uaa_auth_provider).to receive(:get_token).and_return(uaa_token)
    allow(Bosh::Director::ConfigServer::UAAAuthProvider).to receive(:new).and_return(uaa_auth_provider)
    allow(uaa_token).to receive(:auth_header).and_return('fake-auth-header')
  end

  describe '#initialize' do
    context 'ssl is setup' do
      shared_examples 'does not configure cert_store' do
        before do
          allow(http_client).to receive(:use_ssl=).with(true)
          allow(http_client).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
        end

        it 'does not set cert_store, falling back to default trust store' do
          expect(http_client).not_to receive(:cert_store=)
          expect(http_client).not_to receive(:ca_file=)
          expect(OpenSSL::X509::Store).not_to receive(:new)

          subject
        end
      end

      context 'ca_cert file does not exist' do
        before do
          config_server_hash['ca_cert_path'] = nil
        end

        it_behaves_like 'does not configure cert_store'
      end

      context 'ca_cert file exists and is empty' do
        before do
          config_server_hash['ca_cert_path'] = '/root/cert.crt'
          allow(File).to receive(:file?).with('/root/cert.crt').and_return(true)
          allow(File).to receive(:zero?).with('/root/cert.crt').and_return(true)
        end

        it_behaves_like 'does not configure cert_store'
      end
    end
  end

  describe '#get' do
    before do
      allow(http_client).to receive(:use_ssl=).with(true)
      allow(http_client).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
    end

    it 'should add "Authorization" header and call through to actual http client' do
      expected_headers = {
          'Key' => 'value',
          'Authorization' => 'fake-auth-header'
      }
      expect(http_client).to receive(:get).with("url", expected_headers, anything).and_return(successful_response)
      subject.get("url", {'Key' => 'value'})
    end

    context 'when `get` call fails with 401 unauthorized' do
      it 'throws an unauthorized error after retrying 2 times' do
        expect(http_client).to receive(:get).with('url', anything, anything).and_return(unauthorized_response).exactly(2).times
        expect { subject.get("url") }.to raise_error(Bosh::Director::UAAAuthorizationError)
      end

      it 'gets a new token' do
        allow(http_client).to receive(:get).with('url', anything, anything).and_return(unauthorized_response).exactly(2).times
        expect(uaa_auth_provider).to receive(:get_token).exactly(2).times # Once on initialize, once on retry
        expect { subject.get("url") }.to raise_error(Bosh::Director::UAAAuthorizationError)
      end
    end
  end

  describe '#post' do
    before do
      allow(http_client).to receive(:use_ssl=).with(true)
      allow(http_client).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
    end

    it 'should add "Authorization" header and call through to actual http client' do
      expected_headers = {
          'Key' => 'value',
          'Authorization' => 'fake-auth-header'
      }
      expect(http_client).to receive(:post).with("url", 'data!!', expected_headers, anything).and_return(successful_response)
      subject.post("url", 'data!!', {'Key' => 'value'})
    end

    context 'when `get` call fails with 401 unauthorized' do
      it 'throws an unauthorized error after retrying 2 times' do
        expect(http_client).to receive(:post).with('url', 'data!!', anything, anything).and_return(unauthorized_response).exactly(2).times
        expect { subject.post('url', 'data!!') }.to raise_error(Bosh::Director::UAAAuthorizationError)
      end

      it 'gets a new token' do
        allow(http_client).to receive(:post).with('url', 'data!!', anything, anything).and_return(unauthorized_response).exactly(2).times
        expect(uaa_auth_provider).to receive(:get_token).exactly(2).times # Once on initialize, once on retry
        expect { subject.post('url', 'data!!') }.to raise_error(Bosh::Director::UAAAuthorizationError)
      end
    end
  end
end
