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
    test_cmd(["alias", "test", "alias"], :misc, :set_alias, ["test", "alias"])
    test_cmd(["aliases"], :misc, :list_aliases)
    test_cmd(["target"], :misc, :show_target)
    test_cmd(["target", "test"], :misc, :set_target, ["test"])
    test_cmd(["target", "test", "alias"], :misc, :set_target, ["test", "alias"])
    test_cmd(["targets"], :misc, :list_targets)
    test_cmd(["deploy"], :deployment, :perform)
    test_cmd(["deployment"], :deployment, :show_current)
    test_cmd(["deployment", "test"], :deployment, :set_current, ["test"])

    test_cmd(["delete", "deployment", "foo"], :deployment, :delete, ["foo"])
    test_cmd(["delete", "stemcell", "a", "1"], :stemcell, :delete, ["a", "1"])
    test_cmd(["delete", "release", "a"], :release, :delete, ["a"])
    test_cmd(["delete", "release", "a", "--force"],
             :release, :delete, ["a", "--force"])
    test_cmd(["delete", "release", "a", "2.2.1", "--force"],
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
    test_cmd(["tasks", "recent", "42"], :task, :list_recent, ["42"])

    test_cmd(%w(blobs), :blob_management, :status)
    test_cmd(%w(add blob foo bar), :blob_management, :add, %w(foo bar))
    test_cmd(%w(upload blobs), :blob_management, :upload)
    test_cmd(%w(sync blobs), :blob_management, :sync)
  end

  it "loads custom plugins" do
    plugin_path = spec_asset("plugins")
    $:.unshift(plugin_path)

    begin
      test_cmd(["banner", "foo"], :echo, :banner, ["foo"])
      test_cmd(["say", "bar"], :echo, :say_color, ["bar"])
      test_cmd(["say", "baz", "--color", "red"],
               :echo, :say_color, ["baz", "--color", "red"])

      test_cmd(["ruby", "version"], :ruby, :ruby_version)
      test_cmd(["ruby", "config", "arch"], :ruby, :ruby_config, ["arch"])
    ensure
      $:.shift.should == plugin_path
    end
  end

  describe "command completion" do
    let(:runner) { r = Bosh::Cli::Runner.new([]); r.prepare; r }

    it "should complete 'cr' to 'create'" do
      runner.complete("cr").should == %w[create]
    end

    it "should complete 'create' to 'package, release & user'" do
      completion = runner.complete("create")
      completion.should include("package")
      completion.should include("release")
      completion.should include("user")
    end

    it "should complete 'cr' to 'create'" do
      runner.complete("create u").should == %w[user]
    end

  end

end
