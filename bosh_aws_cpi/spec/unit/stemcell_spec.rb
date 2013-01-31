require 'spec_helper'

describe Bosh::AwsCloud::Stemcell do
  describe ".find" do
    it "should return an AMI if given an id for an existing one" do
      fake_aws_ami = double("image", exists?: true)
      region = double("region", images: {'ami-exists' => fake_aws_ami})
      described_class.find(region, "ami-exists").aws_ami.should == fake_aws_ami
    end

    it "should raise an error if no AMI exists with the given id" do
      fake_aws_ami = double("image", exists?: false)
      region = double("region", images: {'ami-doesntexist' => fake_aws_ami})
      expect {
        described_class.find(region, "ami-doesntexist")
      }.to raise_error Bosh::Clouds::CloudError, "could not find AMI ami-doesntexist"
    end
  end
end