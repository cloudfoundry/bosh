require 'spec_helper'

describe Bhm::Plugins::Json do
  let(:process_manager) { instance_double(Bosh::Monitor::Plugins::ProcessManager) }

  subject(:plugin) { Bhm::Plugins::Json.new('process_manager' => process_manager) }

  it 'send events to the process manager' do
    expect(process_manager).to receive(:start)
    plugin.run

    heartbeat = make_heartbeat(timestamp: Time.now.to_i)

    expect(process_manager).to receive(:send_event).with(heartbeat)
    plugin.process(heartbeat)
  end
end

describe Bhm::Plugins::ProcessManager do
  subject(:process_manager) do
    Bhm::Plugins::ProcessManager.new(
      glob: '/*/json-plugin/*',
      logger: double('logger').as_null_object,
      check_interval: 0.2,
      restart_wait: 0.1,
    )
  end

  it "doesn't start if event loop isn't running" do
    expect(process_manager.start).to be(false)
  end

  it 'starts processes that match the glob' do
    allow(Dir).to receive(:[]).with('/*/json-plugin/*').and_return(['/plugin'])

    process = double('some-process').as_null_object
    expect(Bosh::Monitor::Plugins::DeferrableChildProcess).to receive(:open).once.with('/plugin').and_return(process)
    allow(EventMachine).to receive(:defer).and_yield

    EM.run do
      process_manager.start

      EM.stop
    end
  end

  it 'restarts processes when they die' do
    allow(Dir).to receive(:[]).with('/*/json-plugin/*').and_return(['/non-existent-plugin'])
    expect(Bosh::Monitor::Plugins::DeferrableChildProcess).to receive(:open).at_least(2).times.with('/non-existent-plugin').and_call_original

    EM.run do
      allow(EventMachine).to receive(:add_timer).with(0.1).at_least(2).times.and_yield
      expect(EventMachine).to receive(:add_timer) { EM.stop }
      process_manager.start
    end
  end

  it 'detects and starts new processes' do
    process = double('some-process', errback: nil)
    expect(Dir).to receive(:[]).with('/*/json-plugin/*').and_return([]).once.ordered
    expect(Dir).to receive(:[]).with('/*/json-plugin/*').and_return(['/plugin']).at_least(1).times.ordered
    expect(Bosh::Monitor::Plugins::DeferrableChildProcess).to receive(:open).with('/plugin').and_return(process)

    succeeded = true
    begin
      EM.run do
        process_manager.start

        EM.add_timer(5) do
          # By this time the test is failing
          succeeded = false
          EM.stop
        end

        EM.add_periodic_timer(0.5) do
          EM.stop if process_manager.instance_variable_get(:@processes).size == 1
        end
      end
    ensure
      raise 'timeout canceling the event machine' unless succeeded
    end
  end

  it 'sends events to all managed processes as JSON' do
    alert = make_alert(timestamp: Time.now.to_i)

    expect(Dir).to receive(:[]).with('/*/json-plugin/*').and_return(['/process-a', '/process-b'])

    process_a = double('process-a').as_null_object
    allow(Bosh::Monitor::Plugins::DeferrableChildProcess).to receive(:open).with('/process-a').and_return(process_a)

    process_b = double('process-b').as_null_object
    allow(Bosh::Monitor::Plugins::DeferrableChildProcess).to receive(:open).with('/process-b').and_return(process_b)

    EM.run do
      process_manager.start

      process_manager.send_event(alert)

      expect(process_a).to have_received(:send_data).with("#{alert.to_json}\n")
      expect(process_b).to have_received(:send_data).with("#{alert.to_json}\n")

      EM.stop
    end
  end
end
