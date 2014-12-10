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
        Bhm::Plugins::Graphite.new(valid_options).validate_options.should be(true)
      end
    end

    context "when we omit port or host" do
      it "is not valid" do
        invalid_options = {
            "host" => "localhost"
        }
        Bhm::Plugins::Graphite.new(invalid_options).validate_options.should be(false)
      end
    end
  end

  describe "process metrics" do

    context "when event loop isn't running" do
      it "doesn't start" do
        @plugin.run.should be(false)
      end
    end

    context "when event is of type Alert" do
      it "does not send metrics" do
        graphite = double("graphite connection")

        alert = make_alert(timestamp: Time.now.to_i)

        EM.run do
          EM.stub(:connect) { graphite }
          @plugin.run

          graphite.should_not_receive(:send_metric)

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
          EM.should_receive(:connect).with("localhost", 4242, Bhm::GraphiteConnection, "localhost", 4242).once.and_return(graphite)
          @plugin.run

          heartbeat.metrics.each do |metric|
            graphite.should_receive(:send_metric).with(metric.name, metric.value, metric.timestamp)
          end

          @plugin.process(heartbeat)

          EM.stop
        end
      end
    end
  end
end
