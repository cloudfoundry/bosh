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

        expect(Async::HTTP::Internet).to receive(:put).and_wrap_original do |original_put, endpoint, body, headers|
          expect(endpoint.to_url.to_s).to eq('http://some-uri/some-path')
          expect(endpoint.endpoint).to be_a(Async::HTTP::Proxy)
          expect(endpoint.endpoint.client.endpoint.to_url.to_s).to eq('https://proxy.local:1234/')
          original_put.call(endpoint, body, headers)
        end

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

  describe '#send_http_get_request_synchronous' do
    let(:some_uri) { URI.parse('https://send-http-get-request.example.com/some-path') }
    let(:some_uri_response) { 'hello send_http_get_request' }

    let(:custom_headers) { {} }

    before do
      stub_request(:get, some_uri)
        .with { |request_signature|
          expect(request_signature.headers['Accept']).to eq('*/*')
          expect(request_signature.headers['User-Agent']).to match(/ruby/i)

          custom_headers.each do |h, v|
            expect(request_signature.headers[h]).to eq(v)
          end
        }
        .to_return(status: 200, body: some_uri_response)

      allow(logger).to receive(:debug)
    end

    describe 'configuring the http client' do
      let(:http_client) { Net::HTTP.new(some_uri.host, some_uri.port) }
      let(:proxy_uri) { nil }

      before do
        allow(ENV).to receive(:[]).and_wrap_original do |method, arg|
          if proxy_uri && arg == "#{some_uri.scheme}_proxy"
            proxy_uri.to_s
          else
            method.call(arg)
          end
        end

        allow(Net::HTTP).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:use_ssl=).and_call_original
        allow(http_client).to receive(:verify_mode=).and_call_original
        allow(http_client).to receive(:proxy_address=)
        allow(http_client).to receive(:proxy_port=)
        allow(http_client).to receive(:proxy_user=)
        allow(http_client).to receive(:proxy_pass=)
      end

      it 'configures the SSL Verify mode' do
        send_http_get_request_synchronous(some_uri)

        expect(Net::HTTP).to have_received(:new).with(some_uri.host, some_uri.port)
        expect(http_client).to have_received(:use_ssl=).with(true)
        expect(http_client).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
      end

      context 'when URI#find_proxy is nil' do
        it 'does not set any proxy value on the client' do
          send_http_get_request_synchronous(some_uri)

          expect(http_client).to_not have_received(:proxy_address=)
          expect(http_client).to_not have_received(:proxy_port=)
          expect(http_client).to_not have_received(:proxy_user=)
          expect(http_client).to_not have_received(:proxy_pass=)
        end
      end

      context 'when URI#find_proxy is NOT nil' do
        let(:proxy_uri) { URI.parse('https://proxy-user:proxy-pass@proxy.example.com:8080/proxy-path') }

        it 'sets proxy values on the client' do
          send_http_get_request_synchronous(some_uri)

          expect(http_client).to have_received(:proxy_address=).with(proxy_uri.host)
          expect(http_client).to have_received(:proxy_port=).with(proxy_uri.port)
          expect(http_client).to have_received(:proxy_user=).with(proxy_uri.user)
          expect(http_client).to have_received(:proxy_pass=).with(proxy_uri.password)
        end
      end
    end

    context 'making the request' do
      context 'when headers are NOT specified' do
        it 'sends a get request' do
          body, status = send_http_get_request_synchronous(some_uri)

          expect(status).to eq(200)
          expect(body).to eq(some_uri_response)
        end

        it 'logs the request' do
          send_http_get_request_synchronous(some_uri)

          expect(logger).to have_received(:debug).with("Sending GET request to #{some_uri}")
        end
      end

      context 'when headers are specified' do
        let(:custom_headers) do
          {
            'Authorization' => 'FAKE_AUTH_HEADER',
            'Content-Type' => 'application/json',
          }
        end

        it 'sends a get request with custom headers' do
          body, status = send_http_get_request_synchronous(some_uri, custom_headers)

          expect(status).to eq(200)
          expect(body).to eq(some_uri_response)
        end

        it 'logs the request' do
          send_http_get_request_synchronous(some_uri, custom_headers)

          expect(logger).to have_received(:debug).with("Sending GET request to #{some_uri}")
        end
      end
    end
  end

  describe '#send_http_post_request_synchronous_with_tls_verify_peer' do
    let(:some_uri) { URI.parse('https://send-http-post-sync-request.example.com/some-path') }
    let(:some_uri_response) { 'hello send_http_post_sync_request' }
    let(:request) do
      { body: 'send_http_post_sync_request request body', proxy: nil }
    end

    before do
      stub_request(:post, some_uri)
        .with(body: { 'send_http_post_sync_request request body' => nil })
        .to_return(status: 200, body: some_uri_response)
    end

    describe 'configuring the http client' do
      let(:http_client) { Net::HTTP.new(some_uri.host, some_uri.port) }
      let(:proxy_uri) { nil }

      before do
        allow(ENV).to receive(:[]).and_wrap_original do |method, arg|
          if proxy_uri && arg == "#{some_uri.scheme}_proxy"
            proxy_uri.to_s
          else
            method.call(arg)
          end
        end

        allow(Net::HTTP).to receive(:new).and_return(http_client)
        allow(http_client).to receive(:use_ssl=).and_call_original
        allow(http_client).to receive(:verify_mode=).and_call_original
        allow(http_client).to receive(:proxy_address=)
        allow(http_client).to receive(:proxy_port=)
        allow(http_client).to receive(:proxy_user=)
        allow(http_client).to receive(:proxy_pass=)
      end

      it 'configures the SSL Verify mode' do
        send_http_post_request_synchronous_with_tls_verify_peer(some_uri, request)

        expect(Net::HTTP).to have_received(:new).with(some_uri.host, some_uri.port)
        expect(http_client).to have_received(:use_ssl=).with(true)
        expect(http_client).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
      end

      context 'when URI#find_proxy is nil' do
        it 'does not set any proxy value on the client' do
          send_http_post_request_synchronous_with_tls_verify_peer(some_uri, request)

          expect(http_client).to_not have_received(:proxy_address=)
          expect(http_client).to_not have_received(:proxy_port=)
          expect(http_client).to_not have_received(:proxy_user=)
          expect(http_client).to_not have_received(:proxy_pass=)
        end
      end

      context 'when URI#find_proxy is NOT nil' do
        let(:proxy_uri) { URI.parse('https://proxy-user:proxy-pass@proxy.example.com:8080/proxy-path') }

        it 'sets proxy values on the client' do
          send_http_post_request_synchronous_with_tls_verify_peer(some_uri, request)

          expect(http_client).to have_received(:proxy_address=).with(proxy_uri.host)
          expect(http_client).to have_received(:proxy_port=).with(proxy_uri.port)
          expect(http_client).to have_received(:proxy_user=).with(proxy_uri.user)
          expect(http_client).to have_received(:proxy_pass=).with(proxy_uri.password)
        end
      end
    end

    context 'making the request' do
      it 'sends a get request' do
        body, status = send_http_post_request_synchronous_with_tls_verify_peer(some_uri, request)

        expect(status).to eq(200)
        expect(body).to eq(some_uri_response)
      end
    end
  end
end
