require 'spec_helper'
require 'timecop'

module Bosh::Deployer
  describe DeployerRenderer do
    subject(:renderer) { described_class.new(event_log_renderer) }

    let(:event_log_renderer) { instance_double('Bosh::Cli::TaskTracking::EventLogRenderer', finish: nil) }

    describe '#start' do
      before { Bosh::Cli::Config.poll_interval = 0.1 }
      after { renderer.finish('done') }

      it 'refreshes the event log periodically in a separate thread' do
        expect(event_log_renderer).to receive(:refresh).at_least(2).times
        expect(renderer).to receive(:sleep).with(0.1).at_least(2).times

        renderer.start

        sleep 0.5
      end
    end

    describe '#finish' do
      before { renderer.start }

      it 'stops refreshing the event log' do
        called = 0
        allow(event_log_renderer).to receive(:refresh) do
          called += 1
        end

        renderer.finish('done')

        sleep DeployerRenderer::DEFAULT_POLL_INTERVAL

        expect(called).to be < 2
      end

      it 'finishes the event log' do
        expect(event_log_renderer).to receive(:finish).with('done')
        renderer.finish('done')
      end
    end

    describe '#update' do
      before do
        @actual_json = nil
        allow(event_log_renderer).to receive(:add_output) do |output|
          @actual_json = output
        end
      end

      it 'adds an event to the event log for the given task and state' do
        time = Time.now
        Timecop.freeze(time) do
          renderer.update(:fake_state, 'fake-task')
        end

        expect(JSON.parse(@actual_json)).to include({
          'time' => time.to_s,
          'task' => 'fake-task',
          'tags' => [],
          'state' => 'fake_state',
        })
      end

      context 'when a new stage is set' do
        before { renderer.enter_stage('fake-stage', 'fake-total') }

        it 'adds an event to the event log with the current stage and an index of 1' do
          renderer.update(:fake_state, 'fake-task')

          expect(JSON.parse(@actual_json)).to include({
            'stage' => 'fake-stage',
            'index' => 1,
            'total' => 'fake-total',
          })
        end
      end

      context 'when a task was finished in the current stage' do
        before do
          renderer.enter_stage('fake-stage', 'fake-total')
          renderer.update(:finished, 'some-task')
        end

        it 'adds an event with the next index' do
          renderer.update(:fake_state, 'fake-task')

          expect(JSON.parse(@actual_json)).to include({
            'stage' => 'fake-stage',
            'index' => 2,
            'total' => 'fake-total',
          })
        end
      end

      it 'adds an event with 100 progress when the state is finished' do
        renderer.update(:finished, 'fake-task')

        expect(JSON.parse(@actual_json)).to include({
          'progress' => 100,
        })
      end

      it 'adds an event with 0 progress when the state is not finished' do
        renderer.update(:not_finished, 'fake-task')

        expect(JSON.parse(@actual_json)).to include({
          'progress' => 0,
        })
      end
    end

    describe '#duration' do
      it 'delegates to the event log' do
        expect(event_log_renderer).to receive(:duration).and_return(101)
        expect(renderer.duration).to eq(101)
      end
    end
  end
end
