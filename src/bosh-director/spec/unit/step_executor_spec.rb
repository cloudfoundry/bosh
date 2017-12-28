require 'spec_helper'

module Bosh::Director
  describe 'StepExecutor' do
    subject(:executor) { StepExecutor.new(stage_name, state_step_hash) }
    let(:state_object) do
      double('state_object', task_name: task_name, thread_name: thread_name, info: info, state: state)
    end
    let(:another_state_object) do
      double('another_state_object', task_name: task_name, thread_name: thread_name, info: info, state: another_state)
    end
    let(:state) { double('state') }
    let(:another_state) { double('another_state') }
    let(:stage_name) { 'dummy stage' }
    let(:step1) { double('step1', perform: nil) }
    let(:step2) { double('step2', perform: nil) }
    let(:step3) { double('step3', perform: nil) }
    let(:step4) { double('step4', perform: nil) }
    let(:state_step_hash) { { state_object => [step1, step2], another_state_object => [step3, step4] } }
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

    it 'call perform on each of the steps, passing the state_hash along' do
      expect(step1).to receive(:perform).with(state) do
        allow(state_object).to receive(:step1_performed?).and_return(true)
      end
      expect(step2).to receive(:perform).with(state) do
        expect(state_object.step1_performed?).to eq(true)
      end

      expect(step3).to receive(:perform).with(another_state) do
        allow(another_state_object).to receive(:step3_performed?).and_return(true)
      end
      expect(step4).to receive(:perform).with(another_state) do
        expect(another_state_object.step3_performed?).to eq(true)
      end

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
        .with(anything, stage_name, anything, state_step_hash.length)
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
