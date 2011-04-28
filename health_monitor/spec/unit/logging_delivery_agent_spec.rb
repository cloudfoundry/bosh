require 'spec_helper'

describe Bhm::LoggingDeliveryAgent do

  def make_alert(i, ts = Time.now)
    Bhm::Alert.create!(:id => i, :severity => i, :title => "Server is down", :summary => "Something happened", :created_at => ts)
  end

  before :each do
    Bhm.logger = Logging.logger(StringIO.new)
    @options   = { }
    @agent     = Bhm::LoggingDeliveryAgent.new(@options)
  end

  it "logs the alert" do
    ts = Time.now

    alert_fmt = "Alert #1 (#{ts.utc}, severity 1): [Server is down] Something happened"

    Bhm.logger.should_receive(:info).with("Alert: #{alert_fmt}")
    @agent.deliver(make_alert(1, ts))
  end

end

