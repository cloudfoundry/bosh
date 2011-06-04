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
    test_cmd(["delete", "release", "a", "--force" ], :release, :delete, ["a", "--force"])

    test_cmd(["create", "user", "admin"], :user, :create, ["admin"])
    test_cmd(["create", "user", "admin", "12321"], :user, :create, ["admin", "12321"])
    test_cmd(["create", "release"], :release, :create)
    test_cmd(["reset", "release"], :release, :reset)
    test_cmd(["create", "package", "bla"], :package, :create, ["bla"])

    test_cmd(["login", "admin", "12321"], :misc, :login, ["admin", "12321"])
    test_cmd(["logout"], :misc, :logout)
    test_cmd(["purge"], :misc, :purge_cache)

    test_cmd(["upload", "release", "/path"], :release, :upload, ["/path"])
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
    test_cmd(["tasks", "running"], :task, :list_running)
    test_cmd(["tasks", "recent"], :task, :list_recent)
    test_cmd(["tasks", "recent", "42"], :task, :list_recent, [ "42" ])
  end

  it "dispatches commands to appropriate methods (old school)" do
    test_cmd(["version"], :misc, :version)
    test_cmd(["status"], :misc, :status)
    test_cmd(["target"], :misc, :show_target)
    test_cmd(["target", "test"], :misc, :set_target, ["test"])
    test_cmd(["deploy"], :deployment, :perform)
    test_cmd(["deployment"], :deployment, :show_current)
    test_cmd(["deployment", "test"], :deployment, :set_current, ["test"])
    test_cmd(["deployment", "delete", "foo"], :deployment, :delete, ["foo"])
    test_cmd(["user", "create", "admin"], :user, :create, ["admin"])
    test_cmd(["user", "create", "admin", "12321"], :user, :create, ["admin", "12321"])
    test_cmd(["login", "admin", "12321"], :misc, :login, ["admin", "12321"])
    test_cmd(["logout"], :misc, :logout)
    test_cmd(["purge"], :misc, :purge_cache)
    test_cmd(["task", "500"], :task, :track, ["500"])
    test_cmd(["release", "upload", "/path"], :release, :upload, ["/path"])
    test_cmd(["release", "verify", "/path"], :release, :verify, ["/path"])
    test_cmd(["stemcell", "verify", "/path"], :stemcell, :verify, ["/path"])
    test_cmd(["stemcell", "upload", "/path"], :stemcell, :upload, ["/path"])
    test_cmd(["stemcell", "delete", "a", "1"], :stemcell, :delete, ["a", "1"])
    test_cmd(["stemcells"], :stemcell, :list)
    test_cmd(["releases"], :release, :list)
    test_cmd(["deployments"], :deployment, :list)
    test_cmd(["tasks"], :task, :list_running)
    test_cmd(["tasks", "running"], :task, :list_running)
    test_cmd(["tasks", "recent"], :task, :list_recent)
    test_cmd(["tasks", "recent", "42"], :task, :list_recent, [ "42" ])
  end

  it "whines on extra arguments" do
    runner = Bosh::Cli::Runner.new(["deploy", "--recreate", "me", "bla"])
    runner.parse_command!
    runner.namespace.should == nil
    runner.action.should == nil
    runner.usage_error.should == "Too many arguments: 'me', 'bla'"
  end

  it "whines on too few arguments" do
    runner = Bosh::Cli::Runner.new(["release", "upload"])
    runner.parse_command!
    runner.namespace.should == nil
    runner.action.should == nil
    runner.usage_error.should == "Not enough arguments"
  end

end
