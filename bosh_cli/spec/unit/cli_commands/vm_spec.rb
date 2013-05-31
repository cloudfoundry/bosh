require 'spec_helper'

require 'cli'

describe Bosh::Cli::Command::Vm do
  let(:command) { described_class.new }
  let(:director) { double(Bosh::Cli::Director) }
  let(:deployment) { 'dep1' }
  let(:target) { 'http://example.org' }

  before(:each) do
    command.stub(:director).and_return(director)
    command.stub(:nl)
    command.stub(:logged_in? => true)
    command.options[:target] = target
    command.stub(:prepare_deployment_manifest).and_return({'name' => deployment})
  end

  it 'should toggle the resurrection state to true' do
    director.should_receive(:change_vm_resurrection).with(deployment, 'dea', '1', false).exactly(4).times
    command.resurrection_state('dea', '1', 'on')
    command.resurrection_state('dea', '1', 'enable')
    command.resurrection_state('dea', '1', 'yes')
    command.resurrection_state('dea', '1', 'true')
  end

  it 'should toggle the resurrection state to false' do
    director.should_receive(:change_vm_resurrection).with(deployment, 'dea', '1', true).exactly(4).times
    command.resurrection_state('dea', '1', 'disable')
    command.resurrection_state('dea', '1', 'off')
    command.resurrection_state('dea', '1', 'no')
    command.resurrection_state('dea', '1', 'false')
  end

  it 'should error with an incorrect value' do
    expect { command.resurrection_state('dea', '1', 'nada')}.to raise_error Bosh::Cli::CliError
  end

end
