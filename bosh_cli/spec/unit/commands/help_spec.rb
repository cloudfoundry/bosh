# Copyright (c) 2009-2013 VMware, Inc.

require 'spec_helper'

describe Bosh::Cli::Command::Help do
  let(:runner) { double(Bosh::Cli::Runner) }
  let(:command) { described_class.new }

  before(:each) do
    command.stub(:runner).and_return(runner)
  end

  it 'should raise an error when no help is found for a command' do
    expect {
      command.help('all')
    }.to raise_error(Bosh::Cli::CliError, "No help found for command `all'. Run 'bosh help --all' to see all available BOSH commands.")
  end
end