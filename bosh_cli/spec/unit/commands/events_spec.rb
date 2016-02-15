require 'spec_helper'

describe Bosh::Cli::Command::Events do
  subject(:command) { described_class.new }

  before do
    allow(command).to receive_messages(director: director, logged_in?: true, nl: nil, say: nil)
  end

  let(:director) { double(Bosh::Cli::Client::Director) }

  describe '#list' do
    let(:target) { 'http://example.org' }
    let(:event_1) do
      {
          "id"           => 1,
          "target_type"  => "deployment",
          "target_name"  => "simple",
          "event_action" => "create",
          "event_state"  => "started",
          "event_result" => "running",
          "task_id"      => 1,
          "timestamp"    => 1455635708,
      }
    end
    let(:event_2) do
      {
          "id"           => 2,
          "target_type"  => "deployment",
          "target_name"  => "simple",
          "event_action" => "create",
          "event_state"  => "done",
          "event_result" => "/deployments/simple",
          "task_id"      => 1,
          "timestamp"    => 1455635708,
      }
    end

    context 'when there are events' do
      before { expect(director).to receive(:list_events) { [event_1, event_2] } }

      it 'lists all events' do
        expect(command).to receive(:say) do |display_output|
          expect(display_output.to_s).to match_output "
+---+---------------------+--------+---------+---------------------+------+-------------------------+
| # | Name                | Action | State   | Result              | Task | Timestamp               |
+---+---------------------+--------+---------+---------------------+------+-------------------------+
| 1 | 'simple' deployment | create | started | running             | 1    | 2016-02-16 15:15:08 UTC |
| 2 | 'simple' deployment | create | done    | /deployments/simple | 1    | 2016-02-16 15:15:08 UTC |
+---+---------------------+--------+---------+---------------------+------+-------------------------+
"
        end
        command.list
      end
    end

    context 'when there no events' do
      before { expect(director).to receive(:list_events) { [] } }

      it 'displays a message telling the user that there are no events' do
        expect(command).to receive(:say) do |display_output|
          expect(display_output).to include('No events')
        end
        command.list
      end
    end
  end
end