require 'spec_helper'

describe Bhm::PagerdutyDeliveryAgent do

  before :each do
    @options = {
      "service_key" => "mypants"
    }

    @agent = Bhm::PagerdutyDeliveryAgent.new(@options)
  end

  it "validates options" do
    valid_options = {
      "service_key" => "zb512",
      "http_proxy"  => "http://nowhere.com:3128"
    }

    invalid_options = { # no service key
      "http_proxy"  => "http://nowhere.com:3128"
    }

    Bhm::PagerdutyDeliveryAgent.new(valid_options).validate_options.should be_true
    Bhm::PagerdutyDeliveryAgent.new(invalid_options).validate_options.should be_false
  end

  it "formats alert description and data" do
    ts = Time.now

    attrs = {
      :id         => "1045",
      :severity   => 2,
      :title      => "process is not running",
      :summary    => "Summary",
      :created_at => ts,
      :source     => "mycloud: mysql_node (5)"
    }
    alert = Bhm::Alert.create!(attrs)

    @agent.format_alert_description(alert).should == "Severity 2: mycloud: mysql_node (5) process is not running"

    @agent.format_alert_data(alert).should == {
      :summary    => "Summary",
      :created_at => ts.utc
    }
  end

end
