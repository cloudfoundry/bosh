require 'spec_helper'

describe Bhm::AlertProcessor do

  it "has a set of available plugins" do
    Bhm::AlertProcessor.plugin_available?(:silent).should be_true
    Bhm::AlertProcessor.plugin_available?(:email).should be_true
    Bhm::AlertProcessor.plugin_available?(:foo).should be_false
  end

  it "finds silent plugin implementation" do
    Bhm::AlertProcessor.find(:silent).should be_kind_of(Bhm::SilentAlertProcessor)
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

    Bhm::AlertProcessor.find(:email, valid_options).should be_kind_of(Bhm::EmailAlertProcessor)

    lambda {
      Bhm::AlertProcessor.find(:email, invalid_options)
    }.should raise_error(Bhm::AlertProcessingError, "Invalid options for `Bosh::HealthMonitor::EmailAlertProcessor'")
  end

end
