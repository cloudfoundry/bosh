require 'spec_helper'

describe Bhm::Plugins::Base do

  it "has stubs for methods supposed to be overriden by plugins" do
    plugin = Bhm::Plugins::Base.new
    lambda {
      plugin.run
    }.should raise_error(Bhm::FatalError, "`run' method is not implemented in `Bosh::Monitor::Plugins::Base'")

    lambda {
      plugin.process("foo")
    }.should raise_error(Bhm::FatalError, "`process' method is not implemented in `Bosh::Monitor::Plugins::Base'")

    plugin.validate_options.should be(true)
    plugin.options.should == {}
    plugin.event_kinds.should == []
  end

end
