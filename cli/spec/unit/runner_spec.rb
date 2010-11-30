require 'spec_helper'

describe Bosh::Cli::Runner do

  before(:all) do
    Bosh::Cli::Runner.class_eval do
      def dummy_cmd(arg1, arg2, arg3); end
    end
  end

  it "dispatches commands to appropriate methods" do
    runner = Bosh::Cli::Runner.new(:dummy_cmd, 1, 2, 3)
    runner.should_receive(:dummy_cmd).with(1, 2, 3)
    runner.run
  end

  it "whines on invalid arity" do
    runner = Bosh::Cli::Runner.new(:dummy_cmd, 1, 2)

    lambda {
      runner.run
    }.should raise_error(ArgumentError, "wrong number of arguments for Bosh::Cli::Runner#dummy_cmd (2 for 3)")
  end

  it "whines on invalid command" do
    runner = Bosh::Cli::Runner.new(:do_stuff, 1, 2)

    lambda {
      runner.run
    }.should raise_error(Bosh::Cli::UnknownCommand, "unknown command 'do_stuff'")
  end
  
end
