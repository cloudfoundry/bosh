require 'spec_helper'

describe Bhm::EmailDeliveryAgent do

  before :each do
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

    @agent = Bhm::EmailDeliveryAgent.new(@options)
  end

  def make_alert(i, ts = Time.now)
    Bhm::Alert.create!(:id => i, :severity => i, :title => "Alert #{i}", :summary => "Summary #{i}", :created_at => ts)
  end

  it "doesn't start if event loop isn't running" do
    lambda {
      @agent.run
    }.should raise_error Bhm::DeliveryAgentError, "Email delivery agent can only be started when event loop is running"
  end

  it "has a list of recipients and smtp options" do
    @agent.recipients.should == [ "dude@vmware.com", "dude2@vmware.com" ]
    @agent.smtp_options.should == @smtp_options
  end

  it "formats alert as an email" do
    ts = Time.now

    alert_attrs = {
      :id         => "34",
      :severity   => 1,
      :title      => "Test Alert",
      :summary    => "Something happened",
      :created_at => ts
    }

    alert = Bhm::Alert.create!(alert_attrs)

    @agent.formatted_alert(alert).should == <<-TEXT
Test Alert
Severity: 1
Summary: Something happened
Time: #{ts.utc}
    TEXT
  end

  it "queues up messages for delivery" do
    @agent.should_not_receive(:send_email)
    10.times do |i|
      @agent.deliver(make_alert(i))
    end
    @agent.queue_size.should == 10
  end

  it "processes queue when requested" do
    ts = Time.now

    3.times do |i|
      @agent.deliver(make_alert(i + 1, ts + i))
    end

    email_body = <<-EMAIL
Alert 1
Severity: 1
Summary: Summary 1
Time: #{(ts).utc}

Alert 2
Severity: 2
Summary: Summary 2
Time: #{(ts + 1).utc}

Alert 3
Severity: 3
Summary: Summary 3
Time: #{(ts + 2).utc}

    EMAIL

    @agent.should_receive(:send_email).with("3 alerts from Bosh Health Monitor", email_body).once.and_return(true)
    @agent.process_queue
  end

  it "utilizes processes queue asynchronously when running" do
    @agent.stub!(:send_email)
    ts = Time.now
    20.times do |i|
      @agent.deliver(make_alert(i + 1, ts + i))
    end

    @agent.queue_size.should == 20

    EM.run do
      EM.add_timer(0.5) { EM.stop }
      @agent.run
    end

    @agent.queue_size.should == 0
  end

end
