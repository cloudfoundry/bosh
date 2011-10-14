require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::NTP do
  def asset(file)
    File.expand_path("../../assets/#{file}", __FILE__)
  end

  it "should load time offset from ntpdate output" do
    Bosh::Agent::NTP.offset(asset("ntpdate.out")).should ==
      {"offset" => "-0.081236", "timestamp" => "12 Oct 17:37:58"}
  end

  it "should be nil when the file is bogus" do
    Bosh::Agent::NTP.offset(asset("ntpdate.bad")).should ==
      {"message" => Bosh::Agent::NTP::BAD_CONTENTS}
  end

  it "should be nil when the file is bogus" do
    Bosh::Agent::NTP.offset(asset("ntpdate.bad-server")).should ==
      {"message" => Bosh::Agent::NTP::BAD_SERVER}
  end

  it "should be nil when file is missing" do
    Bosh::Agent::NTP.offset.should ==
      {"message" => Bosh::Agent::NTP::FILE_MISSING}
  end
end
