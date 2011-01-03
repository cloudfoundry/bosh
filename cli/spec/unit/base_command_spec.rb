require 'spec_helper'

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
    Bosh::Cli::Command::Base.new({:config => @config, :cache_dir => @cache_dir}.merge(options))
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

  it "fetches auth information from the config file" do
    config = {
      "target" => "localhost:8080",
      "deployment" => "test",
      "auth" => {
        "localhost:8080" => { "username" => "a", "password" => "b" },
        "localhost:8081" => { "username" => "c", "password" => "d" }
      }
    }

    add_config(config)
    cmd = make_command()

    cmd.logged_in?.should be_true
    cmd.username.should == "a"
    cmd.password.should == "b"

    config["target"] = "localhost:8081"
    add_config(config)

    cmd = make_command()
    cmd.logged_in?.should be_true
    cmd.username.should == "c"
    cmd.password.should == "d"

    config["target"] = "localhost:8082"
    add_config(config)
    cmd = make_command()
    cmd.logged_in?.should be_false
    cmd.username.should be_nil
    cmd.password.should be_nil
  end

  it "can evaluate other commands" do
    cmd     = make_command
    new_cmd = mock(Object)
    
    Bosh::Cli::Command::Dashboard.should_receive(:new).and_return(new_cmd)
    new_cmd.should_receive(:status).with(:arg1, :arg2)
    
    cmd.run("dashboard", "status", :arg1, :arg2)
  end

  it "can redirect to other commands (effectively exiting after running them)" do
    cmd     = make_command
    new_cmd = mock(Object)

    Bosh::Cli::Command::Dashboard.should_receive(:new).and_return(new_cmd)
    new_cmd.should_receive(:status).with(:arg1, :arg2)

    lambda {
      cmd.redirect("dashboard", "status", :arg1, :arg2)
    }.should raise_error(Bosh::Cli::GracefulExit, "redirected to dashboard status arg1 arg2")
  end

  it "effectively ignores config file if it is malformed" do
    add_config([1, 2, 3])
    cmd = make_command()

    cmd.target.should == nil
    cmd.deployment.should == nil
  end

  it "whines on missing config file" do
    lambda {
      File.should_receive(:open).with(@config, "w").and_raise(Errno::EACCES)
      make_command      
    }.should raise_error(Bosh::Cli::ConfigError)
  end
  
end
