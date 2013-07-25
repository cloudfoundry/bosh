require "spec_helper"

describe Bosh::Aws::Migration do
  let(:config) do
    {"aws" => {}}
  end

  let(:s3) { double("S3") }
  let(:receipt) do
    {"hello" => "world"}
  end

  before do
    Bosh::Aws::S3.stub(new: s3)
  end

  around do |example|
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        example.run
      end
    end
  end

  it "saves receipts in s3" do
    s3.should_receive(:upload_to_bucket).with("bucket", "receipts/aws_dummy_receipt.yml", YAML.dump(receipt))

    migration = described_class.new(config, 'bucket')
    migration.save_receipt("aws_dummy_receipt", receipt)
  end

  it "saves receipts in the local filesystem" do
    s3.stub(:upload_to_bucket)

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        migration = described_class.new(config, 'bucket')
        migration.save_receipt("aws_dummy_receipt", receipt)

        receipt_contents = YAML.load_file("aws_dummy_receipt.yml")
        receipt_contents.should == receipt
      end
    end
  end

  it "loads the receipt from S3" do
    s3.should_receive(:fetch_object_contents).with("bucket", "receipts/aws_dummy_receipt.yml").and_return(YAML.dump(receipt))

    migration = described_class.new(config, 'bucket')
    migration.load_receipt("aws_dummy_receipt").should == receipt
  end

  it "initializes AWS helpers" do
    elb = double("ELB")
    ec2 = double("EC2")
    route53 = double("Route53")

    Bosh::Aws::S3.should_receive(:new).with(config["aws"]).and_return(s3)
    Bosh::Aws::ELB.should_receive(:new).with(config["aws"]).and_return(elb)
    Bosh::Aws::EC2.should_receive(:new).with(config["aws"]).and_return(ec2)
    Bosh::Aws::Route53.should_receive(:new).with(config["aws"]).and_return(route53)

    migration = described_class.new(config, 'bucket')
    migration.ec2.should == ec2
    migration.s3.should == s3
    migration.elb.should == elb
    migration.route53.should == route53
    migration.logger.should_not be_nil
  end
end