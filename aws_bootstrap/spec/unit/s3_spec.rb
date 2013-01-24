require 'spec_helper'

describe Bosh::Aws::S3 do
  it "can empty and delete all buckets" do
    fake_aws_s3 = mock("aws_s3")
    fake_bucket = mock("bucket")

    ::AWS::S3.stub(:new).with("creds").and_return(fake_aws_s3)
    fake_aws_s3.stub(:buckets).and_return([fake_bucket])

    fake_bucket.should_receive(:delete!)

    described_class.new("creds").empty
  end

  it "can list the names of the buckets" do
    fake_aws_s3 = mock("aws_s3")

    ::AWS::S3.stub(:new).with("creds").and_return(fake_aws_s3)
    fake_aws_s3.stub(:buckets).and_return([mock("bucket", name: "buckets of fun"),
                                           mock("bucket", name: "barrel of monkeys")])

    described_class.new("creds").bucket_names.should =~ ["buckets of fun", "barrel of monkeys"]
  end
end