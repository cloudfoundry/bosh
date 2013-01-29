require "spec_helper"

describe Bosh::AwsCloud::AKIPicker do
  let(:akis) {
    [
      double("image-1", :root_device_name => "/dev/sda1",
             :image_location => "pv-grub-hd00_1.03-x86_64.gz",
             :image_id => "aki-b4aa75dd"),
      double("image-2", :root_device_name => "/dev/sda1",
             :image_location => "pv-grub-hd00_1.02-x86_64.gz",
             :image_id => "aki-b4aa75d0")
    ]
  }
  let(:logger) {double("logger", :info => nil)}
  let(:picker) {Bosh::AwsCloud::AKIPicker.new(double("ec2"))}

  it "should pick the AKI with the highest version" do
    picker.should_receive(:logger).and_return(logger)
    picker.should_receive(:fetch_akis).and_return(akis)
    picker.pick("x86_64", "/dev/sda1").should == "aki-b4aa75dd"
  end

  it "should raise an error when it can't pick an AKI" do
    picker.should_receive(:fetch_akis).and_return(akis)
    expect {
      picker.pick("foo", "bar")
    }.to raise_error Bosh::Clouds::CloudError, "unable to find AKI"
  end
end
