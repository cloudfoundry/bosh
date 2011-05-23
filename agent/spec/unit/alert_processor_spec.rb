require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::AlertProcessor do

  before(:each) do
    log     = StringIO.new
    @logger = Logger.new(log)
    @port   = 54321

    @smtp_user     = "zb"
    @smtp_password = "zb"

    Bosh::Agent::Config.logger = @logger
    @processor = Bosh::Agent::AlertProcessor.new("localhost", @port, @smtp_user, @smtp_password)
  end

  it "receives alerts via built-in SMTP based server" do
    EM.run do
      # TODO: clean this timer up by also stopping event loop from process_email_alert
      # itself (possibly using alias method chain is some test helper)
      EM.add_timer(0.2) { EM.stop }

      outgoing_email = {
        :host   => "localhost",
        :port   => @port,
        :auth   => {
          :type     => :plain,
          :username => @smtp_user,
          :password => @smtp_password
        },
        :domain => "local",
        :from   => "zb@local",
        :to     => "zb@local",
        :body   => "Test alert",
        :header => {
          "Subject" => "Test Alert"
        }
      }

      @processor.start
      @processor.should_receive(:process_email_alert).with("Subject: Test Alert\n\nTest alert")

      EM::Protocols::SmtpClient.send(outgoing_email)
    end
  end

  it "creates agent alerts from email alerts" do
    email_body = <<-EMAIL
    Message-id: <1304319946.0@localhost>
    Service: nats
    Event: does not exist
    Action: restart
    Date: Sun, 22 May 2011 20:07:41 +0500
    Description: process is not running
    EMAIL

    alert = @processor.create_alert_from_email(email_body)

    alert.id.should          == "1304319946.0"
    alert.service.should     == "nats"
    alert.event.should       == "does not exist"
    alert.action.should      == "restart"
    alert.timestamp.should   == 1306076861
    alert.description.should == "process is not running"
  end

  it "creates agent alerts with partial data" do
    email_body = <<-EMAIL
    Message-id: <1304319946.0@localhost>
    Date: Sun, 22 May 2011 20:07:41 +0500
    Description: process is not running
    EMAIL

    alert = @processor.create_alert_from_email(email_body)

    alert.id.should          == "1304319946.0"
    alert.service.should     == nil
    alert.event.should       == nil
    alert.action.should      == nil
    alert.timestamp.should   == 1306076861
    alert.description.should == "process is not running"
  end

end
