require 'spec_helper'

class FakeNATS
  def initialize(verbose = false)
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
  include_context Async::RSpec::Reactor

  WebMock.allow_net_connect!

  let(:runner) { Bosh::Monitor::Runner.new(spec_asset('dummy_plugin_config.yml')) }
  let(:hm_process) { MonitorProcess.new(runner) }

  before do
    free_port = find_free_tcp_port
    allow(Bhm).to receive(:http_port).and_return(free_port)
    allow(runner).to receive(:connect_to_mbus)
    allow_any_instance_of(Puma::Launcher).to receive(:run)
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

      nats = FakeNATS.new
      allow(Bhm).to receive(:nats).and_return(nats)

      reactor.async do
        runner.run
      end

      wait_for_plugins
      nats.alert(JSON.dump(payload))

      reactor.async do |task|
        reactor.with_timeout(5) do
          loop do
            sleep(0.1)
            alert = get_alert
            called = true
            break if alert&.attributes == payload
          end
        end
      end.wait

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
        'summary' => /Unable to send get \/info/,
        'created_at' => Time.now.to_i,
        'source' => 'hm',
      }

      called = false
      alert = nil

      nats = FakeNATS.new
      allow(Bhm).to receive(:nats).and_return(nats)

      reactor.async do
        runner.run
      end

      wait_for_plugins

      reactor.async do |task|
        reactor.with_timeout(5) do
          loop do
            sleep(0.1)
            alert = get_alert
            called = true
            break if alert#&.attributes&.match(alert_json)
          end
        end
      end.wait

      expect(alert).to_not be_nil
      expect(alert.attributes).to match(alert_json)
      expect(called).to be(true)
    end
  end

  def start_fake_nats
    @nats = FakeNATS.new
    allow(NATS).to receive(:connect).and_return(@nats)
  end

  def wait_for_plugins(tries = 60)
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
