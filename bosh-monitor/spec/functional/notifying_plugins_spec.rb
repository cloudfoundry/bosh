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
  def start_health_monitor
    Thread.new { runner.run }
    sleep 1
  end

  def send_failure_message
    @nats.alert(JSON.dump(payload))
  end

  def start_fake_nats
    @nats = FakeNATS.new
    NATS.stub(:connect => @nats)
  end

  def fake_director
    director = double(Bosh::Monitor::Director, :get_deployments => [])
    Bosh::Monitor::Director.stub(:new => director)
  end

  let(:runner) { Bosh::Monitor::Runner.new(spec_asset("dummy_plugin_config.yml")) }
  let(:event_processor) { Bosh::Monitor.event_processor }
  let(:dummy_plugin) { event_processor.plugins[:alert].first }
  let(:payload) { {
      "id" => 'payload-id',
      "severity" => 3,
      "title" => 'payload-title',
      "summary" => 'payload-summary',
      "created_at" => Time.now.to_i
  } }

  before do
    start_fake_nats
    start_health_monitor
  end

  after do
    runner.stop(true)
  end

  it 'sends an alert to its plugins' do
    send_failure_message
    alert = dummy_plugin.events.first
    expect(alert.attributes).to eq payload
  end
end
