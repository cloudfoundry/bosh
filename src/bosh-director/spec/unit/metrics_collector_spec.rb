require 'spec_helper'

module Bosh
  module Director
    describe MetricsCollector do
      class FakeRufusScheduler
        attr_reader :interval
        def every(interval, &blk)
          @interval = interval
          @blk = blk
        end

        def tick
          @blk.call
        end
      end

      let(:scheduler) { FakeRufusScheduler.new }
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
            metrics_collector.start
            expect(scheduler.interval).to eq('30s')
            expect(Prometheus::Client.registry.get(:resurrection_enabled).get).to eq(1)
            scheduler.tick
            expect(Prometheus::Client.registry.get(:resurrection_enabled).get).to eq(0)
          end
        end

        describe 'queued_tasks' do
          let!(:task1) { Models::Task.make(state: 'queued') }
          let!(:task2) { Models::Task.make(state: 'queued') }
          let!(:task3) { Models::Task.make(state: 'processing') }

          it 'populates the metrics every 30 seconds' do
            metrics_collector.start

            expect(Prometheus::Client.registry.get(:queued_tasks).get).to eq(2)
            expect(Prometheus::Client.registry.get(:processing_tasks).get).to eq(1)

            task2.update(state: 'processing')
            scheduler.tick

            expect(Prometheus::Client.registry.get(:queued_tasks).get).to eq(1)
            expect(Prometheus::Client.registry.get(:processing_tasks).get).to eq(2)
          end
        end
      end
    end
  end
end
