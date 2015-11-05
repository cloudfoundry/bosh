# Copyright (c) 2009-2013 VMware, Inc.

require 'spec_helper'

describe Bosh::Cli::Command::Help do
  let(:runner) { instance_double('Bosh::Cli::Runner') }
  let(:help_command) { described_class.new }
  let(:vm_command) do
    double('VM Command',
           usage: 'this is vms',
           usage_with_params: 'this is vms',
           desc: 'you can use it',
           :has_options? => false)
  end
  let(:target_command) do
    double('Target Command',
           usage: 'this is target',
           usage_with_params: 'this is target',
           desc: 'you can use it too',
           :has_options? => false)
  end
  let(:all_commands) do
    { 'vms' => vm_command,
      'target' => target_command }
  end
  let(:keywords) { [] }

  before(:each) do
    allow(help_command).to receive(:runner).and_return(runner)
    allow(runner).to receive(:usage).and_return('fake runner usage')
  end

  it 'should raise an error when no help is found for a command' do
    expect {
      help_command.help('all')
    }.to raise_error(Bosh::Cli::CliError, "No help found for command `all'. Run 'bosh help --all' to see all available BOSH commands.")
  end

  context 'when keywords are not passed' do
    it 'prints out all commands help output' do
      allow(Bosh::Cli::Config).to receive(:commands).and_return(all_commands)
      expect(help_command).to receive(:say).with strip_heredoc <<-HELP
        BOSH CLI helps you manage your BOSH deployments and releases.

        fake runner usage

      HELP
      expect(described_class).to receive(:say).with('this is target').ordered
      expect(described_class).to receive(:say).with('    you can use it too').ordered
      expect(described_class).to receive(:say).with("\n").ordered
      expect(described_class).to receive(:say).with('this is vms').ordered
      expect(described_class).to receive(:say).with('    you can use it').ordered

      help_command.help(*keywords)
    end
  end

  context 'when one keyword is passed' do
    let(:keywords) { ['vms'] }

    it 'only shows records for keyword' do
      allow(runner).to receive(:usage).and_return('fake runner usage')
      allow(vm_command).to receive(:keywords).and_return(['vms'])
      allow(target_command).to receive(:keywords).and_return(['target'])

      allow(Bosh::Cli::Config).to receive(:commands).and_return(all_commands)

      expect(described_class).to receive(:say).with('this is vms').ordered
      expect(described_class).to receive(:say).with('    you can use it').ordered

      help_command.help(*keywords)
    end
  end

  context 'when multiple keywords are passed' do
    let(:keywords) { ['vms', 'target'] }

    it 'shows records for all keywords' do
      allow(runner).to receive(:usage).and_return('fake runner usage')
      allow(vm_command).to receive(:keywords).and_return(['vms'])
      allow(target_command).to receive(:keywords).and_return(['target'])

      allow(Bosh::Cli::Config).to receive(:commands).and_return(all_commands)

      expect(described_class).to receive(:say).with('this is target').ordered
      expect(described_class).to receive(:say).with('    you can use it too').ordered
      expect(described_class).to receive(:say).with("\n").ordered
      expect(described_class).to receive(:say).with('this is vms').ordered
      expect(described_class).to receive(:say).with('    you can use it').ordered

      help_command.help(*keywords)
    end
  end
end
