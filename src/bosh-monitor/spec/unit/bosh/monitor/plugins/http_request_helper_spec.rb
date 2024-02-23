require 'spec_helper'

describe Bosh::Monitor::Plugins::HttpRequestHelper do
  include Bosh::Monitor::Plugins::HttpRequestHelper
  include_context Async::RSpec::Reactor

  before do
    Bhm.logger = logger
  end

  describe '#send_http_put_request' do
    it 'sends a put request' do
      stub_request(:put, 'http://some-uri/some-path').with(body: 'some-request').to_return(body: 'response', status: 200)

      task = reactor.async do
        send_http_put_request('http://some-uri/some-path', { body: 'some-request' })
      end

      response = task.wait

      expect(WebMock).to have_requested(:put, 'http://some-uri/some-path').with(body: 'some-request')
      expect(response.read).to eq('response')
      expect(response.status).to eq(200)
    end

    context 'when passed a proxy URI' do
      it 'sends a put request' do
        stub_request(:put, 'http://some-uri/some-path').with(body: 'some-request').to_return(body: 'response', status: 200)

        task = reactor.async do
          send_http_put_request('http://some-uri/some-path', { body: 'some-request', proxy: 'https://proxy.local:1234' })
        end

        response = task.wait

        expect(WebMock).to have_requested(:put, 'http://some-uri/some-path').with(body: 'some-request')
        expect(response.read).to eq('response')
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#send_http_post_request' do
    it 'sends a post request' do
      stub_request(:post, 'http://some-uri/some-path').with(body: 'some-request').to_return(body: 'response', status: 200)

      task = reactor.async do
        send_http_post_request('http://some-uri/some-path', { body: 'some-request' })
      end

      response = task.wait

      expect(WebMock).to have_requested(:post, 'http://some-uri/some-path').with(body: 'some-request')
      expect(response.read).to eq('response')
      expect(response.status).to eq(200)
    end
  end

  describe '#send_http_get_request' do
    it 'sends a get request' do
      uri = 'http://some-uri'
      expect(logger).to receive(:debug).with("Sending GET request to #{uri}")

      ssl_config = double('HTTPClient::SSLConfig')

      httpclient = instance_double(HTTPClient)
      expect(HTTPClient).to receive(:new).and_return(httpclient)
      expect(httpclient).to receive(:ssl_config).and_return(ssl_config)
      expect(ssl_config).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
      expect(httpclient).to receive(:get).with(uri)
      send_http_get_request(uri)
    end
  end

  describe '#send_http_post_sync_request' do
    let(:request) do
      { body: 'some-request-body', proxy: nil }
    end

    it 'sends a sync post request' do
      ssl_config = double('HTTPClient::SSLConfig')
      httpclient = instance_double(HTTPClient)

      expect(HTTPClient).to receive(:new).and_return(httpclient)
      expect(httpclient).to receive(:ssl_config).and_return(ssl_config)
      expect(ssl_config).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
      expect(httpclient).to receive(:post).with('http://some-uri', 'some-request-body')

      send_http_post_sync_request('http://some-uri', request)
    end
  end
end
