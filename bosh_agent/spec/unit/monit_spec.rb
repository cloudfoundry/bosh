# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../spec_helper'

module Bosh::Agent
  describe Monit do
    before(:each) do
      Config.smtp_port = 55231
      Monit.stub(:monit_reload_cmd)

      monit_dir = File.join(base_dir, 'monit')
      FileUtils.mkdir_p(monit_dir)

      @monit_user_file = File.join(monit_dir, 'monit.user')
      @monit_alerts_file = File.join(monit_dir, 'alerts.monitrc')
    end

    it "should have monit user file" do
      Monit.monit_user_file.should == @monit_user_file
    end

    it "should have monit alerts file" do
      Monit.monit_alerts_file.should == @monit_alerts_file
    end

    it "should set up monit user" do
      Monit.setup_monit_user

      File.exist?(@monit_user_file).should == true
      monit_user_data = File.read(@monit_user_file)
      monit_user_data.should match(/vcap:\S{16}/)
    end

    it "should set up monit alerts if alert processing is enabled" do
      Config.smtp_user      = "vcap"
      Config.smtp_password  = "pass"
      Config.smtp_port      = 55231
      Config.process_alerts = true

      Monit.setup_alerts

      File.exist?(@monit_alerts_file).should == true
      monit_alert_config = File.read(@monit_alerts_file)

      monit_alert_config.should == <<-CONFIG
        set alert bosh@localhost
        set mailserver 127.0.0.1 port 55231
            username "vcap" password "pass"

        set eventqueue
            basedir #{Monit.monit_events_dir}
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
      Monit.stub(:reload_incarnation_sleep).and_return(0.1)
      Monit.stub(:incarnation).and_return(99,99,100)
      Monit.reload
    end

    it "should fail when NUM_RETRY_MONIT_WAIT_INCARNATION is exceeded" do
      Monit.stub(:reload_incarnation_sleep).and_return(0.1)
      Monit.stub(:reload_timeout).and_return(1)

      old_incarnations = Array.new(Monit::NUM_RETRY_MONIT_WAIT_INCARNATION, 99)
      Monit.stub(:incarnation).and_return(*old_incarnations)
      lambda {
        Monit.reload
      }.should raise_error(StateError)
    end

    it "should fail monit reload when incarnation is not changing" do
      Monit.stub(:monit_reload_sleep).and_return(0.1)
      Monit.stub(:reload_timeout).and_return(1)

      Monit.stub(:incarnation).and_return(99)
      lambda {
        Monit.reload
      }.should raise_error(StateError)
    end

    it "should provide monit api client" do
      http_client = double("http_client")
      Net::HTTP.should_receive(:new).with("127.0.0.1", 2822).and_return(http_client)

      Monit.stub(:random_credential).and_return('foobar')

      user_file = Monit.monit_user_file
      if File.exist?(user_file)
        FileUtils.rm(user_file)
      end
      Monit.setup_monit_user

      response = double("response")
      response.stub(:code).and_return("200")

      http_client.should_receive(:request) { |request|
        request["authorization"].should == "Basic dmNhcDpmb29iYXI="
      }.and_return(response)

      client = Monit.monit_api_client
      client.send('service_action', 'test', 'start')
    end


    describe '#service_group_state' do

      let(:monit_api_client) { double(MonitClient) }

      before do
        monit_api_client.should_receive(:status).with(group: 'vcap').and_return status
        MonitClient.stub(new: monit_api_client)
        Monit.enable
      end

      context 'some services in init state' do
        let(:status) { {'name' => {status: {message: 'running'}, monitor: :init}} }

        it 'returns starting if any services are init state' do
          expect(Monit.service_group_state).to eq 'starting'
        end
      end

      context 'no services' do
        let(:status) { {} }

        it 'returns running if there are no services' do
          expect(Monit.service_group_state).to eq 'running'
        end
      end
    end
  end
end
