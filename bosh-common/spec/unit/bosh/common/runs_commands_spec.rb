require 'bosh/common/runs_commands'

describe Bosh::Common::RunsCommands do

  class C
    include Bosh::Common::RunsCommands
  end

  it 'delegates the sh method to its command runner' do
    command_runner = double('command runner')

    c = C.new
    c.command_runner = command_runner

    command_runner.should_receive(:sh).with('hi')
    c.sh 'hi'
  end

  it 'defaults the command runner to Bosh::Common::Exec' do
    c = C.new
    Bosh::Common::Exec.should_receive(:sh).with('hi')
    c.sh('hi')
  end
end
