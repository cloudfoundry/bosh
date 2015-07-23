require "spec_helper"

describe Bosh::AwsCliPlugin::Migration do
  let(:config) do
    {"aws" => {}}
  end

  let(:s3) { double("S3") }
  let(:receipt) do
    {"hello" => "world"}
  end

  before do
    allow(Bosh::AwsCliPlugin::S3).to receive_messages(new: s3)
  end

  around do |example|
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        example.run
      end
    end
  end

  it "saves receipts in s3" do
    expect(s3).to receive(:upload_to_bucket).with("bucket", "receipts/aws_dummy_receipt.yml", YAML.dump(receipt))

    migration = described_class.new(config, 'bucket')
    migration.save_receipt("aws_dummy_receipt", receipt)
  end

  it "saves receipts in the local filesystem" do
    allow(s3).to receive(:upload_to_bucket)

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        migration = described_class.new(config, 'bucket')
        migration.save_receipt("aws_dummy_receipt", receipt)

        receipt_contents = YAML.load_file("aws_dummy_receipt.yml")
        expect(receipt_contents).to eq(receipt)
      end
    end
  end

  it "loads the receipt from S3" do
    expect(s3).to receive(:fetch_object_contents).with("bucket", "receipts/aws_dummy_receipt.yml").and_return(YAML.dump(receipt))

    migration = described_class.new(config, 'bucket')
    expect(migration.load_receipt("aws_dummy_receipt")).to eq(receipt)
  end

  it "initializes AWS helpers" do
    elb = double("ELB")
    ec2 = double("EC2")
    route53 = double("Route53")

    expect(Bosh::AwsCliPlugin::S3).to receive(:new).with(config["aws"]).and_return(s3)
    expect(Bosh::AwsCliPlugin::ELB).to receive(:new).with(config["aws"]).and_return(elb)
    expect(Bosh::AwsCliPlugin::EC2).to receive(:new).with(config["aws"]).and_return(ec2)
    expect(Bosh::AwsCliPlugin::Route53).to receive(:new).with(config["aws"]).and_return(route53)

    migration = described_class.new(config, 'bucket')
    expect(migration.ec2).to eq(ec2)
    expect(migration.s3).to eq(s3)
    expect(migration.elb).to eq(elb)
    expect(migration.route53).to eq(route53)
    expect(migration.logger).not_to be_nil
  end
end
