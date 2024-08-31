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

      body, status = task.wait

      expect(WebMock).to have_requested(:put, 'http://some-uri/some-path').with(body: 'some-request')
      expect(body).to eq('response')
      expect(status).to eq(200)
    end

    context 'when passed a proxy URI' do
      it 'sends a put request' do
        stub_request(:put, 'http://some-uri/some-path').with(body: 'some-request').to_return(body: 'response', status: 200)

        task = reactor.async do
          send_http_put_request('http://some-uri/some-path', { body: 'some-request', proxy: 'https://proxy.local:1234' })
        end

        body, status = task.wait

        expect(WebMock).to have_requested(:put, 'http://some-uri/some-path').with(body: 'some-request')
        expect(body).to eq('response')
        expect(status).to eq(200)
      end
    end
  end

  describe '#send_http_post_request' do
    it 'sends a post request' do
      stub_request(:post, 'http://some-uri/some-path').with(body: 'some-request').to_return(body: 'response', status: 200)

      task = reactor.async do
        send_http_post_request('http://some-uri/some-path', { body: 'some-request' })
      end

      body, status = task.wait

      expect(WebMock).to have_requested(:post, 'http://some-uri/some-path').with(body: 'some-request')
      expect(body).to eq('response')
      expect(status).to eq(200)
    end
  end

  describe '#send_http_get_request' do
    let(:some_uri) { 'https://send-http-get-request.example.com/some-path' }
    let(:some_uri_response) { 'hello send_http_get_request' }

    describe 'configuring the http client' do
      let(:ssl_config) { double(HTTPClient::SSLConfig) }
      let(:http_client) { instance_double(HTTPClient) }
      let(:proxy_uri) { nil }

      before do
        allow(HTTPClient).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:ssl_config).and_return(ssl_config)
        allow(http_client).to receive(:proxy=)

        parsed_uri = instance_double(URI::Generic)
        allow(parsed_uri).to receive(:find_proxy).and_return(proxy_uri)
        allow(URI).to receive(:parse).with(some_uri.to_s).and_return(parsed_uri)

        allow(ssl_config).to receive(:verify_mode=)
        allow(http_client).to receive(:get)
      end

      it 'configures the SSL Verify mode' do
        send_http_get_request(some_uri)

        expect(http_client).to have_received(:get).with(some_uri)
        expect(ssl_config).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
      end

      context 'when URI#finx_proxy is nil' do
        it 'does not set any proxy value on the client' do
          send_http_get_request(some_uri)

          expect(http_client).to_not have_received(:proxy=)
        end
      end

      context 'when URI#finx_proxy is NOT nil' do
        let(:proxy_uri) { 'https://proxy-user:proxy-pass@proxy.example.com:8080/proxy-path' }

        it 'sets proxy values on the client' do
          send_http_get_request(some_uri)

          expect(http_client).to have_received(:proxy=).with(proxy_uri)
        end
      end
    end

    context 'making the request' do
      before do
        stub_request(:get, some_uri)
          .to_return(status: 200, body: some_uri_response)

        allow(logger).to receive(:debug)
      end

      it 'sends a get request' do
        response = send_http_get_request(some_uri)

        expect(response.status_code).to eq(200)
        expect(response.body).to eq(some_uri_response)
      end

      it 'logs the request' do
        send_http_get_request(some_uri)

        expect(logger).to have_received(:debug).with("Sending GET request to #{some_uri}")
      end
    end
  end

  describe '#send_http_post_sync_request' do
    let(:some_uri) { 'https://send-http-post-sync-request.example.com/some-path' }
    let(:some_uri_response) { 'hello send_http_post_sync_request' }
    let(:request) do
      { body: 'send_http_post_sync_request request body', proxy: nil }
    end

    describe 'configuring the http client' do
      let(:ssl_config) { double(HTTPClient::SSLConfig) }
      let(:http_client) { instance_double(HTTPClient) }
      let(:proxy_uri) { nil }

      before do
        allow(HTTPClient).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:ssl_config).and_return(ssl_config)
        allow(http_client).to receive(:proxy=)

        parsed_uri = instance_double(URI::Generic)
        allow(parsed_uri).to receive(:find_proxy).and_return(proxy_uri)
        allow(URI).to receive(:parse).with(some_uri.to_s).and_return(parsed_uri)

        allow(ssl_config).to receive(:verify_mode=)
        allow(http_client).to receive(:post)
      end

      it 'configures the SSL Verify mode' do
        send_http_post_sync_request(some_uri, request)

        expect(http_client).to have_received(:post).with(some_uri, request[:body])
        expect(ssl_config).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
      end

      context 'when URI#finx_proxy is nil' do
        it 'does not set any proxy value on the client' do
          send_http_post_sync_request(some_uri, request)

          expect(http_client).to_not have_received(:proxy=)
        end
      end

      context 'when URI#finx_proxy is nil' do
        it 'does not set any proxy value on the client' do
          send_http_post_sync_request(some_uri, request)

          expect(http_client).to_not have_received(:proxy=)
        end
      end

      context 'when URI#finx_proxy is NOT nil' do
        let(:proxy_uri) { 'https://proxy-user:proxy-pass@proxy.example.com:8080/proxy-path' }

        it 'sets proxy values on the client' do
          send_http_post_sync_request(some_uri, request)

          expect(http_client).to have_received(:proxy=).with(proxy_uri)
        end
      end
    end

    context 'making the request' do
      before do
        stub_request(:post, some_uri)
          .with(body: { 'send_http_post_sync_request request body' => nil })
          .to_return(status: 200, body: some_uri_response)
      end

      it 'sends a get request' do
        response = send_http_post_sync_request(some_uri, request)

        expect(response.status_code).to eq(200)
        expect(response.body).to eq(some_uri_response)
      end
    end
  end
end
