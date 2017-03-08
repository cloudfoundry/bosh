require 'spec_helper'

describe Bhm::Plugins::Json do
  subject(:plugin) { Bhm::Plugins::Json.new(options) }

  let(:options) do
    {
        "bin_glob" => `which cat`.chomp
    }
  end

  let(:process) { double(:process).as_null_object }

  it "doesn't start if event loop isn't running" do
    expect(plugin.run).to be(false)
  end

  it "sends alerts as JSON" do
    alert = make_alert(timestamp: Time.now.to_i)

    expect(EventMachine::DeferrableChildProcess).to receive(:open).with("/bin/cat").and_return(process)

    EM.run do
      plugin.run

      expect(process).to receive(:send_data) do |payload|
        json = JSON.parse(payload)
        expect(json['kind']).to eq 'alert'
      end
      plugin.process(alert)

      EM.stop
    end
  end

  it "sends heartbeat metrics as JSON" do
    heartbeat = make_heartbeat(timestamp: Time.now.to_i)

    expect(EventMachine::DeferrableChildProcess).to receive(:open).with("/bin/cat").and_return(process)

    EM.run do
      plugin.run

      expect(process).to receive(:send_data) do |payload|
        json = JSON.parse(payload)
        expect(json['kind']).to eq 'heartbeat'
      end
      plugin.process(heartbeat)

      EM.stop
    end
  end
end
