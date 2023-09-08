require 'spec_helper'

describe Bhm::Plugins::Riemann do
  before do
    options = {
      'host' => '127.0.0.1',
      'port' => '5555',
    }

    @client = double('Riemann Client')
    @plugin = Bhm::Plugins::Riemann.new(options)
    allow(@plugin).to receive_messages(client: @client)
  end

  it 'validates options' do
    expect(Bhm::Plugins::Riemann.new('host' => '127.0.0.1', 'port' => '5555').validate_options).to be(true)
    expect(Bhm::Plugins::Riemann.new('host' => '127.0.0.1').validate_options).to be(false)
    expect(Bhm::Plugins::Riemann.new('port' => '5555').validate_options).to be(false)
  end

  it "doesn't start if event loop isn't running" do
    expect(@plugin.run).to be(false)
  end

  it 'sends events to Riemann' do
    alert = make_alert
    heartbeat = make_heartbeat

    alert_request = alert.to_hash.merge(
      service: 'bosh.hm',
      state: 'critical',
    )

    heartbeat_request = heartbeat.to_hash.merge(
      service: 'bosh.hm',
      name: 'system.load.1m',
      metric: 0.2,
    )
    heartbeat_request.delete :vitals

    EM.run do
      expect(@plugin.run).to be(true)

      allow(@client).to receive(:<<)
      expect(@client).to receive(:<<).with(alert_request)
      expect(@client).to receive(:<<).with(heartbeat_request)

      @plugin.process(alert)
      @plugin.process(heartbeat)
      EM.stop
    end
  end
end
