# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::Runner do

  before(:all) do
    @out = StringIO.new
    Bosh::Cli::Config.output = @out
  end

  def test_cmd(args, namespace, action, cmd_args = [])
    runner = Bosh::Cli::Runner.new(args)
    runner.prepare
    runner.dispatch

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
    runner = Bosh::Cli::Runner.new(["--verbose", "--no-color",
                                    "--skip-director-checks", "--quiet",
                                    "--non-interactive", "release",
                                    "upload", "/path"])
    runner.parse_options!
    runner.options[:verbose].should  == true
    runner.options[:colorize].should == false
    runner.options[:director_checks].should == false
    runner.options[:quiet].should == true
    runner.options[:non_interactive].should == true
  end

  it "dispatches commands to appropriate methods (nu school)" do
    test_cmd(["version"], :misc, :version)
    test_cmd(["status"], :misc, :status)
    test_cmd(["target"], :misc, :show_target)
    test_cmd(["target", "test"], :misc, :set_target, ["test"])
    test_cmd(["target", "test", "alias"], :misc, :set_target, ["test", "alias"])
    test_cmd(["deploy"], :deployment, :perform)
    test_cmd(["deployment"], :deployment, :show_current)
    test_cmd(["deployment", "test"], :deployment, :set_current, ["test"])

    test_cmd(["delete", "deployment", "foo"], :deployment, :delete, ["foo"])
    test_cmd(["delete", "stemcell", "a", "1"], :stemcell, :delete, ["a", "1"])
    test_cmd(["delete", "release", "a" ], :release, :delete, ["a"])
    test_cmd(["delete", "release", "a", "--force" ],
             :release, :delete, ["a", "--force"])
    test_cmd(["delete", "release", "a", "2.2.1", "--force" ],
             :release, :delete, ["a", "2.2.1", "--force"])

    test_cmd(["create", "user", "admin"], :user, :create, ["admin"])
    test_cmd(["create", "user", "admin", "12321"],
             :user, :create, ["admin", "12321"])
    test_cmd(["create", "release"], :release, :create)
    test_cmd(["reset", "release"], :release, :reset)
    test_cmd(["create", "package", "bla"], :package, :create, ["bla"])

    test_cmd(["login", "admin", "12321"], :misc, :login, ["admin", "12321"])
    test_cmd(["logout"], :misc, :logout)
    test_cmd(["purge"], :misc, :purge_cache)

    test_cmd(["init", "release"], :release, :init)
    test_cmd(["init", "release", "/path"], :release, :init, ["/path"])

    test_cmd(["upload", "release", "/path"], :release, :upload, ["/path"])
    test_cmd(["upload", "release"], :release, :upload)
    test_cmd(["upload", "stemcell", "/path"], :stemcell, :upload, ["/path"])

    test_cmd(["generate", "package", "foo"], :package, :generate, ["foo"])
    test_cmd(["generate", "job", "baz"], :job, :generate, ["baz"])

    test_cmd(["verify", "release", "/path"], :release, :verify, ["/path"])
    test_cmd(["verify", "stemcell", "/path"], :stemcell, :verify, ["/path"])

    test_cmd(["stemcells"], :stemcell, :list)
    test_cmd(["releases"], :release, :list)
    test_cmd(["deployments"], :deployment, :list)

    test_cmd(["tasks"], :task, :list_running)
    test_cmd(["task", "500"], :task, :track, ["500"])
    test_cmd(["tasks"], :task, :list_running)
    test_cmd(["tasks", "recent"], :task, :list_recent)
    test_cmd(["tasks", "recent", "42"], :task, :list_recent, [ "42" ])
  end

  it "cancels running task and quits when ctrl-c is issued " +
     "and user agrees to quit" do
    runner = Bosh::Cli::Runner.new(["any", "command"])
    runner.runner = {}
    runner.runner.stub(:task_running?).and_return(true)
    runner.stub(:kill_current_task?).and_return(true)
    runner.runner.should_receive(:cancel_current_task).once
    lambda { runner.handle_ctrl_c }.should raise_error SystemExit
  end

  it "quits when ctrl-c is issued and there is no task running" do
    runner = Bosh::Cli::Runner.new(["any", "command"])
    runner.runner = {}
    runner.runner.stub(:task_running?).and_return(false)
    lambda { runner.handle_ctrl_c }.should raise_error SystemExit
  end

  it "doesn't quit when user issues ctrl-c but does not want to quit" do
    runner = Bosh::Cli::Runner.new(["any", "command"])
    runner.runner = {}
    runner.runner.stub(:task_running?).and_return(true)
    runner.stub(:kill_current_task?).and_return(false)
    lambda { runner.handle_ctrl_c }.should_not raise_error SystemExit
  end
end
