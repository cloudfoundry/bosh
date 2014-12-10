require 'spec_helper'

describe Bhm::Plugins::Graphite do

  before do
    @options = {
        "host" => "graphite-host",
        "port" => 2003
    }

    @plugin = Bhm::Plugins::Graphite.new(@options)
  end

  describe "options validation" do
    context "when we specify both host abd port" do
      it "is valid" do
        valid_options = @options
        expect(Bhm::Plugins::Graphite.new(valid_options).validate_options).to be(true)
      end
    end

    context "when we omit port or host" do
      it "is not valid" do
        invalid_options = {
            "host" => "localhost"
        }
        expect(Bhm::Plugins::Graphite.new(invalid_options).validate_options).to be(false)
      end
    end
  end

  describe "process metrics" do

    context "when event loop isn't running" do
      it "doesn't start" do
        expect(@plugin.run).to be(false)
      end
    end

    context "when event is of type Alert" do
      it "does not send metrics" do
        graphite = double("graphite connection")

        alert = make_alert(timestamp: Time.now.to_i)

        EM.run do
          allow(EM).to_receive(:connect).and_return(graphite)
          @plugin.run

          expect(graphite).to_not receive(:send_metric)

          @plugin.process(alert)

          EM.stop
        end
      end
    end

    context "when event is of type Heartbeat" do

      it "sends metrics to Graphite" do
        graphite = double("graphite connection")

        heartbeat = make_heartbeat(timestamp: Time.now.to_i)

        EM.run do
          expect(EM).to receive(:connect).with(@options["host"], @options["port"], Bhm::GraphiteConnection, @options["host"], @options["port"]).once.and_return(graphite)
          @plugin.run

          heartbeat.metrics.each do |metric|
            metric_name = "#{heartbeat.deployment_name}.#{heartbeat.job}.#{heartbeat.index}.#{heartbeat.agent_id}.#{metric.name}"
            graphite.should_receive(:send_metric).with(metric.name, metric.value, metric.timestamp)
          end

          @plugin.process(heartbeat)

          EM.stop
        end
      end
    end
  end
end
