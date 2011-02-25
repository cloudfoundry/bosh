require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Blobstore::LocalClient do

  describe "options" do
    it "should set blobstore_path" do
      Dir.mktmpdir do |tmp_dir|
        File.open(File.join(tmp_dir, 'foo'), 'w') do |fh|
          fh.puts("bar")
        end

        client = Bosh::Blobstore::LocalClient.new({"blobstore_path" => tmp_dir})
        client.get("foo").should == "bar\n"
      end
    end
  end

  describe "operations" do 
    it "should raise exception on create" do
      Dir.mktmpdir do |tmp_dir|
        lambda {
          client = Bosh::Blobstore::LocalClient.new({"blobstore_path" => tmp_dir})
          client.create("foo")
        }.should raise_error(Bosh::Blobstore::BlobstoreError)
      end
    end
  end

end
