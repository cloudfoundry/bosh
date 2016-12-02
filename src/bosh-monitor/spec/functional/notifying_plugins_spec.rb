require 'spec_helper'
require 'timecop'

class FakeNATS
  def initialize(verbose=false)
    @subscribers = []
    @verbose = verbose
  end

  def subscribe(channel, &block)
    puts "Adding subscriber (#{channel}): #{block.inspect}" if @verbose
    @subscribers << block
  end

  def alert(message)
    reply = 'reply'
    subject = '1.2.3.not-an-agent'

    @subscribers.each do |subscriber|
      puts "Alerting subscriber: #{subscriber}" if @verbose
      subscriber.call(message, reply, subject)
    end
  end
end

describe 'notifying plugins' do
  WebMock.allow_net_connect!

  let(:runner) { Bosh::Monitor::Runner.new(spec_asset('dummy_plugin_config.yml')) }
  let(:hm_process) { MonitorProcess.new(runner) }

  before do
    free_port = find_free_tcp_port
    allow(Bhm).to receive(:http_port).and_return(free_port)
  end

  context 'when alert is received via nats' do
    it 'sends an alert to its plugins' do
      payload = {
        'id' => 'payload-id',
        'severity' => 3,
        'title' => 'payload-title',
        'summary' => 'payload-summary',
        'created_at' => Time.now.to_i,
      }

      called = false
      alert = nil
      EM.run do
        nats = FakeNATS.new
        allow(NATS).to receive(:connect).and_return(nats)
        runner.run
        wait_for_plugins
        nats.alert(JSON.dump(payload))
        EM.add_timer(2) { EM.stop }
        EM.add_periodic_timer(0.1) do
          alert = get_alert
          called = true
          EM.stop if alert && alert.attributes.match(payload)
        end
      end

      expect(alert).to_not be_nil
      expect(alert.attributes).to eq(payload)
      expect(called).to be(true)
    end
  end

  context 'when health monitor fails to fetch deployments' do
    # director is not running

    before do
      created_at_time = Time.now
      Timecop.freeze(created_at_time)
    end

    it 'sends an alert to its plugins' do
      allow(SecureRandom).to receive(:uuid).and_return('random-id')
      alert_json = {
        'id' => 'random-id',
        'severity' => 3,
        'title' => 'Health monitor failed to connect to director',
        'summary' => /Cannot get status from director/,
        'created_at' => Time.now.to_i,
        'source' => 'hm'
      }

      called = false
      alert = nil
      EM.run do
        nats = FakeNATS.new
        allow(NATS).to receive(:connect).and_return(nats)
        runner.run
        wait_for_plugins
        EM.add_timer(5) { EM.stop }
        EM.add_periodic_timer(0.1) do
          alert = get_alert
          called = true
          EM.stop if alert && alert.attributes.match(alert_json)
        end
      end

      expect(alert).to_not be_nil
      expect(alert.attributes).to match(alert_json)
      expect(called).to be(true)
    end
  end

  def start_fake_nats
    @nats = FakeNATS.new
    allow(NATS).to receive(:connect).and_return(@nats)
  end

  def wait_for_plugins(tries=60)
    while tries > 0
      tries -= 1
      # wait for alert plugin to load
      return if Bosh::Monitor.event_processor && Bosh::Monitor.event_processor.plugins[:alert]
      sleep 0.2
    end
    raise 'Failed to configure event_processor in time'
  end

  def get_alert
    dummy_plugin = Bosh::Monitor.event_processor.plugins[:alert].first
    return dummy_plugin.events.first if dummy_plugin.events
  end
end
