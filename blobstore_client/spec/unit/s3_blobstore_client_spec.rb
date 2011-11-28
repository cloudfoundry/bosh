require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Blobstore::S3BlobstoreClient do

  before(:each) do
    @aws_mock_options = {
      :access_key_id     => "KEY",
      :secret_access_key => "SECRET",
      :use_ssl           => true,
      :port              => 443
    }
  end

  def s3_blobstore(options)
    Bosh::Blobstore::S3BlobstoreClient.new(options)
  end

  describe "options" do

    it "establishes S3 connection on creation" do
      AWS::S3::Base.should_receive(:establish_connection!).with(@aws_mock_options)

      @client = s3_blobstore("encryption_key"    => "bla",
                             "bucket_name"       => "test",
                             "access_key_id"     => "KEY",
                             "secret_access_key" => "SECRET")

      @client.encryption_key.should == "bla"
      @client.bucket_name.should == "test"
    end

    it "supports Symbol option keys too" do
      AWS::S3::Base.should_receive(:establish_connection!).with(@aws_mock_options)

      @client = s3_blobstore(:encryption_key    => "bla",
                             :bucket_name       => "test",
                             :access_key_id     => "KEY",
                             :secret_access_key => "SECRET")

      @client.encryption_key.should == "bla"
      @client.bucket_name.should == "test"
    end

    it "should raise an exception on duplicate option keys with different values" do
      lambda {
        s3_blobstore(:f => "f1", "f" => "f2")
      }.should raise_error ArgumentError, "duplicate option 'f' with different values 'f2' and 'f1'"
    end

    it "should not raise an exception on duplicate option keys with same values" do
      AWS::S3::Base.should_receive(:establish_connection!).with(@aws_mock_options)

      lambda {
        s3_blobstore(:f                 => "f",
                     "f"                => "f",
                     :access_key_id     => "KEY",
                     :secret_access_key => "SECRET")
      }.should_not raise_error
    end
  end

  describe "operations" do

    before :each do
      @client = s3_blobstore(:encryption_key    => "bla",
                             :bucket_name       => "test",
                             :access_key_id     => "KEY",
                             :secret_access_key => "SECRET")
    end

    describe "create" do

      it "should create an object" do
        encrypted_file = nil
        @client.should_receive(:generate_object_id).and_return("object_id")
        @client.should_receive(:encrypt_stream).with { |from_file, _|
          from_file.read.should eql("some content")
          true
        }.and_return {|_, to_file|
          encrypted_file = to_file
          nil
        }

        AWS::S3::S3Object.should_receive(:store).with { |key, data, bucket|
          key.should eql("object_id")
          data.path.should eql(encrypted_file.path)
          bucket.should eql("test")
          true
        }
        @client.create("some content").should eql("object_id")
      end

      it "should raise an exception when there is an error creating an object" do
        encrypted_file = nil
        @client.should_receive(:generate_object_id).and_return("object_id")
        @client.should_receive(:encrypt_stream).with { |from_file, _|
          from_file.read.should eql("some content")
          true
        }.and_return {|_, to_file|
          encrypted_file = to_file
          nil
        }

        AWS::S3::S3Object.should_receive(:store).with { |key, data, bucket|
          key.should eql("object_id")
          data.path.should eql(encrypted_file.path)
          bucket.should eql("test")
          true
        }.and_raise(AWS::S3::S3Exception.new("Epic Fail"))
        lambda {
          @client.create("some content")
        }.should raise_error(Bosh::Blobstore::BlobstoreError, "Failed to create object, S3 response error: Epic Fail")
      end

    end

    describe "fetch" do

      it "should fetch an object" do
        mock_s3_object = mock("s3_object")
        mock_s3_object.stub!(:value).and_yield("ENCRYPTED")
        AWS::S3::S3Object.should_receive(:find).with("object_id", "test").and_return(mock_s3_object)
        @client.should_receive(:decrypt_stream).with { |from, _|
          encrypted = ""
          from.call(lambda {|segment| encrypted << segment})
          encrypted.should eql("ENCRYPTED")
          true
        }.and_return {|_, to|
          to.write("stuff")
        }
        @client.get("object_id").should == "stuff"
      end

      it "should raise an exception when there is an error fetching an object" do
        AWS::S3::S3Object.should_receive(:find).with("object_id", "test").and_raise(AWS::S3::S3Exception.new("Epic Fail"))
        lambda {
          @client.get("object_id")
        }.should raise_error(Bosh::Blobstore::BlobstoreError, "Failed to find object 'object_id', S3 response error: Epic Fail")
      end

      it "should raise more specific NotFound exception when object is not found" do
        AWS::S3::S3Object.should_receive(:find).with("object_id", "test").and_raise(AWS::S3::NoSuchKey.new("NO KEY", "test"))
        lambda {
          @client.get("object_id")
        }.should raise_error(Bosh::Blobstore::BlobstoreError, "S3 object 'object_id' not found")
      end

    end

    describe "delete" do

      it "should delete an object" do
        AWS::S3::S3Object.should_receive(:delete).with("object_id", "test")
        @client.delete("object_id")
      end

      it "should raise an exception when there is an error deleting an object" do
        AWS::S3::S3Object.should_receive(:delete).with("object_id", "test").and_raise(AWS::S3::S3Exception.new("Epic Fail"))
        lambda {
          @client.delete("object_id")
        }.should raise_error(Bosh::Blobstore::BlobstoreError, "Failed to delete object 'object_id', S3 response error: Epic Fail")
      end

    end

    describe "encryption" do

      before :each do
        @from_path = File.join(Dir::tmpdir, "from-#{UUIDTools::UUID.random_create}")
        @to_path = File.join(Dir::tmpdir, "to-#{UUIDTools::UUID.random_create}")
      end

      after :each do
        FileUtils.rm_f(@from_path)
        FileUtils.rm_f(@to_path)
      end

      it "encrypt/decrypt works as long as key is the same" do
        File.open(@from_path, "w") { |f| f.write("clear text") }
        File.open(@from_path, "r") do |from|
          File.open(@to_path, "w") do |to|
            @client.send(:encrypt_stream, from, to)
          end
        end

        Base64.encode64(File.read(@to_path)).should eql("XCUKDXXzjh43DmNylgVpQQ==\n")

        File.open(@from_path, "w") { |f| f.write(File.read(@to_path)) }
        File.open(@from_path, "r") do |from|
          File.open(@to_path, "w") do |to|
            @client.send(:decrypt_stream, from, to)
          end
        end

        File.read(@to_path).should eql("clear text")
      end

      it "encrypt/decrypt doesn't have padding issues for very small inputs" do
        File.open(@from_path, "w") { |f| f.write("c") }
        File.open(@from_path, "r") do |from|
          File.open(@to_path, "w") do |to|
            @client.send(:encrypt_stream, from, to)
          end
        end

        Base64.encode64(File.read(@to_path)).should eql("S1ZnX5gPfm/rQbRCcShHSg==\n")

        File.open(@from_path, "w") { |f| f.write(File.read(@to_path)) }
        File.open(@from_path, "r") do |from|
          File.open(@to_path, "w") do |to|
            @client.send(:decrypt_stream, from, to)
          end
        end

        File.read(@to_path).should eql("c")
      end

      it "should raise an exception if incorrect encryption key is used" do
        File.open(@from_path, "w") { |f| f.write("clear text") }
        File.open(@from_path, "r") do |from|
          File.open(@to_path, "w") do |to|
            @client.send(:encrypt_stream, from, to)
          end
        end

        Base64.encode64(File.read(@to_path)).should eql("XCUKDXXzjh43DmNylgVpQQ==\n")

        client2 = s3_blobstore(:encryption_key    => "zzz",
                               :bucket_name       => "test",
                               :access_key_id     => "KEY",
                               :secret_access_key => "SECRET")

        File.open(@from_path, "w") { |f| f.write(File.read(@to_path)) }
        File.open(@from_path, "r") do |from|
          File.open(@to_path, "w") do |to|
            lambda {
              client2.send(:decrypt_stream, from, to)
            }.should raise_error(Bosh::Blobstore::BlobstoreError, "Decryption error: bad decrypt")
          end
        end
      end

    end

  end

end
