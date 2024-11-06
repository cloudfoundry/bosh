require 'spec_helper'

describe Bosh::Monitor::Plugins::Dummy do
  let(:plugin) { described_class.new }

  it 'retains a list of previously made alerts' do
    heartbeat = Bosh::Monitor::Events::Base.create!(:heartbeat, heartbeat_payload)
    alert = Bosh::Monitor::Events::Base.create!(:alert, alert_payload)

    plugin.process(heartbeat)
    plugin.process(alert)

    expect(plugin.events).to include(heartbeat)
    expect(plugin.events).to include(alert)
  end
end
