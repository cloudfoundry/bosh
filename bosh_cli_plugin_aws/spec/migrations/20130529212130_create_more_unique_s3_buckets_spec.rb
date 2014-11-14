require 'spec_helper'
require '20130529212130_create_more_unique_s3_buckets'

describe CreateMoreUniqueS3Buckets do

  let(:config) { {'aws' => {}, 'name' => 'dev102', 'vpc' => {'domain' => 'dev102.cf.com'}} }
  let(:subject) { described_class.new(config,'') }
  let(:mock_s3) { double("Bosh::Aws::S3").as_null_object }

  before do
    Bosh::Aws::S3.stub(:new).and_return(mock_s3)
  end

  context "when the old and new buckets have the same name" do
    it "should not do anything" do
      config['vpc']['domain'] = 'run.pivotal.io'
      config['name'] = 'run-pivotal-io'
      mock_s3.should_not_receive :create_bucket
      mock_s3.should_not_receive :move_bucket
      mock_s3.should_not_receive :delete_bucket

      subject.execute
    end
  end

  context "when old buckets exists" do
    before do
      mock_s3.should_receive(:bucket_exists?).with("dev102-bosh-blobstore").and_return(true)
      mock_s3.should_receive(:bucket_exists?).with("dev102-cf-com-bosh-artifacts").and_return(true)
      mock_s3.stub(:move_bucket)
      mock_s3.stub(:delete_bucket)
    end

    it "should create the buckets" do
      mock_s3.should_not_receive(:create_bucket).with("dev102-cf-com-bosh-artifacts")
      mock_s3.should_not_receive(:create_bucket).with("dev102-cf-com-bosh-blobstore")
      subject.execute
    end

    it "should copy the existing bucket content" do
      mock_s3.should_receive(:move_bucket).with("dev102-bosh-blobstore", "dev102-cf-com-bosh-blobstore").ordered
      mock_s3.should_receive(:move_bucket).with("dev102-bosh-artifacts", "dev102-cf-com-bosh-artifacts").ordered
      subject.execute
    end

    it "should remove the old buckets" do
      mock_s3.should_receive(:delete_bucket).with("dev102-bosh-blobstore").ordered
      mock_s3.should_receive(:delete_bucket).with("dev102-bosh-artifacts").ordered
      subject.execute
    end
  end

  context "when old buckets don't exist" do

    before do
      mock_s3.should_receive(:bucket_exists?).with("dev102-bosh-blobstore").and_return(false)
      mock_s3.should_receive(:bucket_exists?).with("dev102-bosh-artifacts").and_return(false)
      mock_s3.should_receive(:bucket_exists?).with("dev102-cf-com-bosh-blobstore").and_return(false)
      mock_s3.should_receive(:bucket_exists?).with("dev102-cf-com-bosh-artifacts").and_return(false)
    end

    it "should create the buckets" do
      mock_s3.should_receive(:create_bucket).with("dev102-cf-com-bosh-blobstore").ordered
      mock_s3.should_receive(:create_bucket).with("dev102-cf-com-bosh-artifacts").ordered
      subject.execute
    end

    it "should not copy the existing bucket content" do
      mock_s3.should_not_receive(:move_bucket)
      subject.execute
    end

    it "should not remove the old buckets" do
      mock_s3.should_not_receive(:delete_bucket)
      subject.execute
    end
  end
end
