require 'spec_helper'

describe Bhm::Plugins::Logger do

  let(:plugin) { Bhm::Plugins::Logger.new(options) }
  let(:heartbeat) { Bhm::Events::Base.create!(:heartbeat, heartbeat_payload) }
  let(:alert) { Bhm::Events::Base.create!(:alert, alert_payload) }

  before do
    Bhm.logger = logger
  end

  describe 'without options' do
    let(:options) { nil }

    it 'validates' do
      expect(plugin.validate_options).to be(true)
    end

    it 'writes events to log' do
      expect(logger).to receive(:info).with("[HEARTBEAT] #{heartbeat.to_s}")
      expect(logger).to receive(:info).with("[ALERT] #{alert.to_s}")

      plugin.process(heartbeat)
      plugin.process(alert)
    end
  end

  describe 'with json output option' do
    let(:options) { { 'format' => 'json' } }

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
      let(:options) { { 'foofoo' => {} } }
      it 'does not validate' do
        expect(plugin.validate_options).to be(false)
      end
    end

    describe 'with unknown format' do
      let(:options) { { 'format' => 'blargh' } }
      it 'does not validate' do
        expect(plugin.validate_options).to be(false)
      end
    end
  end
end

