require 'spec_helper'

module Bosh::Cli::TaskTracking
  describe StageCollectionPresenter do
    subject(:presenter) { described_class.new(printer) }
    let(:printer) { instance_double('Bosh::Cli::TaskTracking::SmartWhitespacePrinter', print: nil) }

    describe '#start_stage' do
      let(:curr_stage) { Stage.new('fake-curr-stage', %w(fake-tag1), 1, {}) }
      let(:last_stage) { Stage.new('fake-last-stage', %w(fake-tag2), 1, {}) }

      def self.it_prints_full_stage_start_message
        context 'when the the last stage is similar to passed in stage' do
          before { allow(curr_stage).to receive(:similar?).with(last_stage).and_return(true) }

          it 'prints a single newline' do
            expect(printer).to receive(:print).
              with(:before, '  Started fake-curr-stage fake-tag1')
            presenter.start_stage(curr_stage)
          end
        end

        context 'when the the last stage is not similar to passed in stage' do
          before { allow(curr_stage).to receive(:similar?).with(last_stage).and_return(false) }

          it 'prints one blank line' do
            expect(printer).to receive(:print).
              with(:line_before, '  Started fake-curr-stage fake-tag1')
            presenter.start_stage(curr_stage)
          end
        end
      end

      context 'when is called first' do
        it 'prints stage start full message' do
          expect(printer).to receive(:print).
            with(:line_before, '  Started fake-curr-stage fake-tag1')
          presenter.start_stage(curr_stage)
        end
      end

      context 'when it is called after stage start' do
        before { presenter.start_stage(last_stage) }
        it_prints_full_stage_start_message
      end

      context 'when it is called after stage end' do
        before { presenter.end_stage(last_stage, 'fake-prefix') }
        it_prints_full_stage_start_message
      end

      context 'when it is called after task start' do
        before { presenter.start_task(last_task) }
        let(:last_task) { Task.new(last_stage, 'fake-last-task', 1, 0, {}) }
        it_prints_full_stage_start_message
      end

      context 'when it is called after task end' do
        before { presenter.end_task(last_task, 'fake-prefix', nil) }
        let(:last_task) { Task.new(last_stage, 'fake-last-task', 1, 0, {}) }
        it_prints_full_stage_start_message
      end

      context 'when there multiple tags' do
        let(:curr_stage) { Stage.new('fake-curr-stage', %w(fake-tag1 fake-tag2), 1, {}) }

        it 'prints all the tags' do
          expect(printer).to receive(:print).
            with(:line_before, '  Started fake-curr-stage fake-tag1, fake-tag2')
          presenter.start_stage(curr_stage)
        end
      end
    end

    describe '#end_stage' do
      let(:curr_stage) { Stage.new('fake-curr-stage', %w(fake-tag1), 1, {}) }
      let(:last_stage) { Stage.new('fake-last-stage', %w(fake-tag2), 1, {}) }

      def self.it_prints_full_stage_end_message
        context 'when the the last stage is same stage' do
          before { allow(curr_stage).to receive(:==).with(last_stage).and_return(true) }

          context 'when stage has total of 1 task' do
            before { allow(curr_stage).to receive(:total).and_return(1) }

            it 'does not print anything' do
              expect(printer).to_not receive(:print)
              presenter.end_stage(curr_stage, 'fake-prefix')
            end
          end

          context 'when stage has more than 1 task' do
            before { allow(curr_stage).to receive(:total).and_return(2) }

            it 'prints a single newline' do
              expect(printer).to receive(:print).
                with(:before, 'fake-prefix fake-curr-stage fake-tag1')
              presenter.end_stage(curr_stage, 'fake-prefix')
            end
          end
        end

        context 'when the the last stage is not same stage' do
          before { allow(curr_stage).to receive(:==).with(last_stage).and_return(false) }

          it 'prints single blank newline' do
            expect(printer).to receive(:print).
              with(:line_before, 'fake-prefix fake-curr-stage fake-tag1')
            presenter.end_stage(curr_stage, 'fake-prefix')
          end
        end
      end

      context 'when is called first' do
        it 'prints stage end full message' do
          expect(printer).to receive(:print).
            with(:line_before, 'fake-prefix fake-curr-stage fake-tag1')
          presenter.end_stage(curr_stage, 'fake-prefix')
        end
      end

      context 'when it is called after stage start' do
        before { presenter.start_stage(last_stage) }
        it_prints_full_stage_end_message
      end

      context 'when it is called after stage end' do
        before { presenter.end_stage(last_stage, 'fake-prefix') }
        it_prints_full_stage_end_message
      end

      context 'when it is called after task start' do
        before { presenter.start_task(last_task) }
        let(:last_task) { Task.new(last_stage, 'fake-last-task', 1, 0, {}) }
        it_prints_full_stage_end_message
      end

      context 'when it is called after task end' do
        before { presenter.end_task(last_task, 'fake-prefix', nil) }
        let(:last_task) { Task.new(last_stage, 'fake-last-task', 1, 0, {}) }
        it_prints_full_stage_end_message
      end

      context 'when there multiple tags' do
        let(:curr_stage) { Stage.new('fake-curr-stage', %w(fake-tag1 fake-tag2), 1, {}) }

        it 'prints all the tags' do
          expect(printer).to receive(:print).
            with(:line_before, 'fake-prefix fake-curr-stage fake-tag1, fake-tag2')
          presenter.end_stage(curr_stage, 'fake-prefix')
        end
      end
    end

    describe '#start_task' do
      let(:curr_task) { Task.new(curr_stage, 'fake-curr-task', 1, 0, {}) }

      let(:curr_stage) { Stage.new('fake-curr-stage', %w(fake-tag1), 1, {}) }
      let(:last_stage) { Stage.new('fake-last-stage', %w(fake-tag2), 1, {}) }

      context 'when the task is the first task in a stage' do
        before do
          presenter.end_stage(last_stage, 'fake-prefix')
          allow(curr_stage).to receive(:==).with(last_stage).and_return(false)
        end

        context 'when the stage has 1 task' do
          before { allow(curr_stage).to receive(:total).and_return(1) }

          it 'prints a single blank newline' do
            expect(printer).to receive(:print).
              with(:line_before, '  Started fake-curr-stage fake-tag1 > fake-curr-task')
            presenter.start_task(curr_task)
          end
        end

        context 'when the stage has more than 1 task' do
          before { allow(curr_stage).to receive(:total).and_return(2) }

          context 'when the stage is similar to the last stage' do
            before { allow(curr_stage).to receive(:similar?).with(last_stage).and_return(true) }

            it 'prints a single newline' do
              expect(printer).to receive(:print).
                with(:before, '  Started fake-curr-stage fake-tag1 > fake-curr-task')
              presenter.start_task(curr_task)
            end
          end

          context 'when the stage is not similar to the last stage' do
            before { allow(curr_stage).to receive(:similar?).with(last_stage).and_return(false) }

            it 'prints a newline followed by a blank line' do
              expect(printer).to receive(:print).
                with(:line_before, '  Started fake-curr-stage fake-tag1 > fake-curr-task')
              presenter.start_task(curr_task)
            end
          end
        end
      end

      context 'when the task is not the first task in a stage' do
        before do
          presenter.end_stage(last_stage, 'fake-prefix')
          allow(curr_stage).to receive(:==).with(last_stage).and_return(true)
        end

        context 'when the stage has 1 task' do
          before { allow(curr_stage).to receive(:total).and_return(1) }

          it 'prints the message inline' do
            expect(printer).to receive(:print).
              with(:none, ' > fake-curr-task')
            presenter.start_task(curr_task)
          end
        end

        context 'when the stage has more than 1 task' do
          before { allow(curr_stage).to receive(:total).and_return(2) }

          context 'when the stage is similar to the last stage' do
            before { allow(curr_stage).to receive(:similar?).with(last_stage).and_return(true) }

            it 'prints a newline' do
              expect(printer).to receive(:print).
                with(:before, '  Started fake-curr-stage fake-tag1 > fake-curr-task')
              presenter.start_task(curr_task)
            end
          end

          context 'when the stage is not similar to the last stage' do
            before { allow(curr_stage).to receive(:similar?).with(last_stage).and_return(false) }

            it 'prints a newline followed by a blank line' do
              expect(printer).to receive(:print).
                with(:line_before, '  Started fake-curr-stage fake-tag1 > fake-curr-task')
              presenter.start_task(curr_task)
            end
          end
        end
      end
    end

    describe '#end_task' do
      let(:curr_task) { Task.new(curr_stage, 'fake-curr-task', 1, 0, {}) }

      let(:curr_stage) { Stage.new('fake-curr-stage', %w(fake-tag1), 1, {}) }
      let(:last_stage) { Stage.new('fake-last-stage', %w(fake-tag2), 1, {}) }

      context 'when task is the same as the last task' do
        before { presenter.start_task(curr_task) }

        it 'prints the message inline' do
          expect(printer).to receive(:print).
            with(:none, '. fake-task-prefixfake-task-suffix')
          presenter.end_task(curr_task, 'fake-task-prefix', 'fake-task-suffix')
        end
      end

      context 'when task is not same as the last task' do
        before { presenter.end_stage(last_stage, 'fake-prefix') }

        context 'when the stage is similar to the last stage' do
          before do
            allow(curr_stage).to receive(:similar?).with(last_stage).and_return(true)
          end

          it 'prints a newline' do
            expect(printer).to receive(:print).
              with(:before,
              '     fake fake-curr-stage fake-tag1 > fake-curr-taskfake-task-suffix')
            presenter.end_task(curr_task, 'fake', 'fake-task-suffix')
          end
        end

        context 'when the stage is not similar to the last stage' do
          before { allow(curr_stage).to receive(:similar?).with(last_stage).and_return(false) }

          it 'prints a newline followed by a blank line' do
            expect(printer).to receive(:print).
              with(:line_before,
              '     fake fake-curr-stage fake-tag1 > fake-curr-taskfake-task-suffix')
            presenter.end_task(curr_task, 'fake', 'fake-task-suffix')
          end
        end
      end
    end
  end
end
