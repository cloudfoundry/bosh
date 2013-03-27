require "spec_helper"

describe Bosh::Aws::MicroBoshBootstrap do
  let(:bootstrap) { described_class.new(nil, nil) }


  describe "micro_ami" do
    context "when the environment provides an override AMI" do
      before(:all) do
        ENV["BOSH_OVERRIDE_MICRO_STEMCELL_AMI"] = 'ami-tgupta'
      end

      after(:all) do
        ENV.delete "BOSH_OVERRIDE_MICRO_STEMCELL_AMI"
      end

      it "uses the given AMI" do
        bootstrap.micro_ami.should == 'ami-tgupta'
      end
    end

    context "when the environment does not provide an override AMI" do
      before do
        Net::HTTP.should_receive(:get).with("bosh-jenkins-artifacts.s3.amazonaws.com", "/last_successful_micro-bosh-stemcell_ami").and_return("ami-david")
      end

      it "returns the content from S3" do
        bootstrap.micro_ami.should == "ami-david"
      end
    end
  end
end