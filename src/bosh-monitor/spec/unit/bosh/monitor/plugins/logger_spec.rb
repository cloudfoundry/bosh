require 'spec_helper'

describe Bosh::Monitor::Plugins::Logger do
  let(:plugin) { Bosh::Monitor::Plugins::Logger.new(options) }
  let(:heartbeat) { Bosh::Monitor::Events::Base.create!(:heartbeat, heartbeat_payload) }
  let(:alert) { Bosh::Monitor::Events::Base.create!(:alert, alert_payload) }

  before do
    Bosh::Monitor.logger = logger
  end

  describe 'without options' do
    let(:options) { nil }

    it 'validates' do
      expect(plugin.validate_options).to be(true)
    end

    it 'writes events to log' do
      expect(logger).to receive(:info).with("[HEARTBEAT] #{heartbeat}")
      expect(logger).to receive(:info).with("[ALERT] #{alert}")

      plugin.process(heartbeat)
      plugin.process(alert)
    end
  end

  describe 'with json output option' do
    let(:options) do
      { 'format' => 'json' }
    end

    it 'validates' do
      expect(plugin.validate_options).to be(true)
    end
    it 'writes events to log as json' do
      expect(logger).to receive(:info).with(heartbeat.to_json)
      expect(logger).to receive(:info).with(alert.to_json)

      plugin.process(heartbeat)
      plugin.process(alert)
    end
  end

  describe 'with garbage option' do
    describe 'with unknown option key' do
      let(:options) do
        { 'foofoo' => {} }
      end
      it 'does not validate' do
        expect(plugin.validate_options).to be(false)
      end
    end

    describe 'with unknown format' do
      let(:options) do
        { 'format' => 'blargh' }
      end
      it 'does not validate' do
        expect(plugin.validate_options).to be(false)
      end
    end
  end
end
