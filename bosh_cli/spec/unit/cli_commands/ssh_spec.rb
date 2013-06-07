# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"
require "net/ssh/gateway"

describe Bosh::Cli::Command::Base do
  # TODO: the whole spec needs to be rewritten

  before :all do
    @public_key = File.join(Dir.mktmpdir, "public_key")
    File.open(@public_key, "w+") do |f|
      f.write("PUBLIC_KEY")
    end
  end

  let(:ssh) { Bosh::Cli::Command::Ssh.new }
  let(:net_ssh) { double('net/ssh') }
  let(:director) { double('director') }
  let(:gw_host) { "gw_host" }
  let(:gw_user) { "vcap" }
  
  describe Bosh::Cli::Command::Ssh do
    it "should get the public key" do
      ssh.add_option(:public_key, @public_key)
      public_key = ssh.send(:get_public_key)
      public_key.should == "PUBLIC_KEY"
    end
    
    it "should get the public key from users home directory or raise exception" do
      public_key = nil
      begin
        public_key = ssh.send(:get_public_key)
      rescue Bosh::Cli::CliError
        public_key = "SOMETHING"
      end
      public_key.should_not be_nil
    end

    it "should contact director to setup ssh on the job" do
      director.stub(:setup_ssh).and_return([:done, 42])

      director.stub(:get_task_result_log).with(42).
        and_return(JSON.generate([{ "status" => "success", "ip" => "127.0.0.1" }]))
      director.stub(:cleanup_ssh)
      Bosh::Cli::Director.should_receive(:new).and_return(director)
      ssh.stub(:prepare_deployment_manifest).and_return("test")
      ssh.stub(:cleanup_ssh)
      ssh.stub(:get_public_key).and_return("PUBKEY")
      ssh.send(
        :setup_ssh, "dea", 0, "temp_pass") do |results, _, _|
        results.each do |result|
          result["status"].should == "success"
          result["ip"].should == "127.0.0.1"
        end
      end
    end   
    
    it "should try to execute given command remotely" do
      @interactive_shell = false
      @execute_command = false
      ssh.stub(:job_exists_in_deployment?).and_return(true)
      ssh.stub(:setup_interactive_shell) { @interactive_shell = true }
      ssh.stub(:perform_operation) { @execute_command = true }
      ssh.shell("dea", "ls -l")
      @interactive_shell.should == false && @execute_command.should == true
    end

    context '#shell' do
      it 'should fail to setup ssh when a job name is not given' do
        expect {
          ssh.shell()
        }.to raise_error(Bosh::Cli::CliError, 'Please provide job name')
      end

      it 'should fail to setup ssh when a job name does not exists in deployment' do
        ssh.stub(:job_exists_in_deployment?).and_return(false)
        expect {
          ssh.shell('dea/0')
        }.to raise_error(Bosh::Cli::CliError, "Job `dea' doesn't exist")
      end
      
      it 'should fail to setup ssh when a job index is not given' do
        ssh.stub(:job_exists_in_deployment?).and_return(true)
        expect {
          ssh.shell('dea')
        }.to raise_error(Bosh::Cli::CliError, 
                         "You should specify the job index. Can't run interactive shell on more than one instance")
      end

      it 'should fail to setup ssh when a job index is not an Integer' do
        expect {
          ssh.shell('dea/dea')
        }.to raise_error(Bosh::Cli::CliError, 'Invalid job index, integer number expected')
      end
      
      it 'should try to setup interactive shell when a job index is given' do
        @interactive_shell = false
        @execute_command = false
        ssh.stub(:job_exists_in_deployment?).and_return(true)
        ssh.stub(:setup_interactive_shell) { @interactive_shell = true }
        ssh.stub(:execute_command) { @execute_command = true }
        ssh.shell('dea', '0')
        @interactive_shell.should == true && @execute_command.should == false
      end  
 
      it 'should setup ssh' do
        Bosh::Cli::Director.should_receive(:new).and_return(director)
        Process.stub(:waitpid)
        
        ssh.add_option(:default_password, 'password')
        ssh.stub(:job_exists_in_deployment?).and_return(true)
        ssh.stub(:deployment_required)      
        ssh.stub(:get_public_key).and_return('PUBKEY')
        ssh.stub(:prepare_deployment_manifest).and_return('test')
        ssh.should_receive(:fork)
        
        director.should_receive(:setup_ssh).and_return([:done, 42])
        director.should_receive(:get_task_result_log).with(42).
          and_return(JSON.generate([{ 'status' => 'success', 'ip' => '127.0.0.1' }]))      
        director.should_receive(:cleanup_ssh)
        
        ssh.shell('dea/0')
      end
  
      it 'should setup ssh with gateway host' do
        Bosh::Cli::Director.should_receive(:new).and_return(director)
        Net::SSH::Gateway.should_receive(:new).with(gw_host, ENV["USER"]).and_return(net_ssh)
        Process.stub(:waitpid)
        
        ssh.add_option(:gateway_host, gw_host)
        ssh.add_option(:default_password, 'password')
        ssh.stub(:job_exists_in_deployment?).and_return(true)
        ssh.stub(:deployment_required)      
        ssh.stub(:get_public_key).and_return('PUBKEY')
        ssh.stub(:prepare_deployment_manifest).and_return('test')
        ssh.should_receive(:fork)
        
        director.should_receive(:setup_ssh).and_return([:done, 42])
        director.should_receive(:get_task_result_log).with(42).
          and_return(JSON.generate([{ 'status' => 'success', 'ip' => '127.0.0.1' }]))      
        director.should_receive(:cleanup_ssh)
        
        net_ssh.should_receive(:open)
        net_ssh.should_receive(:close)
        net_ssh.should_receive(:shutdown!)
        
        ssh.shell('dea/0')
      end
      
      it 'should setup ssh with gateway host and user' do
        Bosh::Cli::Director.should_receive(:new).and_return(director)
        Net::SSH::Gateway.should_receive(:new).with(gw_host, gw_user).and_return(net_ssh)
        Process.stub(:waitpid)
        
        ssh.add_option(:gateway_host, gw_host)
        ssh.add_option(:gateway_user, gw_user)
        ssh.add_option(:default_password, 'password')
        ssh.stub(:job_exists_in_deployment?).and_return(true)
        ssh.stub(:deployment_required)      
        ssh.stub(:get_public_key).and_return('PUBKEY')
        ssh.stub(:prepare_deployment_manifest).and_return('test')
        ssh.should_receive(:fork)
        
        director.should_receive(:setup_ssh).and_return([:done, 42])
        director.should_receive(:get_task_result_log).with(42).
          and_return(JSON.generate([{ 'status' => 'success', 'ip' => '127.0.0.1' }]))      
        director.should_receive(:cleanup_ssh)
        
        net_ssh.should_receive(:open)
        net_ssh.should_receive(:close)
        net_ssh.should_receive(:shutdown!)
        
        ssh.shell('dea/0')
      end
      
      it 'should fail to setup ssh with gateway host and user when authentication fails' do
        Bosh::Cli::Director.should_receive(:new).and_return(director)
        Net::SSH::Gateway.should_receive(:new).with(gw_host, gw_user).and_raise(Net::SSH::AuthenticationFailed)
        
        ssh.add_option(:gateway_host, gw_host)
        ssh.add_option(:gateway_user, gw_user)
        ssh.add_option(:default_password, 'password')
        ssh.stub(:job_exists_in_deployment?).and_return(true)
        ssh.stub(:deployment_required)      
        ssh.stub(:get_public_key).and_return('PUBKEY')
        ssh.stub(:prepare_deployment_manifest).and_return('test')
        
        director.should_receive(:setup_ssh).and_return([:done, 42])
        director.should_receive(:get_task_result_log).with(42).
          and_return(JSON.generate([{ 'status' => 'success', 'ip' => '127.0.0.1' }]))      
        director.should_receive(:cleanup_ssh)    
        
        expect {
          ssh.shell('dea/0')
        }.to raise_error(Bosh::Cli::CliError, 
                         "Authentication failed with gateway #{gw_host} and user #{gw_user}.")
      end
    end

    context '#scp' do
      it 'should fail to setup ssh when a job name does not exists in deployment' do
        ssh.add_option(:upload, true)
        ssh.stub(:job_exists_in_deployment?).and_return(false)
        expect {
          ssh.scp('dea/0')
        }.to raise_error(Bosh::Cli::CliError, "Job `dea' doesn't exist")
      end
    end
    
    context '#cleanup' do
      it 'should fail to setup ssh when a job name does not exists in deployment' do
        ssh.stub(:job_exists_in_deployment?).and_return(false)
        expect {
          ssh.cleanup('dea/0')
        }.to raise_error(Bosh::Cli::CliError, "Job `dea' doesn't exist")
      end
    end
  end
end
