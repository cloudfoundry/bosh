require 'spec_helper'

describe 'Bhm::Plugins::Resurrector' do
  include Support::UaaHelpers

  let(:options) do
    {
      'director' => {
        'endpoint' => 'http://foo.bar.com:25555',
        'user' => 'user',
        'password' => 'password',
        'client_id' => 'client-id',
        'client_secret' => 'client-secret',
        'ca_cert' => 'ca-cert',
      },
    }
  end
  let(:plugin) { Bhm::Plugins::EventLogger.new(options) }
  let(:uri) { 'http://foo.bar.com:25555' }
  let(:status_uri) { "#{uri}/info" }

  before do
    stub_request(:get, status_uri)
      .to_return(status: 200, body: JSON.dump('user_authentication' => user_authentication))
  end

  let(:time) { Time.new }
  let(:alert) { Bhm::Events::Base.create!(:alert, alert_payload(deployment: 'd', job: 'j', instance_id: 'i')) }
  let(:user_authentication) do
    {}
  end

  it 'should construct a usable url' do
    expect(plugin.url.to_s).to eq(uri)
  end

  context 'when the reactor is not running' do
    it 'should not start' do
      expect(plugin.run).to be(false)
    end
  end

  context 'when the reactor is running' do
    include_context Async::RSpec::Reactor

    context 'alert' do
      let(:event_processor) { Bhm::EventProcessor.new }

      it 'should be delivered' do
        plugin.run
        request_url = "#{uri}/events"
        request_data = {
          head: {
            'Content-Type' => 'application/json',
            'authorization' => "Basic #{Base64.encode64('user:password').strip}",
          },
          body: "{\"timestamp\":\"#{time.to_i}\",\"action\":\"create\",\"object_type\":\"alert\"," \
          '"object_name":"foo","deployment":"d","instance":"j/i",' \
          "\"context\":{\"message\":\"Alert. Alert @ #{time.utc}, severity 2: Alert\"}}",
        }
        expect(plugin).to receive(:send_http_post_request).with(request_url, request_data)
        plugin.process(alert)
      end

      context 'when auth provider is using UAA token issuer' do
        let(:user_authentication) do
          {
            'type' => 'uaa',
            'options' => {
              'url' => 'uaa-url',
            },
          }
        end

        before do
          token_issuer = instance_double(CF::UAA::TokenIssuer)
          allow(File).to receive(:exist?).with('ca-cert').and_return(true)
          allow(File).to receive(:read).with('ca-cert').and_return('test')
          allow(CF::UAA::TokenIssuer).to receive(:new).with(
            'uaa-url', 'client-id', 'client-secret', { ssl_ca_file: 'ca-cert' }
          ).and_return(token_issuer)
          allow(token_issuer).to receive(:client_credentials_grant)
            .and_return(token)
        end

        let(:token) { uaa_token_info('fake-token-id') }

        it 'uses UAA token' do
          plugin.run
          request_url = "#{uri}/events"
          request_data = {
            head: {
              'Content-Type' => 'application/json',
              'authorization' => token.auth_header,
            },
            body: "{\"timestamp\":\"#{time.to_i}\",\"action\":\"create\"," \
            '"object_type":"alert","object_name":"foo","deployment":"d",' \
            "\"instance\":\"j/i\",\"context\":{\"message\":\"Alert. Alert @ #{time.utc}, severity 2: Alert\"}}",
          }
          expect(plugin).to receive(:send_http_post_request).with(request_url, request_data)
          plugin.process(alert)
        end
      end
    end

    context 'when director status is not 200' do
      before do
        stub_request(:get, status_uri).to_return(status: 500, headers: {}, body: 'Failed')
      end

      it 'returns false' do
        plugin.run
        expect(plugin).not_to receive(:send_http_post_request)
        plugin.process(alert)
      end

      context 'when director starts responding' do
        before do
          stub_request(:get, status_uri).to_return({ status: 500 }, { status: 200, body: '{}' })
        end

        it 'starts sending alerts' do
          plugin.run
          expect(plugin).to receive(:send_http_post_request).once
          plugin.process(alert) # fails to send request
          plugin.process(alert)
        end
      end
    end
  end
end
