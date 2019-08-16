require 'spec_helper'

describe Bhm::Events::Base do
  it 'can act as events factory' do
    alert = Bhm::Events::Base.create(:alert, alert_payload)
    expect(alert).to be_instance_of Bhm::Events::Alert
    expect(alert.kind).to eq(:alert)

    heartbeat = Bhm::Events::Base.create(:heartbeat, heartbeat_payload)
    expect(heartbeat).to be_instance_of Bhm::Events::Heartbeat
    expect(heartbeat.kind).to eq(:heartbeat)
  end

  it 'whines on attempt to create event from unsupported types' do
    expect do
      Bhm::Events::Base.create!(:alert, 'foo')
    end.to raise_error(Bhm::InvalidEvent, 'Cannot create event from String')
  end

  it 'whines on invalid events (when using create!)' do
    incomplete_payload = alert_payload(severity: nil)

    alert = Bhm::Events::Base.create(:alert, incomplete_payload)
    expect(alert).not_to be_valid

    expect do
      Bhm::Events::Base.create!(:alert, incomplete_payload)
    end.to raise_error(Bhm::InvalidEvent, 'severity is missing')
  end

  it 'whines on unknown event kinds' do
    expect do
      Bhm::Events::Base.create!(:foobar, {})
    end.to raise_error(Bhm::InvalidEvent, "Cannot find 'foobar' event handler")
  end

  it 'normalizes attributes' do
    event = Bhm::Events::Base.new(a: 1, b: 2)
    expect(event.attributes).to eq('a' => 1, 'b' => 2)
  end

  it 'provides stubs for format representations' do
    event = Bhm::Events::Base.new

    %i[validate to_plain_text to_hash to_json metrics].each do |method|
      expect do
        event.send(method)
      end.to raise_error(Bhm::FatalError, "'#{method}' is not implemented by Bosh::Monitor::Events::Base")
    end
  end
end
