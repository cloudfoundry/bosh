# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::Ssh do
  let(:command_runner) { double('command runner') }
  let(:ssh) { described_class.new(args, passwd_file: @passwd_file, sudoers_dir: @sudoers_dir,
                                  command_runner: command_runner) }

  before do
    @passwd_file = Tempfile.new('passwd')
    @sudoers_dir = Dir.mktmpdir('sudoersd')
  end

  after do
    @passwd_file.close
    @passwd_file.unlink
    FileUtils.rm_rf @sudoers_dir
  end

  describe '#setup' do
    let(:user) { 'spec_user' }
    let(:args) { ['setup', {'user' => user, 'password' => 'test', 'public_key' => 'PUBLIC'}] }

    it 'should return a failure when shell commands fail' do
      command_runner.stub(:sh).and_raise('Command failed')

      rtn = ssh.setup
      expect(rtn['status']).to eq 'failure'
    end

    it 'should return success when create succeeds' do
      FileUtils.stub(:chown_R)
      sshd_started = false
      Bosh::Agent::SshdMonitor.stub(:start_sshd) { sshd_started = true }
      Bosh::Agent::Config.stub(default_ip: '127.0.0.1')
      command_runner.stub(:sh)

      rtn = ssh.setup
      expect(rtn['status']).to eq 'success'
      expect(sshd_started).to be_true
    end

    it "creates the user's sudoers.d file" do
      FileUtils.stub(:chown_R)
      Bosh::Agent::SshdMonitor.stub(:start_sshd)
      Bosh::Agent::Config.stub(default_ip: '127.0.0.1')
      command_runner.stub(:sh)
      sudoers_file = File.join(@sudoers_dir, user)

      ssh.setup
      expect(File.read(sudoers_file)).to eq "\n#{user} ALL=(ALL) NOPASSWD:ALL\n"
    end

    it "should copy the public key into the user's director" do
      FileUtils.stub(:chown_R)
      Bosh::Agent::SshdMonitor.stub(:start_sshd)
      Bosh::Agent::Config.stub(default_ip: '127.0.0.1')
      command_runner.stub(:sh)

      rtn = ssh.setup
      authorized_keys = File.read(File.join(ssh.ssh_base_dir, 'spec_user/.ssh/authorized_keys'))
      expect(rtn['status']).to eq 'success'
      expect(authorized_keys).to eq 'PUBLIC'
    end

  end

  describe '#cleanup' do
    let(:args) { ['cleanup', {'user_regex' => 'root', 'password' => 'test', 'public_key' => 'PUBLIC'}] }

    it 'should not cleanup privileged users' do
      Bosh::Agent::SshdMonitor.stub(:stop_sshd)
      command_runner.stub(:sh).with('userdel -r root').and_raise('Unexpected results')

      rtn = ssh.cleanup
      expect(rtn["status"]).to eq 'success'
    end

    context "removing the user's sudoers.d file" do
      let(:user_suffix) { 'foo' }
      let(:args) { ['cleanup', {'user_regex' => user_suffix}] }

      it "removes the user's sudoers.d file" do
        user = "bosh_#{user_suffix}"
        sudoers_file = File.join(@sudoers_dir, user)

        open(sudoers_file, 'w') do |f|
          f.write 'test'
        end

        @passwd_file.write "#{user}:\n"
        @passwd_file.flush

        Bosh::Agent::SshdMonitor.stub(:stop_sshd)
        command_runner.stub(:sh)

        ssh.cleanup
        expect(File.exists?(sudoers_file)).to be_false
      end
    end

  end

end
