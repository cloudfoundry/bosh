require_relative '../../../../spec_helper'

include Bosh::Monitor::Plugins::HttpRequestHelper

describe Bosh::Monitor::Plugins::HttpRequestHelper do
  before do
    Bhm.logger = logger
  end

  describe '#send_http_put_request' do
    let(:http_request) { instance_double(EM::HttpRequest) }
    let(:http_response) { instance_double(EM::Completion) }

    it 'sends a put request' do
      expect(EM::HttpRequest).to receive(:new).with('some-uri').and_return(http_request)

      expect(http_request).to receive(:send).with(:put, 'some-request').and_return(http_response)
      expect(http_response).to receive(:callback)
      expect(http_response).to receive(:errback)
      expect(logger).not_to receive(:error)

      send_http_put_request('some-uri', 'some-request')
    end
  end
  describe '#use_proxy?' do
    no_proxy_no_match = 'one.three.four,two.three.four,three.two.three.four,*.One.three.four,.one.Three.four'
    no_proxy_no_match_ip = '192.168.0.1,22.24.26.28'
    no_proxy_match_domain = 'one.two.three.one,one.two.three.four'
    no_proxy_match_wildcard_star = 'one.two.three.one,*.two.three.Four,*.threE.three.four'
    no_proxy_match_wildcard_dot = 'one.two.three.one,.two.three.four'
    no_proxy_match_ip = '192.168.0.2,22.24.26.28'

    it 'matches wildcards' do
      expect(use_proxy?('https://one.two.three.four/some/path?with=query', no_proxy_no_match)).to eq true
      expect(use_proxy?('http://one.two.three.four/some/path?with=query', no_proxy_no_match)).to eq true
      expect(use_proxy?('one.two.three.four/some/path?with=query', no_proxy_no_match)).to eq true
      expect(use_proxy?('https://one.two.three.four/some/path?with=query', no_proxy_match_wildcard_star)).to eq false
      expect(use_proxy?('https://one.two.three.four/some/path?with=query', no_proxy_match_wildcard_dot)).to eq false
    end

    it 'matches IPs' do
      expect(use_proxy?('https://one.two.three.four/some/path?with=query', no_proxy_no_match_ip)).to eq true
      expect(use_proxy?('tcp://192.168.0.2/some/path?with=query', no_proxy_no_match_ip)).to eq true
      expect(use_proxy?('https://192.168.0.2/some/path?with=query', no_proxy_match_ip)).to eq false
    end

    it 'matches domain_names' do
      expect(use_proxy?('https://one.two.three.four/some/path?with=query', no_proxy_match_domain)).to eq false
      expect(use_proxy?('https://one.two.three.Four/some/path?with=query', no_proxy_match_domain)).to eq false
    end
  end
  describe '#send_http_post_request' do
    let(:http_request) { instance_double(EM::HttpRequest) }
    let(:http_response) { instance_double(EM::Completion) }

    it 'sends a post request' do
      expect(EM::HttpRequest).to receive(:new).with('some-uri').and_return(http_request)

      expect(http_request).to receive(:send).with(:post, 'some-request').and_return(http_response)
      expect(http_response).to receive(:callback)
      expect(http_response).to receive(:errback)
      expect(logger).not_to receive(:error)

      send_http_post_request('some-uri', 'some-request')
    end
  end

  describe '#send_http_get_request' do
    it 'sends a get request' do
      expect(logger).to receive(:debug).with('Sending GET request to some-uri')

      ssl_config = double('HTTPClient::SSLConfig')

      httpclient = instance_double(HTTPClient)
      expect(HTTPClient).to receive(:new).and_return(httpclient)
      expect(httpclient).to receive(:ssl_config).and_return(ssl_config)
      expect(ssl_config).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
      expect(httpclient).to receive(:get).with('some-uri')
      send_http_get_request('some-uri')
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
      expect(httpclient).to receive(:post).with('some-uri', 'some-request-body')

      send_http_post_sync_request('some-uri', request)
    end
  end
end
