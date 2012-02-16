# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::Command::Base do

  before :each do
    @config    = File.join(Dir.mktmpdir, "bosh_config")
    @cache_dir = Dir.mktmpdir
  end

  def add_config(object)
    File.open(@config, "w") do |f|
      f.write(YAML.dump(object))
    end
  end

  def make_command(options = { })
    Bosh::Cli::Command::Base.new({:config => @config,
                                  :cache_dir => @cache_dir}.merge(options))
  end

  it "can access configuration and respects options" do
    add_config("target" => "localhost:8080", "deployment" => "test")

    cmd = make_command(:verbose => true, :dry_run => true)
    cmd.verbose?.should be_true
    cmd.dry_run?.should be_true
    cmd.target.should == "localhost:8080"
    cmd.deployment.should == "test"
    cmd.username.should == nil
    cmd.password.should == nil
  end

  it "instantiates director when needed" do
    add_config("target" => "localhost:8080", "deployment" => "test")

    cmd = make_command()
    cmd.director.director_uri.should == "localhost:8080"
  end

  it "can evaluate other commands" do
    cmd     = make_command
    new_cmd = mock(Object)

    Bosh::Cli::Command::Misc.should_receive(:new).and_return(new_cmd)
    new_cmd.should_receive(:status).with(:arg1, :arg2)

    cmd.run("misc", "status", :arg1, :arg2)
  end

  it "can redirect to other commands " +
     "(effectively exiting after running them)" do
    cmd     = make_command
    new_cmd = mock(Object)

    Bosh::Cli::Command::Misc.should_receive(:new).and_return(new_cmd)
    new_cmd.should_receive(:status).with(:arg1, :arg2)

    lambda {
      cmd.redirect("misc", "status", :arg1, :arg2)
    }.should raise_error(Bosh::Cli::GracefulExit,
                         "redirected to misc status arg1 arg2")
  end

end
