require 'spec_helper'

describe Bhm::AlertProcessor do

  before :each do
    email_options = {
      "recipients" => [ "dude@example.com" ],
      "smtp" => {
        "from"     => "hm@example.com",
        "host"     => "smtp.example.com",
        "port"     => 587,
        "domain"   => "example.com"
      },
      "interval" => 0.1
    }

    Bhm.logger = Logging.logger(StringIO.new)
    @processor = Bhm::AlertProcessor.new
    @agent1    = Bhm::LoggingDeliveryAgent.new
    @agent2    = Bhm::EmailDeliveryAgent.new(email_options)

    @agent1.stub!(:deliver)
    @agent2.stub!(:deliver)
  end

  def make_alert(i, ts = Time.now)
    Bhm::Alert.create!(:id => i, :severity => i, :title => "Alert #{i}", :summary => "Summary #{i}", :created_at => ts)
  end

  it "registers alerts and delivery agents" do
    alert = make_alert(1)

    @processor.add_delivery_agent(@agent1)
    @processor.add_delivery_agent(@agent2)

    @agent1.should_receive(:deliver).with(alert).and_return(true)
    @agent2.should_receive(:deliver).with(alert).and_return(true)

    @processor.register_alert(alert)
  end

  it "dedups alerts that have the same id and delivers only unique alerts" do
    alert1 = make_alert(1)
    alert2 = make_alert(1)
    alert3 = make_alert(2)

    @processor.add_delivery_agent(@agent1)
    @processor.add_delivery_agent(@agent2)

    @agent1.should_receive(:deliver).with(alert1).once
    @agent1.should_receive(:deliver).with(alert3).once

    @agent2.should_receive(:deliver).with(alert1).once
    @agent2.should_receive(:deliver).with(alert3).once

    @processor.register_alert(alert1)
    @processor.register_alert(alert2)
    @processor.register_alert(alert3)

    @processor.processed_alerts_count.should == 2
  end

  it "logs and swallows delivery agent exceptions" do
    alert = make_alert(1)
    @processor.add_delivery_agent(@agent1)
    @processor.add_delivery_agent(@agent2)

    @agent1.should_receive(:deliver).with(alert).and_raise(Bhm::DeliveryAgentError.new("can't deliver, sorry man"))
    @agent2.should_receive(:deliver)

    Bhm.logger.should_receive(:error).with("Delivery agent #{@agent1} failed to process alert #{alert}: can't deliver, sorry man")
    @processor.register_alert(alert)
  end

end
