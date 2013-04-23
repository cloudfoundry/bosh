require 'spec_helper'

describe Bhm::Runner do

  it "reads provided configuration file and sets Bhm singletons" do
    runner = Bhm::Runner.new(sample_config)

    Bhm.logger.should be_kind_of(Logging::Logger)
    Bhm.director.should be_kind_of(Bhm::Director)

    Bhm.intervals.poll_director.should be_kind_of Integer
    Bhm.intervals.log_stats.should be_kind_of Integer
    Bhm.intervals.agent_timeout.should be_kind_of Integer

    Bhm.mbus.endpoint.should == "nats://127.0.0.1:4222"
    Bhm.mbus.user.should be_nil
    Bhm.mbus.password.should be_nil

    Bhm.plugins.size.should == 7

  end

  it "validates configuration file" do
    pending
  end

end
