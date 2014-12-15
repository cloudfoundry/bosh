require 'spec_helper'

describe Bhm::Plugins::Graphite do
  subject(:plugin) { Bhm::Plugins::Graphite.new(options) }

  let(:options) do
    {
      "host" => "fake-graphite-host",
      "port" => 2003
    }
  end

  describe "validates options" do
    context "when we specify both host abd port" do
      it "is valid" do
        expect(plugin.validate_options).to be(true)
      end
    end

    context "when we omit port or host" do
      let(:options) do
        {
          "host" => "localhost"
        }
      end

      it "is not valid" do
        expect(plugin.validate_options).to be(false)
      end
    end
  end

  describe "process metrics" do
    let(:connection) { instance_double("Bosh::Monitor::GraphiteConnection") }
    before { allow(EM).to receive(:connect).with("fake-graphite-host", 2003, Bhm::GraphiteConnection, "fake-graphite-host", 2003).and_return(connection) }

    context "when event loop isn't running" do
      it "doesn't start" do
        expect(plugin.run).to be(false)
      end
    end

    context "when event is of type Alert" do
      let(:event) { make_alert(timestamp: Time.now.to_i) }

      it "does not send metrics" do
        EM.run do
          plugin.run
          expect(connection).to_not receive(:send_metric)

          plugin.process(event)

          EM.stop
        end
      end
    end

    context "when event is of type Heartbeat" do
      let(:event) { make_heartbeat(timestamp: Time.now.to_i) }

      it "sends metrics to Graphite" do
        EM.run do
          plugin.run

          event.metrics.each do |metric|
            metric_name = "#{event.deployment}.#{event.job}.#{event.index}.#{event.agent_id}.#{metric.name.gsub('.', '_')}"
            expect(connection).to receive(:send_metric).with(metric_name, metric.value, metric.timestamp)
          end

          plugin.process(event)

          EM.stop
        end
      end
    end
  end
end
