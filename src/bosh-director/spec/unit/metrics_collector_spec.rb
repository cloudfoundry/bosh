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
        Prometheus::Client.registry.unregister(:bosh_resurrection_enabled)
        Prometheus::Client.registry.unregister(:bosh_tasks_total)
      end

      describe 'start' do
        describe 'bosh_resurrection_enabled' do
          it 'populates the metrics every 30 seconds' do
            metrics_collector.start
            expect(scheduler.interval).to eq('30s')
            expect(Prometheus::Client.registry.get(:bosh_resurrection_enabled).get).to eq(1)
            scheduler.tick
            expect(Prometheus::Client.registry.get(:bosh_resurrection_enabled).get).to eq(0)
          end
        end

        describe 'task metrics' do
          let!(:task1) { Models::Task.make(state: 'queued', type: 'foobar') }
          let!(:task2) { Models::Task.make(state: 'queued', type: 'foobaz') }
          let!(:task3) { Models::Task.make(state: 'processing', type: 'foobar') }
          let!(:task4) { Models::Task.make(state: 'processing', type: 'foobar') }
          let!(:task5) { Models::Task.make(state: 'processing', type: 'foobaz') }

          it 'populates metrics for processing tasks by type' do
            metrics_collector.start
            metric = Prometheus::Client.registry.get(:bosh_tasks_total)
            expect(metric.get(labels: { state: 'queued', type: 'foobar' })).to eq(1)
            expect(metric.get(labels: { state: 'queued', type: 'foobaz' })).to eq(1)
            expect(metric.get(labels: { state: 'processing', type: 'foobar' })).to eq(2)
            expect(metric.get(labels: { state: 'processing', type: 'foobaz' })).to eq(1)

            task2.update(state: 'processing')
            scheduler.tick

            metric = Prometheus::Client.registry.get(:bosh_tasks_total)
            expect(metric.get(labels: { state: 'queued', type: 'foobaz' })).to eq(0)
            expect(metric.get(labels: { state: 'processing', type: 'foobaz' })).to eq(2)
          end
        end
      end
    end
  end
end
