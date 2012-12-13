require  'spec_helper'

describe Bosh::Blobstore::S3BlobstoreClient do

  def s3_blobstore(options)
    @s3 = double(AWS::S3)
    AWS::S3.stub(:new).and_return(@s3)
    Bosh::Blobstore::S3BlobstoreClient.new(options)
  end

  describe "options" do
    it "should support symbols as option keys" do
      options = {:bucket_name       => "test",
                 :access_key_id     => "KEY",
                 :secret_access_key => "SECRET"}

      s3_blobstore(options).bucket_name.should == "test"
    end
    it "should support strings as option keys" do
      options = {"bucket_name"       => "test",
                 "access_key_id"     => "KEY",
                 "secret_access_key" => "SECRET"}

      s3_blobstore(options).bucket_name.should == "test"
    end

    it "should raise an error if using simple and encryption" do
      options = {"bucket_name"       => "test",
                 "encryption_key"    => "KEY"}
      expect {
        s3_blobstore(options)
      }.to raise_error Bosh::Blobstore::BlobstoreError,
                       "can't use read-only with an encryption key"
    end
  end

  describe "create" do
    context "encrypted" do
      let(:options) {
        {:bucket_name       => "test",
         :access_key_id     => "KEY",
         :secret_access_key => "SECRET",
         :encryption_key => "kjahsdjahsgdlahs"}
      }
      let(:client) { s3_blobstore(options) }

      it "should encrypt" do
        client.should_receive(:encrypt_file).and_call_original
        client.should_receive(:store_in_s3)
        client.create("foobar")
      end
    end

    context "unencrypted" do
      let(:options) {
        {:bucket_name       => "test",
         :access_key_id     => "KEY",
         :secret_access_key => "SECRET"}
      }
      let(:client) { s3_blobstore(options) }

      it "should not encrypt when key is missing" do
        client.should_not_receive(:encrypt_file)
        client.should_receive(:store_in_s3)
        client.create("foobar")
      end

      it "should take a string as argument" do
        client.should_receive(:store_in_s3)
        client.create("foobar")
      end

      it "should take a file as argument" do
        client.should_receive(:store_in_s3)
        file = File.open(asset("file"))
        client.should_receive(:create_file).with(file).and_call_original
        client.create(file)
      end
    end
  end

  describe "get" do
    let(:options) {
      {:bucket_name       => "test",
       :access_key_id     => "KEY",
       :secret_access_key => "SECRET"}
    }
    let(:client) { s3_blobstore(options) }

    it "should raise an error if the object is missing" do
      client.stub(:get_from_s3).and_raise AWS::S3::Errors::NoSuchKey.new(nil, nil)
      expect {
        client.get("missing-oid")
      }.to raise_error Bosh::Blobstore::BlobstoreError
    end

    context "encrypted" do
      let(:options) {
        {:bucket_name       => "test",
         :access_key_id     => "KEY",
         :secret_access_key => "SECRET",
         :encryption_key => "asdasdasd"}
      }

      it "should get an object" do
        pending "requires refactoring of get_file"
      end
    end

    context "unencrypted" do
      it "should get an object" do
        blob = double("blob")
        blob.should_receive(:read).and_yield("foooo")
        client.should_receive(:get_from_s3).and_return(blob)
        client.get("foooo").should == "foooo"
      end
    end
  end

  describe "delete" do
    it "should delete an object" do
      options = {:encryption_key    => "bla",
                 :bucket_name       => "test",
                 :access_key_id     => "KEY",
                 :secret_access_key => "SECRET"}
      client = s3_blobstore(options)
      blob = double("blob", :exists? => true)

      client.should_receive(:get_from_s3).with("fake-oid").and_return(blob)
      blob.should_receive(:delete)
      client.delete("fake-oid")
    end

    it "should raise an error when the object is missing" do
      options = {:encryption_key    => "bla",
                 :bucket_name       => "test",
                 :access_key_id     => "KEY",
                 :secret_access_key => "SECRET"}
      client = s3_blobstore(options)
      blob = double("blob", :exists? => false)

      client.should_receive(:get_from_s3).with("fake-oid").and_return(blob)
      expect {
        client.delete("fake-oid")
      }.to raise_error Bosh::Blobstore::BlobstoreError, "no such object: fake-oid"
    end
  end
end

__END__

  describe "options" do

    it "establishes S3 connection on creation" do
      AWS::S3.should_receive(:new).with(@aws_mock_options)

      @client = s3_blobstore("encryption_key"    => "bla",
                             "bucket_name"       => "test",
                             "access_key_id"     => "KEY",
                             "secret_access_key" => "SECRET")

      @client.encryption_key.should == "bla"
      @client.bucket_name.should == "test"
    end

    it "supports Symbol option keys too" do
      AWS::S3.should_receive(:new).with(@aws_mock_options)

      @client = s3_blobstore(:encryption_key    => "bla",
                             :bucket_name       => "test",
                             :access_key_id     => "KEY",
                             :secret_access_key => "SECRET")

      @client.encryption_key.should == "bla"
      @client.bucket_name.should == "test"
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

      it "should not encrypt when encryption key is missing" do
        client = s3_blobstore(:bucket_name       => "test",
                              :access_key_id     => "KEY",
                              :secret_access_key => "SECRET")
        client.should_receive(:generate_object_id).and_return("object_id")
        client.should_not_receive(:encrypt_file)

        client.
        AWS::S3::S3Object.should_receive(:store).with do |key, path, bucket|
          key.should == "object_id"
          bucket.should == "test"
        end
        client.create("some content").should eql("object_id")
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
        }.and_raise(AWS::S3::Errors::NoSuchKey.new(nil, nil))
        lambda {
          @client.create("some content")
        }.should raise_error(Bosh::Blobstore::BlobstoreError, "Failed to create object, S3 response error: No Such Key")
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

      it "should not decrypt when encryption key is missing" do
        client = s3_blobstore(:bucket_name       => "test",
                              :access_key_id     => "KEY",
                              :secret_access_key => "SECRET")

        mock_s3_object = mock("s3_object")
        mock_s3_object.stub!(:value).and_yield("stuff")
        AWS::S3::S3Object.should_receive(:find).with("object_id", "test").and_return(mock_s3_object)
        client.should_not_receive(:decrypt_stream)

        client.get("object_id").should == "stuff"
      end

      it "should raise an exception when there is an error fetching an object" do
        AWS::S3::S3Object.should_receive(:find).with("object_id", "test").and_raise(AWS::S3::Errors::NoSuchKey.new(nil, nil))
        lambda {
          @client.get("object_id")
        }.should raise_error(Bosh::Blobstore::BlobstoreError, "S3 object 'object_id' not found")
      end

      it "should raise more specific NotFound exception when object is not found" do
        AWS::S3::S3Object.should_receive(:find).with("object_id", "test").and_raise(AWS::S3::Errors::NoSuchKey.new(nil, nil))
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
        AWS::S3::S3Object.should_receive(:delete).with("object_id", "test").and_raise(AWS::S3::Errors::NoSuchKey.new(nil, nil))
        lambda {
          @client.delete("object_id")
        }.should raise_error(Bosh::Blobstore::BlobstoreError, "Failed to delete object 'object_id', S3 response error: No Such Key")
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
