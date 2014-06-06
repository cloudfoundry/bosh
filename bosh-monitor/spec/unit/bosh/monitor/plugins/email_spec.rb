require 'spec_helper'

describe Bhm::Plugins::Email do

  before :each do
    Bhm.logger = Logging.logger(StringIO.new)

    @smtp_options = {
      "from"     => "hm@example.com",
      "host"     => "smtp.example.com",
      "port"     => 587,
      "user"     => "usr",
      "password" => "pwd",
      "auth"     => "plain",
      "domain"   => "example.com"
    }

    @options = {
      "recipients" => [ "dude@vmware.com", "dude2@vmware.com" ],
      "smtp"       => @smtp_options,
      "interval"   => 0.1
    }

    @plugin = Bhm::Plugins::Email.new(@options)
  end

  it "validates options" do
    valid_options = {
      "recipients" => [ "olegs@vmware.com" ],
      "smtp" => {
        "from"     => "hm@example.com",
        "host"     => "smtp.example.com",
        "port"     => 587,
        "user"     => "usr",
        "password" => "pwd",
        "auth"     => "plain",
        "domain"   => "example.com"
      }
    }

    invalid_options = {
      "a" => "b",
      "c" => "d"
    }

    Bhm::Plugins::Email.new(valid_options).validate_options.should be(true)
    Bhm::Plugins::Email.new(invalid_options).validate_options.should be(false)
  end

  it "doesn't start if event loop isn't running" do
    @plugin.run.should be(false)
  end

  it "has a list of recipients and smtp options" do
    @plugin.recipients.should == [ "dude@vmware.com", "dude2@vmware.com" ]
    @plugin.smtp_options.should == @smtp_options
  end

  it "queues up messages for delivery" do
    @plugin.should_not_receive(:send_email_async)

    10.times do |i|
      @plugin.process(Bhm::Events::Base.create!(:alert, alert_payload))
      @plugin.process(Bhm::Events::Base.create!(:heartbeat, heartbeat_payload))
    end

    @plugin.queue_size(:alert).should == 10
    @plugin.queue_size(:heartbeat).should == 10
  end

  it "processes queues when requested" do
    alerts = [ ]

    3.times do
      alert = Bhm::Events::Base.create!(:alert, alert_payload)
      alerts << alert
      @plugin.process(alert)
    end

    heartbeats = [ Bhm::Events::Base.create!(:heartbeat, heartbeat_payload) ]
    @plugin.process(heartbeats[0])

    alert_email_body = alerts.map{ |alert| alert.to_plain_text }.join("\n") + "\n"
    heartbeat_email_body = heartbeats.map{ |hb| hb.to_plain_text }.join("\n") + "\n"

    @plugin.should_receive(:send_email_async).with("3 alerts from BOSH Health Monitor", alert_email_body).once.and_return(true)
    @plugin.should_receive(:send_email_async).with("1 heartbeat from BOSH Health Monitor", heartbeat_email_body).once.and_return(true)
    @plugin.process_queues
  end

  it "processes queue asynchronously when running" do
    @plugin.stub(:send_email_async)

    20.times do |i|
      @plugin.process(Bhm::Events::Base.create!(:heartbeat, heartbeat_payload))
      @plugin.process(Bhm::Events::Base.create!(:alert, alert_payload))
    end

    @plugin.queue_size(:alert).should == 20
    @plugin.queue_size(:heartbeat).should == 20

    EM.run do
      EM.add_timer(0.2) { EM.stop } # Need to wait at least a tick to drain queue
      @plugin.run
    end

    @plugin.queue_size(:alert).should == 0
    @plugin.queue_size(:heartbeat).should == 0
  end

end
