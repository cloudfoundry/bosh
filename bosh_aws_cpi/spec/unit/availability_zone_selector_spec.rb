require "spec_helper"

describe Bosh::AwsCloud::AvailabilityZoneSelector do

  let(:instances) { double("instances") }
  let(:region) { double("region", :instances => instances) }
  let(:selector) { described_class.new(region, "default_zone") }

  describe "#select_from_instance_id" do

    let(:instance) { double("instance", :availability_zone => "this_zone") }

    context "with existing instance" do
      it "should select the zone of the instance over a given default" do
        instances.stub(:[]).and_return(instance)
        instance.stub(:availability_zone).and_return("this_zone")

        selector.select_from_instance_id(instance).should == "this_zone"
      end
    end

    context "without existing instance" do
      it "should select the default" do
        selector.select_from_instance_id(nil).should == "default_zone"
      end
    end

  end

  describe "#common_availability_zone" do

    it "should raise an error when multiple availability zones are present" do
      expect {
        selector.common_availability_zone(["this_zone"], "other_zone", nil)
      }.to raise_error Bosh::Clouds::CloudError, "can't use multiple availability zones: this_zone, other_zone"
    end

    it "should select the common availability zone" do
      selector.common_availability_zone(["this_zone"], "this_zone", nil).should == "this_zone"
    end

    it "should return the default when no availability zone is passed" do
      selector.common_availability_zone([], nil, nil).should == "default_zone"
    end

  end
end
