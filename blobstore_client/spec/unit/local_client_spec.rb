require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Blobstore::LocalClient do

  it "should require blobstore_path option" do
    lambda {
      client = Bosh::Blobstore::LocalClient.new({})
      }.should raise_error
  end

  it "should create blobstore_path direcory if it doesn't exist'" do
    Dir.mktmpdir do |tmp|
      dir = File.join(tmp, "blobstore")
      client = Bosh::Blobstore::LocalClient.new({:blobstore_path => dir})
      File.directory?(dir).should be_true
    end
  end

  describe "operations" do

    describe "get" do
      it "should retrive the correct contents" do
        Dir.mktmpdir do |tmp_dir|
          File.open(File.join(tmp_dir, 'foo'), 'w') do |fh|
            fh.puts("bar")
          end

          client = Bosh::Blobstore::LocalClient.new({:blobstore_path => tmp_dir})
          client.get("foo").should == "bar\n"
        end
      end
    end

    describe "create" do
      it "should store a file" do
        test_file = File.join(File.dirname(__FILE__), "../assets/file")
        Dir.mktmpdir do |tmp_dir|
          client = Bosh::Blobstore::LocalClient.new({:blobstore_path => tmp_dir})
          fh = File.open(test_file)
          id = client.create(fh)
          fh.close
          original = File.new(test_file).readlines
          stored = File.new(File.join(tmp_dir, id)).readlines
          stored.should == original
        end
      end

      it "should store a string" do
        Dir.mktmpdir do |tmp_dir|
          client = Bosh::Blobstore::LocalClient.new({:blobstore_path => tmp_dir})
          string = "foobar"
          id = client.create(string)
          stored = File.new(File.join(tmp_dir, id)).readlines
          stored.should == [string]
        end
      end
    end

  end

end
