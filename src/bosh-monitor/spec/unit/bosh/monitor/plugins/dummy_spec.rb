require_relative '../../../../spec_helper'

describe Bhm::Plugins::Dummy do
  let(:plugin) { described_class.new }

  it 'retains a list of previously made alerts' do
    heartbeat = Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)
    alert = Bhm::Events::Base.create!(:alert, alert_payload)

    plugin.process(heartbeat)
    plugin.process(alert)

    expect(plugin.events).to include(heartbeat)
    expect(plugin.events).to include(alert)
  end
end
