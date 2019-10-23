require 'spec_helper'

module Bosh
  module Director
    describe MetricsCollector do
      let(:scheduler) { double(Rufus::Scheduler) }
      let(:metrics_collector) { MetricsCollector.new(Config.load_hash(SpecHelper.spec_get_director_config)) }
      let(:resurrector_manager) { instance_double(Api::ResurrectorManager) }

      before do
        allow(Rufus::Scheduler).to receive(:new).and_return(scheduler)
        allow(Api::ResurrectorManager).to receive(:new).and_return(resurrector_manager)
        allow(resurrector_manager).to receive(:pause_for_all?).and_return(false, true, false)
      end

      after do
        Prometheus::Client.registry.unregister(:resurrection_enabled)
        Prometheus::Client.registry.unregister(:queued_tasks)
        Prometheus::Client.registry.unregister(:processing_tasks)
      end

      describe 'start' do
        describe 'resurrection_enabled' do
          it 'populates the metrics every 30 seconds' do
            allow(scheduler).to receive(:every).with('30s') do |&blk|
              expect(Prometheus::Client.registry.get(:resurrection_enabled).get).to eq(1)
              blk.call
            end

            metrics_collector.start

            expect(scheduler).to have_received(:every)
            expect(Prometheus::Client.registry.get(:resurrection_enabled).get).to eq(0)
          end
        end

        describe 'queued_tasks' do
          let!(:task1) { Models::Task.make(state: 'queued') }
          let!(:task2) { Models::Task.make(state: 'queued') }
          let!(:task3) { Models::Task.make(state: 'processing') }

          it 'populates the metrics every 30 seconds' do
            allow(scheduler).to receive(:every).with('30s') do |&blk|
              expect(Prometheus::Client.registry.get(:queued_tasks).get).to eq(2)
              expect(Prometheus::Client.registry.get(:processing_tasks).get).to eq(1)
              task2.update(state: 'processing')

              blk.call
            end

            metrics_collector.start

            expect(scheduler).to have_received(:every)
            expect(Prometheus::Client.registry.get(:queued_tasks).get).to eq(1)
            expect(Prometheus::Client.registry.get(:processing_tasks).get).to eq(2)
          end
        end
      end
    end
  end
end
