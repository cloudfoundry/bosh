require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::HeartbeatProcessor do

  before(:each) do
    @processor = Bosh::Agent::HeartbeatProcessor.new
  end

  it "should raise an error when the reactor isn't running'" do
    lambda { @processor.enable }.should raise_error
  end

  it "should add a periodic timer" do
    interval = 10
    EM.should_receive(:reactor_running?).and_return(true)
    EM.should_receive(:add_periodic_timer).with(interval)
    @processor.enable(interval)
  end

end
