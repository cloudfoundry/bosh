require 'spec_helper'

describe Bosh::Aws::S3 do
  let(:fake_aws_s3) { mock("aws_s3") }

  before do
    ::AWS::S3.stub(:new).with("creds").and_return(fake_aws_s3)
  end

  subject do
    described_class.new("creds")
  end

  it "can empty and delete all buckets" do
    fake_bucket = mock("bucket")

    fake_aws_s3.stub(:buckets).and_return([fake_bucket])

    fake_bucket.should_receive(:delete!)

    subject.empty
  end

  it "can list the names of the buckets" do
    fake_buckets = [mock("bucket", name: "buckets of fun"),
                    mock("bucket", name: "barrel of monkeys")]

    fake_aws_s3.stub(:buckets).and_return(fake_buckets)

    subject.bucket_names.should =~ ["buckets of fun", "barrel of monkeys"]
  end

  it "can create a new bucket" do
    fake_buckets = mock("buckets")

    fake_aws_s3.stub(:buckets).and_return(fake_buckets)

    fake_buckets.should_receive(:create).with("bucket_name")

    subject.create_bucket("bucket_name")
  end
end
