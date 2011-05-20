require 'spec_helper'

describe Bhm::AlertProcessor do

  it "has a set of available delivery agents" do
    Bhm::AlertProcessor.agent_available?(:logger).should be_true
    Bhm::AlertProcessor.agent_available?(:email).should be_true
    Bhm::AlertProcessor.agent_available?(:foo).should be_false
  end

  it "finds agent implementations" do
    Bhm::AlertProcessor.find_agent(:logger).should be_kind_of(Bhm::LoggingDeliveryAgent)
  end

  it "finds email plugin and validates its options" do
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

    Bhm::AlertProcessor.find_agent(:email, valid_options).should be_kind_of(Bhm::EmailDeliveryAgent)

    lambda {
      Bhm::AlertProcessor.find_agent(:email, invalid_options)
    }.should raise_error(Bhm::DeliveryAgentError, "Invalid options for `Bosh::HealthMonitor::EmailDeliveryAgent'")
  end

end
