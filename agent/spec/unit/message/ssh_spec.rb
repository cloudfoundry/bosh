require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::Ssh do
  def ssh_create_args
    ["setup", {"user" => "spec_user", "password" => "test", "public_key" => "PUBLIC"}]
  end

  def ssh_cleanup_args
    ["cleanup", {"user_regex" => "root", "password" => "test", "public_key" => "PUBLIC"}]
  end

  it "should return a failure when shell commands fail" do
    ssh = Bosh::Agent::Message::Ssh.new(ssh_create_args)
    ssh.stub!(:shell_cmd).and_raise("Command failed")
    rtn = ssh.setup
    rtn["status"].should == "failure"
  end

  it "should return success when create succeeds" do
    ssh = Bosh::Agent::Message::Ssh.new(ssh_create_args)
    FileUtils.stub!(:chown_R)
    @sshd_started = false
    Bosh::Agent::SshdMonitor.stub!(:start_sshd) { @sshd_started = true }
    Bosh::Agent::Config.stub!(:default_ip).and_return("127.0.0.1")
    ssh.stub!(:shell_cmd)
    rtn = ssh.setup
    rtn["status"].should == "success" && @sshd_started.should == true
  end

  it "should copy public key into users director" do
    ssh = Bosh::Agent::Message::Ssh.new(ssh_create_args)
    FileUtils.stub!(:chown_R)
    Bosh::Agent::SshdMonitor.stub!(:start_sshd)
    Bosh::Agent::Config.stub!(:default_ip).and_return("127.0.0.1")
    ssh.stub!(:shell_cmd)
    rtn = ssh.setup
    authorized_keys =  File.read(File.join(ssh.ssh_base_dir, "spec_user/.ssh/authorized_keys"))
    rtn["status"].should == "success" && authorized_keys.should == "PUBLIC"
  end

  it "should not cleanup privileged users" do
    ssh = Bosh::Agent::Message::Ssh.new(ssh_cleanup_args)
    Bosh::Agent::SshdMonitor.stub!(:stop_sshd)
    ssh.stub(:shell_cmd).with("userdel -r root") { raise "Unexpected results" }
    rtn = ssh.cleanup
    rtn["status"].should == "success"
  end
end
