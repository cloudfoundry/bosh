require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::Handler do 

  before(:each) do
    redis = mock("redis")
    Redis.stub(:new).and_return(redis)
  end

  it "should load 3 default message processors" do
    handler = Bosh::Agent::Handler.new
    handler.processors.size.should == 3
  end

  # FIXME: break more stuff out of the redis subscribe or see if we can enhance
  # http://github.com/causes/modesty.git mock-redis to include pubsub.

end
