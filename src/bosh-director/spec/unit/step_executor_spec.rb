require 'spec_helper'

module Bosh::Director
  describe 'StepExecutor' do
    subject(:executor) { StepExecutor.new(stage_name, agenda_step_hash) }
    let(:agenda) do
      instance_double(
        DeploymentPlan::Stages::Agenda,
        task_name: task_name,
        thread_name: thread_name,
        info: info,
        report: report,
      )
    end
    let(:another_agenda) do
      instance_double(
        DeploymentPlan::Stages::Agenda,
        task_name: task_name,
        thread_name: thread_name,
        info: info,
        report: another_report,
      )
    end
    let(:report) { instance_double(DeploymentPlan::Stages::Report) }
    let(:another_report) { instance_double(DeploymentPlan::Stages::Report) }
    let(:stage_name) { 'dummy stage' }
    let(:step1) { double('step1', perform: nil) }
    let(:step2) { double('step2', perform: nil) }
    let(:step3) { double('step3', perform: nil) }
    let(:step4) { double('step4', perform: nil) }
    let(:agenda_step_hash) { { agenda => [step1, step2], another_agenda => [step3, step4] } }
    let(:queue) { Thread::Queue.new }
    let(:logger) { Logging::Logger.new('test-logger') }
    let(:thread_name) { 'dummy_thread' }
    let(:info) { 'log info' }
    let(:task_name) { 'task name' }
    let(:stage) { instance_double(EventLog::Stage) }

    before do
      allow(Bosh::Director::ThreadPool).to receive(:new).and_call_original
      allow(Config).to receive(:max_threads).and_return(2)
      allow(Config).to receive(:logger).and_return(logger)
      allow(logger).to receive(:debug)
      allow(logger).to receive(:info)
    end

    it 'call perform on each of the steps, passing the report along' do
      expect(step1).to receive(:perform).with(report).ordered
      expect(step2).to receive(:perform).with(report).ordered

      expect(step3).to receive(:perform).with(another_report).ordered
      expect(step4).to receive(:perform).with(another_report).ordered

      executor.run
    end

    it 'runs each group of steps in a separate thread, with threads running in parallel' do
      expect(step2).to receive(:perform) do
        wait_for_parallel_call(queue, nil)
      end

      expect(step4).to receive(:perform) do
        wait_for_parallel_call(queue, nil)
      end

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
      expect(EventLog::Stage).to receive(:new)
        .with(anything, stage_name, anything, agenda_step_hash.length)
        .and_return(stage)
      expect(stage).to receive(:advance_and_track).with(task_name).twice
      executor.run
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
