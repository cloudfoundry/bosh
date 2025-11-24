require 'spec_helper'

describe Bosh::Monitor::Plugins::Riemann do
  before do
    options = {
      'host' => '127.0.0.1',
      'port' => '5555',
    }

    @client = double('Riemann Client')
    @plugin = Bosh::Monitor::Plugins::Riemann.new(options)
    allow(@plugin).to receive_messages(client: @client)
  end

  it 'validates options' do
    expect(Bosh::Monitor::Plugins::Riemann.new('host' => '127.0.0.1', 'port' => '5555').validate_options).to be(true)
    expect(Bosh::Monitor::Plugins::Riemann.new('host' => '127.0.0.1').validate_options).to be(false)
    expect(Bosh::Monitor::Plugins::Riemann.new('port' => '5555').validate_options).to be(false)
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

    Sync do
      expect(@plugin.run).to be(true)

      allow(@client).to receive(:<<)
      expect(@client).to receive(:<<).with(alert_request)
      expect(@client).to receive(:<<).with(heartbeat_request)

      @plugin.process(alert)
      @plugin.process(heartbeat)
    end
  end

  it 'includes process_length in heartbeat events sent to Riemann' do
    heartbeat = make_heartbeat(process_length: 42)

    Sync do
      expect(@plugin.run).to be(true)

      allow(@client).to receive(:<<)
      
      # Verify that process_length is attached to events
      expect(@client).to receive(:<<).at_least(1).times do |event|
        expect(event[:service]).to eq('bosh.hm')
        expect(event[:process_length]).to eq(42)
        expect(event[:name]).not_to be_nil
        expect(event[:metric]).not_to be_nil
      end

      @plugin.process(heartbeat)
    end
  end

  it 'omits process_length when not present in heartbeat' do
    heartbeat = make_heartbeat

    Sync do
      expect(@plugin.run).to be(true)

      allow(@client).to receive(:<<)
      
      # Verify that process_length is NOT attached to events
      expect(@client).to receive(:<<).at_least(1).times do |event|
        expect(event[:service]).to eq('bosh.hm')
        expect(event).not_to have_key(:process_length)
        expect(event[:name]).not_to be_nil
        expect(event[:metric]).not_to be_nil
      end

      @plugin.process(heartbeat)
    end
  end
end
