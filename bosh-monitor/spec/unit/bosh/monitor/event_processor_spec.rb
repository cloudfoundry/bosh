require 'spec_helper'

describe Bhm::EventProcessor do
  before :each do
    email_options = {
      "recipients" => [ "dude@example.com" ],
      "smtp" => {
        "from"    => "hm@example.com",
        "host"    => "smtp.example.com",
        "port"    => 587,
        "domain"  => "example.com"
      },
      "interval" => 0.1
    }

    Bhm.logger = Logging.logger(StringIO.new)
    @processor = Bhm::EventProcessor.new

    @logger_plugin = Bhm::Plugins::Logger.new
    @email_plugin = Bhm::Plugins::Email.new(email_options)

    @logger_plugin.stub(:deliver)
    @email_plugin.stub(:deliver)
  end

  it "registers plugin handlers for different event kinds" do
    @processor.add_plugin(@logger_plugin, ["alert", "heartbeat"])
    @processor.add_plugin(@email_plugin, ["heartbeat", "foobar"])

    @logger_plugin.should_receive(:process) { |alert|
      alert.should be_instance_of Bhm::Events::Alert
    }

    @email_plugin.should_not_receive(:process)
    @processor.process(:alert, alert_payload)
  end

  it "dedups events" do
    @processor.add_plugin(@logger_plugin, ["alert"])
    @processor.add_plugin(@email_plugin, ["heartbeat"])

    @logger_plugin.should_receive(:process) { |alert|
      alert.should be_instance_of Bhm::Events::Alert
      alert.id.should == 1
    }.once

    @logger_plugin.should_receive(:process) { |alert|
      alert.should be_instance_of Bhm::Events::Alert
      alert.id.should == 2
    }.once

    @email_plugin.should_receive(:process) { |heartbeat|
      heartbeat.should be_instance_of Bhm::Events::Heartbeat
      heartbeat.id.should == 1
    }.once

    @email_plugin.should_receive(:process) { |heartbeat|
      heartbeat.should be_instance_of Bhm::Events::Heartbeat
      heartbeat.id.should == 2
    }.once

    @processor.process(:alert, alert_payload(:id => 1))
    @processor.process(:alert, alert_payload(:id => 2))
    @processor.process(:alert, alert_payload(:id => 2))

    @processor.process(:heartbeat, heartbeat_payload(:id => 1))
    @processor.process(:heartbeat, heartbeat_payload(:id => 2))
    @processor.process(:heartbeat, heartbeat_payload(:id => 2))

    @processor.events_count.should == 4
  end

  it "logs and swallows plugin exceptions" do
    @processor.add_plugin(@logger_plugin, ["alert", "heartbeat"])

    @logger_plugin.should_receive(:process) { |alert|
      alert.should be_instance_of Bhm::Events::Alert
    }.and_raise(Bhm::PluginError.new("error1"))

    @logger_plugin.should_receive(:process) { |heartbeat|
      heartbeat.should be_instance_of Bhm::Events::Heartbeat
    }.and_raise(Bhm::PluginError.new("error2"))

    Bhm.logger.should_receive(:error).with("Plugin Bosh::Monitor::Plugins::Logger failed to process alert: error1")
    Bhm.logger.should_receive(:error).with("Plugin Bosh::Monitor::Plugins::Logger failed to process heartbeat: error2")
    @processor.process(:alert, alert_payload)
    @processor.process(:heartbeat, heartbeat_payload)
  end

  it "can prune old events" do
    @processor.add_plugin(@logger_plugin, ["alert"])
    @processor.add_plugin(@email_plugin, ["heartbeat"])

    ts = Time.now

    @processor.process(:alert, alert_payload(:id => 1))
    @processor.process(:alert, alert_payload(:id => 2))
    @processor.process(:alert, alert_payload(:id => 2))
    @processor.events_count.should == 2

    Time.stub(:now).and_return(ts + 6)
    @processor.prune_events(5)

    @processor.events_count.should == 0
    @processor.process(:alert, alert_payload(:id => 1))
    @processor.process(:alert, alert_payload(:id => 2))
    @processor.events_count.should == 2
  end

end
