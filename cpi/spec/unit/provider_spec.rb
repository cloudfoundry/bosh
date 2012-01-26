require File.expand_path("../../spec_helper", __FILE__)
$:.unshift(File.expand_path("../../lib", __FILE__))

describe Bosh::Clouds::Provider do
  it "should create a provider instance" do

    provider = Bosh::Clouds::Provider.create("spec", {})
    provider.should be_kind_of(Bosh::Clouds::Spec)

  end

  it "should fail to create an invalid provider" do

    lambda {
      Bosh::Clouds::Provider.create("enoent", {})
    }.should raise_error(Bosh::Clouds::CloudError)

  end
end
