# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::Command::Base do

  before :all do
    @public_key = File.join(Dir.mktmpdir, "public_key")
    File.open(@public_key, "w+") do |f|
      f.write("PUBLIC_KEY")
    end
  end

  describe Bosh::Cli::Command::Ssh do
    it "should get the public key" do
      ssh = Bosh::Cli::Command::Ssh.new
      public_key = ssh.get_public_key("public_key" => @public_key)
      public_key.should == "PUBLIC_KEY"
    end

    it "should get the public key from users home directory " +
       "or raise exception" do
      ssh = Bosh::Cli::Command::Ssh.new
      public_key = nil
      begin
        public_key = ssh.get_public_key({})
      rescue Bosh::Cli::CliExit
        public_key = "SOMETHING"
      end
      public_key.should_not be_nil
    end

    it "should contact director to setup ssh on the job" do
      mock_director = mock(Object)
      mock_director.stub(:setup_ssh).and_return([{ "status" => "success",
                                                   "ip" => "127.0.0.1" }])
      mock_director.stub(:cleanup_ssh)
      Bosh::Cli::Director.should_receive(:new).and_return(mock_director)
      ssh = Bosh::Cli::Command::Ssh.new
      ssh.stub(:prepare_deployment_manifest).and_return("test")
      ssh.stub(:cleanup_ssh)
      ssh.setup_ssh("dea", 0, "temp_pass",
                    { "public_key" => @public_key }) do |results, user|
        results.each do |result|
          result["status"].should == "success"
          result["ip"].should == "127.0.0.1"
        end
      end
    end

    it "should try to setup interactive shell when a job index is given" do
      ssh = Bosh::Cli::Command::Ssh.new
      @interactive_shell = false
      @execute_command = false
      ssh.stub(:setup_interactive_shell) { @interactive_shell = true }
      ssh.stub(:execute_command) { @execute_command = true }
      ssh.shell("dea", "0")
      @interactive_shell.should == true && @execute_command.should == false
    end

    it "should fail to setup interactive shell when a job index is not given" do
      ssh = Bosh::Cli::Command::Ssh.new
      lambda {
        ssh.shell("dea")
      }.should raise_error(Bosh::Cli::CliExit, "Please specify a job index")
    end

    it "should try to execute given command remotely" do
      ssh = Bosh::Cli::Command::Ssh.new
      @interactive_shell = false
      @execute_command = false
      ssh.stub(:setup_interactive_shell) { @interactive_shell = true }
      ssh.stub(:execute_command) { @execute_command = true }
      ssh.shell("dea", "ls -l")
      @interactive_shell.should == false && @execute_command.should == true
    end
  end
end
