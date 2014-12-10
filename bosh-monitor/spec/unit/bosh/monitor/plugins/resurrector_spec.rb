require 'spec_helper'

describe Bhm::Plugins::Resurrector do
  let(:options) {
    {
        'director' => {
            'endpoint' => 'http://foo.bar.com:25555',
            'user' => 'user',
            'password' => 'password'
        }
    }
  }
  let(:plugin) { described_class.new(options) }
  let(:uri) { 'http://foo.bar.com:25555' }

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
      let(:alert) { Bhm::Events::Base.create!(:alert, alert_payload(deployment: 'd', job: 'j', index: 'i')) }
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

      it 'does not deliver while melting down' do
        expect(@don).to receive(:melting_down?).and_return(true)
        plugin.run
        expect(plugin).not_to receive(:send_http_put_request)
        plugin.process(alert)
      end

      it 'should alert through EventProcessor while melting down' do
        expect(@don).to receive(:melting_down?).and_return(true)
        allow(Time).to receive(:now).and_return(12345)
        alert_option = {
            :severity => 1,
            :source => "HM plugin resurrector",
            :title => "We are in meltdown.",
            :created_at => 12345
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
  end
end
