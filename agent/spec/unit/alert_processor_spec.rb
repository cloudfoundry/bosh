require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::AlertProcessor do

  before(:each) do
    log     = StringIO.new
    @logger = Logger.new(log)
    @port   = 54321

    @smtp_user     = "zb"
    @smtp_password = "zb"

    Bosh::Agent::Config.logger = @logger
  end

  it "receives alerts via built-in SMTP based server" do
    processor = Bosh::Agent::AlertProcessor.new("localhost", @port, @smtp_user, @smtp_password)

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

      processor.start
      processor.should_receive(:process_email_alert).with("Subject: Test Alert\n\nTest alert")

      EM::Protocols::SmtpClient.send(outgoing_email)
    end
  end

end
