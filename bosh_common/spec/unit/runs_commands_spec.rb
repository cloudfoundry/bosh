require 'common/runs_commands'

describe Bosh::RunsCommands do

  class C
    include Bosh::RunsCommands
  end

  it 'delegates the sh method to its command runner' do
    command_runner = double('command runner')

    c = C.new
    c.command_runner = command_runner

    command_runner.should_receive(:sh).with('hi')
    c.sh 'hi'
  end

  it 'defaults the command runner to Bosh::Exec' do
    c = C.new
    Bosh::Exec.should_receive(:sh).with('hi')
    c.sh('hi')
  end
end
