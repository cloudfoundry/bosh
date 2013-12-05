require 'spec_helper'

describe Bhm::Plugins::Resurrector do
  before(:all) do
    Bhm.logger = Logging.logger(StringIO.new)
  end

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
    plugin.url.to_s.should == uri
  end

  context 'when the event machine reactor is not running' do
    it 'should not start' do
      plugin.run.should be(false)
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
        Bhm::Plugins::ResurrectorHelper::AlertTracker.should_receive(:new).and_return(@don)
      end

      it 'should be delivered' do
        @don.should_receive(:melting_down?).and_return(false)
        plugin.run

        request_url = "#{uri}/deployments/d/scan_and_fix"
        request_data = {
            head: {
                'Content-Type' => 'application/json',
                'authorization' => %w[user password]
            },
            body: '{"jobs":{"j":["i"]}}'
        }
        plugin.should_receive(:send_http_put_request).with(request_url, request_data)

        plugin.process(alert)
      end

      it 'does not deliver while melting down' do
        @don.should_receive(:melting_down?).and_return(true)
        plugin.run
        plugin.should_not_receive(:send_http_put_request)
        plugin.process(alert)
      end

      it 'should alert through EventProcessor while melting down' do
        @don.should_receive(:melting_down?).and_return(true)
        Time.stub(:now).and_return(12345)
        alert_option = {
            :severity => 1,
            :source => "HM plugin resurrector",
            :title => "We are in meltdown.",
            :created_at => 12345
        }
        event_processor.should_receive(:process).with(:alert, alert_option)
        plugin.run
        plugin.process(alert)
      end
    end

    context 'alerts without deployment, job and index' do
      let(:alert) { Bhm::Events::Base.create!(:alert, alert_payload) }

      it 'should not be delivered' do
        plugin.run

        plugin.should_not_receive(:send_http_put_request)

        plugin.process(alert)
      end
    end
  end
end
