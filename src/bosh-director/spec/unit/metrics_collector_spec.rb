require 'spec_helper'

module Bosh
  module Director
    describe MetricsCollector do
      let(:metrics_collector) { MetricsCollector.new({}) }
      let(:resurrector_manager) { instance_double(Api::ResurrectorManager) }

      before do
        Timecop.freeze(Time.now)

        allow(Api::ResurrectorManager).to receive(:new).and_return(resurrector_manager)
        allow(resurrector_manager).to receive(:pause_for_all?).and_return(false, true, false)
      end

      after do
        Timecop.return
      end

      describe 'start' do
        it 'populates the metrics every 30 seconds' do
          metrics_collector.start

          expect(metrics_collector.resurrection_enabled.get).to eq(1)

          Timecop.travel(Time.now + 31)
          sleep 1

          expect(metrics_collector.resurrection_enabled.get).to eq(0)

          Timecop.travel(Time.now + 61)
          sleep 1

          expect(metrics_collector.resurrection_enabled.get).to eq(1)
        end
      end
    end
  end
end
