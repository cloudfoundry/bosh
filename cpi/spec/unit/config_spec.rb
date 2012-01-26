require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Clouds::Config do
  it "configure a logger" do
    Bosh::Clouds::Config.logger.should be_kind_of(Logger)
  end

  it "should configure a uuid" do
    Bosh::Clouds::Config.uuid.should be_kind_of(String)
  end

  it "should not have a db configured" do
    Bosh::Clouds::Config.db.should be_nil
  end
end
