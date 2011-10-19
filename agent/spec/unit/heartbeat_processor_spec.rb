require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::HeartbeatProcessor do

  before(:each) do
    @processor = Bosh::Agent::HeartbeatProcessor.new
  end

  it "should raise an error when the reactor isn't running'" do
    lambda { @processor.enable }.should raise_error
  end

end
