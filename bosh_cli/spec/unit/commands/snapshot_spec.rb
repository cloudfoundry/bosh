require 'spec_helper'

describe Bosh::Cli::Command::Snapshot do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Client::Director) }

  before do
    allow(command).to receive(:director).and_return(director)
    allow(command).to receive(:nl)
    allow(command).to receive(:show_current_state)
    allow(command).to receive(:prepare_deployment_manifest).and_return(double(:manifest, name: 'bosh'))
  end

  describe 'listing snapshot' do
    it_requires_logged_in_user ->(command) { command.list }

    context 'when the user is logged in' do
      before do
        allow(command).to receive_messages(:logged_in? => true)
        command.options[:target] = 'http://bosh-target.example.com'
      end

      context 'when there are snapshots' do
        let(:snapshots) {[
          {'job' => 'job', 'uuid' => '12xyz4561', 'index' => 0, 'snapshot_cid' => 'snap0a', 'created_at' => '2015-12-21 14:53:28 -0800', 'clean' => true},
          {'job' => 'job', 'uuid' => '12abdc456', 'index' => 1, 'snapshot_cid' => 'snap1a', 'created_at' => '2015-12-27 14:53:28 -0800', 'clean' => true}
        ]}

        it 'is backwards compatible with director API that does not return instance uuid' do
          snapshots = [{'job' => 'job', 'index' => 0, 'snapshot_cid' => 'snap0a', 'created_at' => '2015-12-21 14:53:28 -0800', 'clean' => true}]

          expect(director).to receive(:list_snapshots).with('bosh', nil, nil).and_return(snapshots)
          expect(command).to receive(:say) do |display_output|
            expect(display_output.to_s).to match_output '
              +-----------------+--------------+---------------------------+-------+
              | Job/ID          | Snapshot CID | Created at                | Clean |
              +-----------------+--------------+---------------------------+-------+
              | job/unknown (0) | snap0a       | 2015-12-21 14:53:28 -0800 | true  |
              +-----------------+--------------+---------------------------+-------+
              '
          end
          expect(command).to receive(:say).with('Snapshots total: 1')

          command.list
        end

        it 'list all snapshots for the deployment' do
          expect(director).to receive(:list_snapshots).with('bosh', nil, nil).and_return(snapshots)
          expect(command).to receive(:say) do |display_output|
            expect(display_output.to_s).to match_output '
              +-------------------+--------------+---------------------------+-------+
              | Job/ID            | Snapshot CID | Created at                | Clean |
              +-------------------+--------------+---------------------------+-------+
              | job/12xyz4561 (0) | snap0a       | 2015-12-21 14:53:28 -0800 | true  |
              | job/12abdc456 (1) | snap1a       | 2015-12-27 14:53:28 -0800 | true  |
              +-------------------+--------------+---------------------------+-------+
              '
          end
          expect(command).to receive(:say).with('Snapshots total: 2')

          command.list
        end

        it 'list all snapshots for a job and index' do
          expect(director).to receive(:list_snapshots).with('bosh', 'foo', '0').and_return([snapshots[0]])
          expect(command).to receive(:say) do |display_output|
            expect(display_output.to_s).to match_output '
               +-------------------+--------------+---------------------------+-------+
               | Job/ID            | Snapshot CID | Created at                | Clean |
               +-------------------+--------------+---------------------------+-------+
               | job/12xyz4561 (0) | snap0a       | 2015-12-21 14:53:28 -0800 | true  |
               +-------------------+--------------+---------------------------+-------+
              '
          end
          expect(command).to receive(:say).with('Snapshots total: 1')

          command.list('foo', '0')
        end
      end

      context 'when there are no snapshots' do
        let(:snapshots) { [] }

        it 'should not fail' do
          expect(director).to receive(:list_snapshots).with('bosh', nil, nil).and_return(snapshots)
          expect(command).to receive(:say).with('No snapshots')

          command.list
        end
      end
    end
  end

  describe 'taking a snapshot' do
    it_requires_logged_in_user ->(command) { command.take('foo', '0') }

    context 'when the user is logged in' do
      before do
        allow(command).to receive_messages(:logged_in? => true)
        command.options[:target] = 'http://bosh-target.example.com'
      end

      context 'for all deployment' do
        context 'when interactive' do
          before do
            command.options[:non_interactive] = false
          end

          context 'when the user confirms taking the snapshot' do
            it 'deletes the snapshot' do
              allow(command).to receive(:prepare_deployment_manifest).and_return(double(:manifest, name: 'bosh'))
              expect(command).to receive(:confirmed?).with("Are you sure you want to take a snapshot of all deployment 'bosh'?").and_return(true)

              expect(director).to receive(:take_snapshot).with('bosh', nil, nil)

              command.take()
            end
          end

          context 'when the user does not confirms taking the snapshot' do
            it 'does not delete the snapshot' do
              allow(command).to receive(:prepare_deployment_manifest).and_return(double(:manifest, name: 'bosh'))
              expect(command).to receive(:confirmed?).with("Are you sure you want to take a snapshot of all deployment 'bosh'?").and_return(false)

              expect(director).not_to receive(:take_snapshot)

              command.take()
            end
          end
        end

        context 'when non interactive' do
          before do
            command.options[:non_interactive] = true
          end

          it 'takes the snapshot' do
            expect(director).to receive(:take_snapshot).with('bosh', nil, nil)

            command.take
          end
        end
      end

      context 'for a job and index' do
        it 'takes the snapshot' do
          expect(director).to receive(:take_snapshot).with('bosh', 'foo', '0')

          command.take('foo', '0')
        end
      end

      context 'for a job and id' do
        it 'takes the snapshot' do
          expect(director).to receive(:take_snapshot).with('bosh', 'foo', 'abc123')

          command.take('foo', 'abc123')
        end
      end
    end
  end

  describe 'deleting a snapshot' do
    it_requires_logged_in_user ->(command) { command.delete('snap0a') }

    context 'when the user is logged in' do
      before do
        allow(command).to receive_messages(:logged_in? => true)
        command.options[:target] = 'http://bosh-target.example.com'
      end

      context 'when interactive' do
        before do
          command.options[:non_interactive] = false
        end

        context 'when the user confirms the snapshot deletion' do
          it 'deletes the snapshot' do
            expect(command).to receive(:confirmed?).with("Are you sure you want to delete snapshot 'snap0a'?").and_return(true)

            expect(director).to receive(:delete_snapshot).with('bosh', 'snap0a')

            command.delete('snap0a')
          end
        end

        context 'when the user does not confirms the snapshot deletion' do
          it 'does not delete the snapshot' do
            expect(command).to receive(:confirmed?).with("Are you sure you want to delete snapshot 'snap0a'?").and_return(false)

            expect(director).not_to receive(:delete_snapshot)

            command.delete('snap0a')
          end
        end
      end

      context 'when non interactive' do
        before do
          command.options[:non_interactive] = true
        end

        it 'deletes the snapshot' do
          expect(director).to receive(:delete_snapshot).with('bosh', 'snap0a')

          command.delete('snap0a')
        end
      end
    end
  end

  describe 'deleting all snapshots of a deployment' do
    it_requires_logged_in_user ->(command) { command.delete_all }

    context 'when the user is logged in' do
      before do
        allow(command).to receive_messages(:logged_in? => true)
        command.options[:target] = 'http://bosh-target.example.com'
      end

      context 'when interactive' do
        before do
          command.options[:non_interactive] = false
        end

        context 'when the user confirms the snapshot deletion' do
          it 'deletes all snapshots' do
            expect(command).to receive(:confirmed?)
                .with("Are you sure you want to delete all snapshots of deployment 'bosh'?").and_return(true)

            expect(director).to receive(:delete_all_snapshots).with('bosh')

            command.delete_all
          end
        end

        context 'when the user does not confirms the snapshot deletion' do
          it 'does not delete snapshots' do
            expect(command).to receive(:confirmed?)
                .with("Are you sure you want to delete all snapshots of deployment 'bosh'?").and_return(false)

            expect(director).not_to receive(:delete_all_snapshots)

            command.delete_all
          end
        end
      end

      context 'when non interactive' do
        before do
          command.options[:non_interactive] = true
        end

        it 'deletes all snapshots' do
          expect(director).to receive(:delete_all_snapshots).with('bosh')

          command.delete_all
        end
      end
    end
  end
end
