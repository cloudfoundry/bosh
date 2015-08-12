require 'spec_helper'

describe Bhm::Plugins::SyslogEventForwarder do
  subject(:plugin) do
    subj = described_class.new
    subj.run
    subj
  end

  it 'initializes the syslogger with bosh.hm as programname' do
    expect(plugin.sys_logger).not_to be_nil
    expect(Syslog::ident).to eq('bosh.hm')
  end

  it 'writes alerts to log' do
    alert = Bhm::Events::Base.create!(:alert, alert_payload)

    expect(plugin.sys_logger).to receive(:info).with("[ALERT] #{alert.to_json}")

    plugin.process(alert)
  end

  it 'ignores heartbeats' do
    heartbeat = Bhm::Events::Base.create!(:heartbeat, heartbeat_payload)

    expect(plugin.sys_logger).not_to receive(:info)

    plugin.process(heartbeat)
  end

end

