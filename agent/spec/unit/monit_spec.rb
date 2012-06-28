# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::Monit do

  before(:each) do
    Bosh::Agent::Config.smtp_port = 55231
    Bosh::Agent::Monit.stub!(:monit_reload_cmd)

    monit_dir = File.join(base_dir, 'monit')
    FileUtils.mkdir_p(monit_dir)

    @monit_user_file = File.join(monit_dir, 'monit.user')
    @monit_alerts_file = File.join(monit_dir, 'alerts.monitrc')
  end

  it "should have monit user file" do
    Bosh::Agent::Monit.monit_user_file.should == @monit_user_file
  end

  it "should have monit alerts file" do
    Bosh::Agent::Monit.monit_alerts_file.should == @monit_alerts_file
  end

  it "should set up monit user" do
    Bosh::Agent::Monit.setup_monit_user

    File.exist?(@monit_user_file).should == true
    monit_user_data = File.read(@monit_user_file)
    monit_user_data.should match(/vcap:\S{16}/)
  end

  it "should set up monit alerts if alert processing is enabled" do
    Bosh::Agent::Config.smtp_user      = "vcap"
    Bosh::Agent::Config.smtp_password  = "pass"
    Bosh::Agent::Config.smtp_port      = 55231
    Bosh::Agent::Config.process_alerts = true

    Bosh::Agent::Monit.setup_alerts

    File.exist?(@monit_alerts_file).should == true
    monit_alert_config = File.read(@monit_alerts_file)

    monit_alert_config.should == <<-CONFIG
        set alert bosh@localhost
        set mailserver 127.0.0.1 port 55231
            username "vcap" password "pass"

        set eventqueue
            basedir #{Bosh::Agent::Monit.monit_events_dir}
            slots 5000

        set mail-format {
          from: monit@localhost
          subject: Monit Alert
          message: Service: $SERVICE
          Event: $EVENT
          Action: $ACTION
          Date: $DATE
          Description: $DESCRIPTION
        }
    CONFIG
  end

  it "should pass monit reload when incarnation is not changing" do
    Bosh::Agent::Monit.stub!(:incarnation).and_return(99,99,99,99,100)
    Bosh::Agent::Monit.reload
  end

  it "should fail when NUM_RETRY_MONIT_WAIT_INCARNATION is exceeded" do
    old_incarnations = Array.new(Bosh::Agent::Monit::NUM_RETRY_MONIT_WAIT_INCARNATION, 99)
    Bosh::Agent::Monit.stub!(:incarnation).and_return(*old_incarnations)
    lambda {
      Bosh::Agent::Monit.reload
    }.should raise_error(Bosh::Agent::StateError)
  end

  it "should fail monit reload when incarnation is not changing" do
    Bosh::Agent::Monit.stub!(:incarnation).and_return(99)
    lambda {
      Bosh::Agent::Monit.reload
    }.should raise_error(Bosh::Agent::StateError)
  end

  it "should provide monit api client" do
    http_client = mock("http_client")
    Net::HTTP.should_receive(:new).with("localhost", 2822).and_return(http_client)

    Bosh::Agent::Monit.stub!(:random_credential).and_return('foobar')

    user_file = Bosh::Agent::Monit.monit_user_file
    if File.exist?(user_file)
      FileUtils.rm(user_file)
    end
    Bosh::Agent::Monit.setup_monit_user

    response = mock("response")
    response.stub!(:code).and_return("200")

    http_client.should_receive(:request).with { |request|
      request["authorization"].should == "Basic dmNhcDpmb29iYXI="
    }.and_return(response)

    client = Bosh::Agent::Monit.monit_api_client
    client.send('service_action', 'test', 'start')
  end

end
