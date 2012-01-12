require 'spec_helper'
require 'micro/settings'

describe VCAP::Micro::Network do
  it "should set a random password at the first invocation" do
    props = {}
    VCAP::Micro::Settings.randomize_passwords(props)
    props['mysql_node']['password'].should_not be_nil
  end

  it "should not set a random password at the sequent invocations" do
    props = {}
    VCAP::Micro::Settings.randomize_passwords(props)
    p1 = props['mysql_node']['password']
    VCAP::Micro::Settings.randomize_passwords(props)
    p2 = props['mysql_node']['password']
    p1.should == p2
  end

end
