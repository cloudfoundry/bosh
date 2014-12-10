require 'spec_helper'

describe Bhm::Plugins::Base do

  it "has stubs for methods supposed to be overriden by plugins" do
    plugin = Bhm::Plugins::Base.new
    expect {
      plugin.run
    }.to raise_error(Bhm::FatalError, "`run' method is not implemented in `Bosh::Monitor::Plugins::Base'")

    expect {
      plugin.process("foo")
    }.to raise_error(Bhm::FatalError, "`process' method is not implemented in `Bosh::Monitor::Plugins::Base'")

    expect(plugin.validate_options).to be(true)
    expect(plugin.options).to eq({})
    expect(plugin.event_kinds).to eq([])
  end

end
