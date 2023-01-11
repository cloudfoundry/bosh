require 'spec_helper'

module Bosh::Director
  describe 'StepExecutor' do
    subject(:executor) { StepExecutor.new(stage_name, agendas) }
    let(:agenda) do
      instance_double(
        DeploymentPlan::Stages::Agenda,
        task_name: task_name,
        thread_name: thread_name,
        info: info,
        report: report,
        steps: [step1, step2],
      )
    end
    let(:report) { instance_double(DeploymentPlan::Stages::Report) }
    let(:another_report) { instance_double(DeploymentPlan::Stages::Report) }
    let(:stage_name) { 'dummy stage' }
    let(:step1) { double('step1', perform: nil) }
    let(:step2) { double('step2', perform: nil) }
    let(:agendas) { [agenda] }
    let(:queue) { Thread::Queue.new }
    let(:logger) { Logging::Logger.new('test-logger') }
    let(:thread_name) { 'dummy_thread' }
    let(:info) { 'log info' }
    let(:task_name) { 'task name' }
    let(:stage) { instance_double(EventLog::Stage) }

    before do
      allow(Bosh::Director::ThreadPool).to receive(:new).and_wrap_original { |m, *args| m.call(max_threads: 2) }
      allow(Config).to receive(:max_threads).and_return(2)
      allow(Config).to receive(:logger).and_return(logger)
      allow(logger).to receive(:debug)
      allow(logger).to receive(:info)
    end

    it 'calls perform on each of the steps for the agenda, passing the report along' do
      expect(step1).to receive(:perform).with(report).ordered
      expect(step2).to receive(:perform).with(report).ordered

      executor.run
    end

    it 'set thread name and log info accordingly' do
      expect(step2).to receive(:perform) do
        expect(Thread.current[:name]).to eq(thread_name)
      end
      expect(logger).to receive(:info).with(info)
      executor.run
    end

    it 'create a stage and track the tasks within the stage' do
      expect(Config.event_log).to receive(:begin_stage).with(stage_name, agendas.length).and_return(stage)
      expect(stage).to receive(:advance_and_track).with(task_name)
      executor.run
    end

    context 'when configured to skip tracking' do
      subject(:executor) { StepExecutor.new(stage_name, agendas, track: false) }

      it 'skips tracking' do
        expect(Config.event_log).to_not receive(:begin_stage)
        executor.run
      end
    end

    context 'when there are multiple agendas' do
      let(:another_agenda) do
        instance_double(
          DeploymentPlan::Stages::Agenda,
          task_name: task_name,
          thread_name: thread_name,
          info: info,
          report: another_report,
          steps: [step2],
        )
      end
      let(:agendas) { [agenda, another_agenda] }

      before { allow(agenda).to receive(:steps).and_return([step1]) }

      it 'runs each group of steps in a separate thread, with threads running in parallel' do
        expect(step1).to receive(:perform) do
          wait_for_parallel_call(queue, nil)
        end

        expect(step2).to receive(:perform) do
          wait_for_parallel_call(queue, nil)
        end

        executor.run
      end
    end

    def wait_for_parallel_call(queue, result)
      queue << true

      10.times do
        return result if queue.length == 2

        sleep 0.1
      end

      raise 'Parallel call did not occur'
    end
  end
end
