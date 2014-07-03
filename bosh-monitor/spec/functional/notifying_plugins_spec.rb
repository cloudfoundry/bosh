require 'spec_helper'

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
    reply = "reply"
    subject = "1.2.3.not-an-agent"

    @subscribers.each do |subscriber|
      puts "Alerting subscriber: #{subscriber}" if @verbose
      subscriber.call(message, reply, subject)
    end
  end
end

describe 'notifying plugins' do
  let(:runner) { Bosh::Monitor::Runner.new(spec_asset("dummy_plugin_config.yml")) }

  before do
    start_fake_nats
    start_health_monitor
  end

  after { runner.stop(true) }

  it 'sends an alert to its plugins' do
    payload = {
      "id" => 'payload-id',
      "severity" => 3,
      "title" => 'payload-title',
      "summary" => 'payload-summary',
      "created_at" => Time.now.to_i,
    }

    @nats.alert(JSON.dump(payload))

    dummy_plugin = Bosh::Monitor.event_processor.plugins[:alert].first

    alert = dummy_plugin.events.first

    expect(alert.attributes).to eq(payload)
  end

  def start_health_monitor(tries=60)
    Thread.new { runner.run }
    while tries > 0
      tries -= 1
      # wait for alert plugin to load
      return if Bosh::Monitor.event_processor && Bosh::Monitor.event_processor.plugins[:alert]
      sleep 0.2
    end
    raise "Failed to configure event_processor in time"
  end

  def start_fake_nats
    @nats = FakeNATS.new
    NATS.stub(:connect => @nats)
  end
end
