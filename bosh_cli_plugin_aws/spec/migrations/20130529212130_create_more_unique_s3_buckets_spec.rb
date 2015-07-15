require 'spec_helper'
require '20130529212130_create_more_unique_s3_buckets'

describe CreateMoreUniqueS3Buckets do

  let(:config) { {'aws' => {}, 'name' => 'dev102', 'vpc' => {'domain' => 'dev102.cf.com'}} }
  let(:subject) { described_class.new(config,'') }
  let(:mock_s3) { double("Bosh::AwsCliPlugin::S3").as_null_object }

  before do
    allow(Bosh::AwsCliPlugin::S3).to receive(:new).and_return(mock_s3)
  end

  context "when the old and new buckets have the same name" do
    it "should not do anything" do
      config['vpc']['domain'] = 'run.pivotal.io'
      config['name'] = 'run-pivotal-io'
      expect(mock_s3).not_to receive :create_bucket
      expect(mock_s3).not_to receive :move_bucket
      expect(mock_s3).not_to receive :delete_bucket

      subject.execute
    end
  end

  context "when old buckets exists" do
    before do
      expect(mock_s3).to receive(:bucket_exists?).with("dev102-bosh-blobstore").and_return(true)
      expect(mock_s3).to receive(:bucket_exists?).with("dev102-cf-com-bosh-artifacts").and_return(true)
      allow(mock_s3).to receive(:move_bucket)
      allow(mock_s3).to receive(:delete_bucket)
    end

    it "should create the buckets" do
      expect(mock_s3).not_to receive(:create_bucket).with("dev102-cf-com-bosh-artifacts")
      expect(mock_s3).not_to receive(:create_bucket).with("dev102-cf-com-bosh-blobstore")
      subject.execute
    end

    it "should copy the existing bucket content" do
      expect(mock_s3).to receive(:move_bucket).with("dev102-bosh-blobstore", "dev102-cf-com-bosh-blobstore").ordered
      expect(mock_s3).to receive(:move_bucket).with("dev102-bosh-artifacts", "dev102-cf-com-bosh-artifacts").ordered
      subject.execute
    end

    it "should remove the old buckets" do
      expect(mock_s3).to receive(:delete_bucket).with("dev102-bosh-blobstore").ordered
      expect(mock_s3).to receive(:delete_bucket).with("dev102-bosh-artifacts").ordered
      subject.execute
    end
  end

  context "when old buckets don't exist" do

    before do
      expect(mock_s3).to receive(:bucket_exists?).with("dev102-bosh-blobstore").and_return(false)
      expect(mock_s3).to receive(:bucket_exists?).with("dev102-bosh-artifacts").and_return(false)
      expect(mock_s3).to receive(:bucket_exists?).with("dev102-cf-com-bosh-blobstore").and_return(false)
      expect(mock_s3).to receive(:bucket_exists?).with("dev102-cf-com-bosh-artifacts").and_return(false)
    end

    it "should create the buckets" do
      expect(mock_s3).to receive(:create_bucket).with("dev102-cf-com-bosh-blobstore").ordered
      expect(mock_s3).to receive(:create_bucket).with("dev102-cf-com-bosh-artifacts").ordered
      subject.execute
    end

    it "should not copy the existing bucket content" do
      expect(mock_s3).not_to receive(:move_bucket)
      subject.execute
    end

    it "should not remove the old buckets" do
      expect(mock_s3).not_to receive(:delete_bucket)
      subject.execute
    end
  end
end
