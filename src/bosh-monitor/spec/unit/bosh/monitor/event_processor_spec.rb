require_relative '../../../spec_helper'

describe Bhm::EventProcessor do
  before do
    email_options = {
      'recipients' => ['dude@example.com'],
      'smtp' => {
        'from' => 'hm@example.com',
        'host' => 'smtp.example.com',
        'port' => 587,
        'domain' => 'example.com',
      },
      'interval' => 0.1,
    }

    Bhm.logger = logger
    @processor = Bhm::EventProcessor.new

    @logger_plugin = Bhm::Plugins::Logger.new
    @email_plugin = Bhm::Plugins::Email.new(email_options)
  end

  it 'registers plugin handlers for different event kinds' do
    @processor.add_plugin(@logger_plugin, %w[alert heartbeat])
    @processor.add_plugin(@email_plugin, %w[heartbeat foobar])

    expect(@logger_plugin).to receive(:process) { |alert|
      expect(alert).to be_instance_of Bhm::Events::Alert
    }

    expect(@email_plugin).not_to receive(:process)
    @processor.process(:alert, alert_payload)
  end

  it 'dedups events' do
    @processor.add_plugin(@logger_plugin, ['alert'])
    @processor.add_plugin(@email_plugin, ['heartbeat'])

    expect(@logger_plugin).to receive(:process) { |alert|
      expect(alert).to be_instance_of Bhm::Events::Alert
      expect(alert.id).to eq(1)
    }.once

    expect(@logger_plugin).to receive(:process) { |alert|
      expect(alert).to be_instance_of Bhm::Events::Alert
      expect(alert.id).to eq(2)
    }.once

    expect(@email_plugin).to receive(:process) { |heartbeat|
      expect(heartbeat).to be_instance_of Bhm::Events::Heartbeat
      expect(heartbeat.id).to eq(1)
    }.once

    expect(@email_plugin).to receive(:process) { |heartbeat|
      expect(heartbeat).to be_instance_of Bhm::Events::Heartbeat
      expect(heartbeat.id).to eq(2)
    }.once

    @processor.process(:alert, alert_payload(id: 1))
    @processor.process(:alert, alert_payload(id: 2))
    @processor.process(:alert, alert_payload(id: 2))

    @processor.process(:heartbeat, heartbeat_payload(id: 1))
    @processor.process(:heartbeat, heartbeat_payload(id: 2))
    @processor.process(:heartbeat, heartbeat_payload(id: 2))

    expect(@processor.events_count).to eq(4)
  end

  it 'logs and swallows plugin exceptions' do
    @processor.add_plugin(@logger_plugin, %w[alert heartbeat])

    expect(@logger_plugin).to receive(:process) { |alert|
      expect(alert).to be_instance_of Bhm::Events::Alert
    }.and_raise(Bhm::PluginError.new('error1'))

    expect(@logger_plugin).to receive(:process) { |heartbeat|
      expect(heartbeat).to be_instance_of Bhm::Events::Heartbeat
    }.and_raise(Bhm::PluginError.new('error2'))

    @processor.process(:alert, alert_payload)
    @processor.process(:heartbeat, heartbeat_payload)

    expect(log_string).to include('Plugin Bosh::Monitor::Plugins::Logger failed to process alert: error1')
    expect(log_string).to include('Plugin Bosh::Monitor::Plugins::Logger failed to process heartbeat: error2')
  end

  it 'can prune old events' do
    @processor.add_plugin(@logger_plugin, ['alert'])
    @processor.add_plugin(@email_plugin, ['heartbeat'])

    ts = Time.now

    @processor.process(:alert, alert_payload(id: 1))
    @processor.process(:alert, alert_payload(id: 2))
    @processor.process(:alert, alert_payload(id: 2))
    expect(@processor.events_count).to eq(2)

    allow(Time).to receive(:now).and_return(ts + 6)
    @processor.prune_events(5)

    expect(@processor.events_count).to eq(0)
    @processor.process(:alert, alert_payload(id: 1))
    @processor.process(:alert, alert_payload(id: 2))
    expect(@processor.events_count).to eq(2)
  end
end
