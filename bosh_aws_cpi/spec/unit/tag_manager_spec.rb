require "spec_helper"

describe Bosh::AwsCloud::TagManager do
  let(:instance) { double("instance") }

  it "should trim key and value length" do
    instance.should_receive(:add_tag) do |key, options|
      key.size.should == 127
      options[:value].size.should == 255
    end

    Bosh::AwsCloud::TagManager.tag(instance, "x"*128, "y"*256)
  end

end
