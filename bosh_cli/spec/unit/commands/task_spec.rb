require 'spec_helper'

describe Bosh::Cli::Command::Task do
  subject(:command) { described_class.new }
  let(:target) { 'http://example.org' }
  before do
    allow(command).to receive_messages(director: director, logged_in?: true, nl: nil, say: nil)
    allow(command).to receive(:show_current_state)
    command.options[:target] = target
  end
  let(:director) { double(Bosh::Cli::Client::Director) }

  describe 'tasks' do
    describe 'recent' do

      let(:task_1) do
        {
            'id' => 1,
            'state' => 'done',
            'description' => 'create deployment',
            'timestamp' => 1455635708,
            'started_at' => 1455635500,
            'result' => '/deployments/dummy',
            'user' => 'admin'
        }
      end
      let(:task_2) do
        {
            'id' => 2,
            'state' => 'error',
            'description' => 'create deployment',
            'timestamp' => 1455635708,
            'started_at' => 1455635500,
            'result' => 'Action Failed',
            'user' => 'admin'
        }
      end
      let(:task_3) do
        {
            'id' => 1,
            'state' => 'done',
            'description' => 'create deployment',
            'timestamp' => 1455635708,
            'started_at' => nil,
            'result' => '/deployments/dummy',
            'user' => 'admin'
        }
      end
      let(:tasks) { [task_3, task_2, task_1] }

      context 'when there are recent tasks' do
        before { expect(director).to receive(:list_recent_tasks) { tasks } }

        it 'lists all recent tasks' do
          expect(command).to receive(:say) do |display_output|
            expect(display_output.to_s).to match_output '
+---+-------+-------------------------+-------------------------+-------+------------+-------------------+--------------------+
| # | State | Started                 | Last Activity           | User  | Deployment | Description       | Result             |
+---+-------+-------------------------+-------------------------+-------+------------+-------------------+--------------------+
| 1 | done  | -                       | 2016-02-16 15:15:08 UTC | admin |            | create deployment | /deployments/dummy |
| 2 | error | 2016-02-16 15:11:40 UTC | 2016-02-16 15:15:08 UTC | admin |            | create deployment | Action Failed      |
| 1 | done  | 2016-02-16 15:11:40 UTC | 2016-02-16 15:15:08 UTC | admin |            | create deployment | /deployments/dummy |
+---+-------+-------------------------+-------------------------+-------+------------+-------------------+--------------------+
'
          end
          command.list_recent
        end
      end

      context 'when there are no recent tasks' do
        before { expect(director).to receive(:list_recent_tasks) { [] } }

        it 'displays a message telling the user that there are no recent tasks' do
          expect { command.list_recent }.to raise_error Bosh::Cli::CliError, 'No recent tasks'
        end
      end
    end
  end
end

