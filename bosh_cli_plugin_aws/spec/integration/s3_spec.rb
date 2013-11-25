require "spec_helper"

describe "S3 buckets integration test", s3_credentials: true do
  let(:credentials) do
    {
        access_key_id: ENV['BOSH_AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['BOSH_AWS_SECRET_ACCESS_KEY']
    }
  end

  subject(:s3) { Bosh::Aws::S3.new(credentials) }
  let(:bucket_name) { "bosh-bucket-test-#{Time.now.to_i}" }
  let(:another_bucket_name) { "bosh-another-bucket-test-#{Time.now.to_i}" }
  let(:file) { StringIO.new("hello friends") }

  context "buckets" do
    it "creates, lists, copies, and deletes buckets" do
      s3.bucket_exists?(bucket_name).should be(false)
      s3.create_bucket(bucket_name)
      s3.create_bucket(another_bucket_name)

      s3.bucket_exists?(bucket_name).should be(true)
      s3.bucket_names.should include(bucket_name)

      s3.fetch_object_contents(bucket_name, "file.txt").should be_nil

      s3.upload_to_bucket(bucket_name, "file.txt", file)

      s3.objects_in_bucket(bucket_name).should include("file.txt")
      s3.fetch_object_contents(bucket_name, "file.txt").should == "hello friends"

      s3.move_bucket(bucket_name, another_bucket_name)
      s3.objects_in_bucket(another_bucket_name).should include("file.txt")
      s3.fetch_object_contents(another_bucket_name, "file.txt").should == "hello friends"
      s3.objects_in_bucket(bucket_name).should_not include("file.txt")

      Dir.mktmpdir do |dir|
        file = s3.copy_remote_file(another_bucket_name, "file.txt", File.join(dir, "new_file.txt"))
        file.read.should == "hello friends"
      end

      expect { s3.copy_remote_file(another_bucket_name, "bad_file_name.txt", "new_file.txt")}.to raise_error(Exception, "Can't find bad_file_name.txt in bucket #{another_bucket_name}")

      s3.delete_bucket(bucket_name)
      s3.delete_bucket(bucket_name)
      s3.delete_bucket(another_bucket_name)

      bucket_exists = true

      1.upto(10) do
        bucket_exists = s3.bucket_exists?(bucket_name)
        break unless bucket_exists
        sleep 0.5
      end

      bucket_exists.should be(false)

      s3.bucket_names.should_not include(bucket_name)
    end
  end

  before :all do
    WebMock.allow_net_connect!
  end

  after do
    s3.delete_bucket(bucket_name)
  end

  after :all do
    WebMock.disable_net_connect!
  end
end
