require 'spec_helper'

describe 'Bhm::Plugins::Resurrector' do
  include Support::UaaHelpers

  let(:options) {
    {
      'director' => {
        'endpoint' => 'http://foo.bar.com:25555',
        'user' => 'user',
        'password' => 'password',
        'client_id' => 'client-id',
        'client_secret' => 'client-secret',
        'ca_cert' => 'ca-cert'
      }
    }
  }
  let(:plugin) { Bhm::Plugins::Resurrector.new(options) }
  let(:uri) { 'http://foo.bar.com:25555' }
  let(:status_uri) { "#{uri}/info" }

  before do
    stub_request(:get, status_uri).
      to_return(status: 200, body: JSON.dump({'user_authentication' => user_authentication}))
  end

  let(:alert) { Bhm::Events::Base.create!(:alert, alert_payload(deployment: 'd', job: 'j', index: 'i')) }

  let(:user_authentication) { {} }

  it 'should construct a usable url' do
    expect(plugin.url.to_s).to eq(uri)
  end

  context 'when the event machine reactor is not running' do
    it 'should not start' do
      expect(plugin.run).to be(false)
    end
  end

  context 'when the event machine reactor is running' do
    around do |example|
      EM.run do
        example.call
        EM.stop
      end
    end

    context 'alerts with deployment, job and index' do
      let (:event_processor) { Bhm::EventProcessor.new }

      before do
        Bhm.event_processor = event_processor
        @don = double(Bhm::Plugins::ResurrectorHelper::AlertTracker, record: nil)
        expect(Bhm::Plugins::ResurrectorHelper::AlertTracker).to receive(:new).and_return(@don)
      end

      it 'should be delivered' do
        expect(@don).to receive(:melting_down?).and_return(false)
        plugin.run

        request_url = "#{uri}/deployments/d/scan_and_fix"
        request_data = {
            head: {
                'Content-Type' => 'application/json',
                'authorization' => %w[user password]
            },
            body: '{"jobs":{"j":["i"]}}'
        }
        expect(plugin).to receive(:send_http_put_request).with(request_url, request_data)

        plugin.process(alert)
      end

      context 'when auth provider is using UAA token issuer' do
        let(:user_authentication) do
          {
            'type' => 'uaa',
            'options' => {
              'url' => 'uaa-url',
            }
          }
        end

        before do
          token_issuer = instance_double(CF::UAA::TokenIssuer)
          allow(CF::UAA::TokenIssuer).to receive(:new).with(
            'uaa-url', 'client-id', 'client-secret', {ssl_ca_file: 'ca-cert'}
          ).and_return(token_issuer)
          allow(token_issuer).to receive(:client_credentials_grant).
            and_return(token)
        end
        let(:token) { uaa_token_info('fake-token-id') }

        it 'uses UAA token' do
          expect(@don).to receive(:melting_down?).and_return(false)
          plugin.run

          request_url = "#{uri}/deployments/d/scan_and_fix"
          request_data = {
            head: {
              'Content-Type' => 'application/json',
              'authorization' => token.auth_header
            },
            body: '{"jobs":{"j":["i"]}}'
          }
          expect(plugin).to receive(:send_http_put_request).with(request_url, request_data)

          plugin.process(alert)
        end
      end

      it 'does not deliver while melting down' do
        expect(@don).to receive(:melting_down?).and_return(true)
        plugin.run
        expect(plugin).not_to receive(:send_http_put_request)
        plugin.process(alert)
      end

      it 'should alert through EventProcessor while melting down' do
        expect(@don).to receive(:melting_down?).and_return(true)
        expected_time = Time.new
        allow(Time).to receive(:now).and_return(expected_time)
        alert_option = {
            :severity => 1,
            :source => "HM plugin resurrector",
            :title => "We are in meltdown.",
            :created_at => expected_time.to_i
        }
        expect(event_processor).to receive(:process).with(:alert, alert_option)
        plugin.run
        plugin.process(alert)
      end
    end

    context 'alerts without deployment, job and index' do
      let(:alert) { Bhm::Events::Base.create!(:alert, alert_payload) }

      it 'should not be delivered' do
        plugin.run

        expect(plugin).not_to receive(:send_http_put_request)

        plugin.process(alert)
      end
    end

    context 'when director status is not 200' do
      before do
        stub_request(:get, status_uri).to_return(status: 500, headers: {}, body: 'Failed')
      end

      it 'returns false' do
        plugin.run

        expect(plugin).not_to receive(:send_http_put_request)

        plugin.process(alert)
      end

      context 'when director starts responding' do
        before do
          stub_request(:get, status_uri).to_return({status: 500}, {status: 200, body: '{}'})
        end

        it 'starts sending alerts' do
          plugin.run

          expect(plugin).to receive(:send_http_put_request).once

          plugin.process(alert) # fails to send request
          plugin.process(alert)
        end
      end
    end
  end
end
