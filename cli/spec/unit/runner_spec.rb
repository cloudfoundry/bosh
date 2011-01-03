require 'spec_helper'

describe Bosh::Cli::Runner do

  before(:all) do
    @out = StringIO.new
    Bosh::Cli::Config.output = @out
  end

  def test_cmd(args, namespace, action, cmd_args = [])
    runner = Bosh::Cli::Runner.new(args)
    runner.parse_command!
    runner.namespace.should == namespace
    runner.action.should    == action
    runner.args.should  == cmd_args
  end

  it "has a set of default global options" do
    runner = Bosh::Cli::Runner.new(["do", "some", "stuff"])
    runner.parse_options!
    runner.options[:verbose].should  == nil
    runner.options[:colorize].should == true
    runner.options[:director_checks].should == true
    runner.options[:quiet].should == nil
    runner.options[:non_interactive].should == nil
  end

  it "allows overriding global options" do
    runner = Bosh::Cli::Runner.new(["-v", "--no-color", "--force", "--quiet", "--non-interactive", "release", "upload", "/path"])
    runner.parse_options!
    runner.options[:verbose].should  == true
    runner.options[:colorize].should == false
    runner.options[:director_checks].should == false
    runner.options[:quiet].should == true
    runner.options[:non_interactive].should == true
  end

  it "dispatches commands to appropriate methods" do
    test_cmd(["version"], :dashboard, :version)
    test_cmd(["status"], :dashboard, :status)    
    test_cmd(["target"], :dashboard, :show_target)
    test_cmd(["target", "test"], :dashboard, :set_target, ["test"])
    test_cmd(["deploy"], :deployment, :perform)
    test_cmd(["deployment"], :deployment, :show_current)
    test_cmd(["deployment", "test"], :deployment, :set_current, ["test"])
    test_cmd(["user", "create", "admin"], :user, :create, ["admin"])
    test_cmd(["user", "create", "admin", "12321"], :user, :create, ["admin", "12321"])
    test_cmd(["login", "admin", "12321"], :dashboard, :login, ["admin", "12321"])
    test_cmd(["logout"], :dashboard, :logout)
    test_cmd(["purge"], :dashboard, :purge_cache)
    test_cmd(["task", "500"], :task, :track, ["500"])
    test_cmd(["release", "upload", "/path"], :release, :upload, ["/path"])
    test_cmd(["release", "verify", "/path"], :release, :verify, ["/path"])
    test_cmd(["stemcell", "verify", "/path"], :stemcell, :verify, ["/path"])
    test_cmd(["stemcell", "upload", "/path"], :stemcell, :upload, ["/path"])
  end

  it "whines on extra arguments" do
    runner = Bosh::Cli::Runner.new(["deploy", "--mutator", "me", "bla"])
    runner.parse_command!
    runner.namespace.should == nil
    runner.action.should == nil
    runner.usage_error.should == "Too many arguments: '--mutator', 'me', 'bla'"
  end

  it "whines on too few arguments" do
    runner = Bosh::Cli::Runner.new(["release", "upload"])
    runner.parse_command!
    runner.namespace.should == nil
    runner.action.should == nil    
    runner.usage_error.should == "Not enough arguments"
  end

end
