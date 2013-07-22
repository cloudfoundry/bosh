# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::SyslogMonitor do

  let(:nats) { double("nats") }
  let(:agent_id) { "agent_id" }

  # first param to new() is eaten by EM
  let(:server) { Bosh::Agent::SyslogMonitor::Server.new(nil, nats, agent_id) }

  # These were obtained by running 'netcat -l 33331 -v' and listening
  let(:login_msg) { "<38>Jan  1 00:00:00 localhost sshd[22636]: Accepted publickey for bosh_8ckfjuxt7 from 10.10.0.7 port 40312 ssh2" }
  let(:logout_msg) { "<38>Jan  1 00:00:00 localhost sshd[22647]: Received disconnect from 10.10.0.7: 11: disconnected by user" }
  let(:invalid_msg) { "<38>Jun  7 19:26:05 localhost sshd[23075]: Invalid user foo from ::1" }
  let(:misc_msg) { "<38>Jan  1 00:00:00 localhost monkeyd[1337]: Printer on fire" }

  let(:time) { Time.now }
  let(:uuid) { 'abc' }

  before do
    Timecop.freeze
    UUIDTools::UUID.stub(random_create: uuid)
  end

  after do
    Timecop.return
  end

  it "converts auth login message into nats alert" do
    expected_json = Yajl::Encoder.encode({
      "id"         => uuid,
      "severity"   => 4,  # warning, see alert.rb
      "title"      => "SSH Login",
      "summary"    => "sshd[22636]: Accepted publickey for bosh_8ckfjuxt7 from 10.10.0.7 port 40312 ssh2",
      "created_at" => time.to_i
    })
    nats.should_receive(:publish).with("hm.agent.alert.agent_id", expected_json)

    server.receive_line(login_msg)
  end

  it "converts auth logout message into nats alert" do
    expected_json = Yajl::Encoder.encode({
      "id"         => uuid,
      "severity"   => 4,  # warning, see alert.rb
      "title"      => "SSH Logout",
      "summary"    => "sshd[22647]: Received disconnect from 10.10.0.7: 11: disconnected by user",
      "created_at" => time.to_i
    })
    nats.should_receive(:publish).with("hm.agent.alert.agent_id", expected_json)

    server.receive_line(logout_msg)
  end

  it "ignores invalid login msgs" do
    nats.should_not_receive(:publish)
    server.receive_line(invalid_msg)
  end

  it "ignores random msgs" do
    nats.should_not_receive(:publish)
    server.receive_line(misc_msg)
  end
end
