# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::BlobManager do

  def make_manager(release)
    Bosh::Cli::BlobManager.new(release)
  end

  before(:each) do
    @blobstore = double("blobstore")
    @dir = Dir.mktmpdir
    @src_dir = FileUtils.mkdir(File.join(@dir, "src"))
    @config_dir = File.join(@dir, "config")
    FileUtils.mkdir(@config_dir)
    @blobs_dir = File.join(@dir, "blobs")
    @release = double("release", :dir => @dir, :blobstore => @blobstore)
  end

  describe "initialization" do
    it "fails if 'src' directory is missing" do
      FileUtils.rm_rf(@src_dir)
      expect {
        make_manager(@release)
      }.to raise_error("`src' directory is missing")
    end

    it "fails if blobstore is not configured" do
      @release.stub(:blobstore).and_return(nil)
      expect {
        make_manager(@release)
      }.to raise_error("Blobstore is not configured")
    end

    it "creates necessary directories in release dir" do
      make_manager(@release)
      File.directory?(File.join(@dir, "blobs")).should be(true)
      File.directory?(File.join(@dir, ".blobs")).should be(true)
    end

    it "has dirty flag cleared and upload list empty" do
      manager = make_manager(@release)
      manager.dirty?.should be(false)
      manager.blobs_to_upload.should == []
    end

    it "doesn't like bad index file'" do
      File.open(File.join(@config_dir, "blobs.yml"), "w") do |f|
        Psych.dump("string", f)
      end

      expect {
        make_manager(@release)
      }.to raise_error(/Incorrect YAML structure/)
    end

    it "migrates legacy index file" do
      legacy_file = File.join(@release.dir, "blob_index.yml")
      test_hash = { "foo" => "bar" }

      File.open(legacy_file, "w") do |f|
        Psych.dump({ "foo" => "bar" }, f)
      end

      make_manager(@release)
      File.exists?(legacy_file).should be(false)
      Psych.load_file(File.join(@config_dir, "blobs.yml")).should == test_hash
    end
  end

  describe "adding a blob" do
    before(:each) do
      @manager = make_manager(@release)
      @blob = Tempfile.new("blob")
      @blob.write("blob contents")
      @blob.close
    end

    it "cannot add non-existing file" do
      expect {
        @manager.add_blob("tmp/foobar.tgz", "test")
      }.to raise_error("File `tmp/foobar.tgz' not found")
    end

    it "cannot add directory" do
      tmp_dir = Dir.mktmpdir
      expect {
        @manager.add_blob(tmp_dir, "test")
      }.to raise_error("`#{tmp_dir}' is a directory")
    end

    it "cannot use absolute path as blob destination" do
      expect {
        @manager.add_blob(@blob.path, "/test")
      }.to raise_error("Blob path should be a relative path")
    end

    it "cannot use 'blobs' prefix for blob destination" do
      expect {
        @manager.add_blob(@blob.path, "blobs/foo/bar")
      }.to raise_error("Blob path should not start with `blobs/'")
    end

    it "cannot use directory as blob destination" do
      foo_dir = File.join(@blobs_dir, "foo")
      FileUtils.mkdir(foo_dir)
      expect {
        @manager.add_blob(@blob.path, "foo")
      }.to raise_error("`#{foo_dir}' is a directory, " +
                       "please pick a different path")
    end

    it "adds blob to a blobs directory" do
      blob_dst = File.join(@blobs_dir, "foo", "blob")
      @manager.add_blob(@blob.path, "foo/blob")
      File.exists?(blob_dst).should be(true)
      File.read(blob_dst).should == "blob contents"
      File.symlink?(blob_dst).should be(false)
      File.stat(blob_dst).mode.to_s(8)[-4..-1].should == "0644"
      File.exists?(@blob.path).should be(true) # original still exists

      @manager.process_blobs_directory
      @manager.dirty?.should be(true)
      @manager.new_blobs.should == %w(foo/blob)
      @manager.updated_blobs.should == []
    end

    it "prevents double adds of the same file" do
      @manager.add_blob(@blob.path, "foo/blob")
      expect {
        @manager.add_blob(@blob.path, "foo/blob")
      }.to raise_error(/Already tracking/)
    end

    it "updates blob" do
      new_blob = Tempfile.new("new-blob")
      new_blob.write("foobar")
      new_blob.close
      blob_dst = File.join(@blobs_dir, "foo", "blob")
      @manager.add_blob(@blob.path, "foo/blob")
      File.read(blob_dst).should == "blob contents"
      @manager.add_blob(new_blob.path, "foo/blob")
      File.read(blob_dst).should == "foobar"
    end
  end

  describe "downloading a blob" do
    it "cannot download blob if path is not in index" do
      @manager = make_manager(@release)

      expect {
        @manager.download_blob("foo")
      }.to raise_error(/Unknown blob path/)
    end

    it "downloads blob from blobstore" do
      index = {
        "foo" => {
          "size" => "1000",
          "object_id" => "deadbeef",
          "sha" => Digest::SHA1.hexdigest("blob contents")
        }
      }

      File.open(File.join(@config_dir, "blobs.yml"), "w") do |f|
        Psych.dump(index, f)
      end

      @manager = make_manager(@release)
      @blobstore.should_receive(:get).with("deadbeef",
                                           an_instance_of(File)).
        and_return { |_, f | f.write("blob contents") }

      path = @manager.download_blob("foo")
      File.read(path).should == "blob contents"
    end
  end

  describe "uploading a blob" do
    before(:each) do
      @manager = make_manager(@release)
    end

    it "needs blob path to exist" do
      expect {
        @manager.upload_blob("foo")
      }.to raise_error(/doesn't exist/)
    end

    it "doesn't follow symlinks" do
      FileUtils.touch(File.join(@dir, "blob"))
      FileUtils.ln_s(File.join(@dir, "blob"), File.join(@blobs_dir, "foo"))
      expect {
        @manager.upload_blob("foo")
      }.to raise_error(/is a symlink/)
    end

    it "uploads file to a blobstore, updates index and symlinks blob" do
      new_blob = File.join(@dir, "blob")
      File.open(new_blob, "w") { |f| f.write("test blob") }
      @manager.add_blob(new_blob, "foo")

      @blobstore.should_receive(:create).and_return("deadbeef")
      @manager.upload_blob("foo").should == "deadbeef"

      blob_dst = File.join(@blobs_dir, "foo")
      checksum = Digest::SHA1.hexdigest("test blob")

      File.symlink?(blob_dst).should be(true)
      File.readlink(blob_dst).should == File.join(@dir, ".blobs", checksum)
      File.read(blob_dst).should == "test blob"
    end
  end

  describe "syncing blobs" do
    it "includes several steps" do
      @manager = make_manager(@release)
      @manager.should_receive(:remove_symlinks).ordered
      @manager.should_receive(:process_blobs_directory).ordered
      @manager.should_receive(:process_index).ordered
      @manager.sync
    end

    it "processes blobs directory" do
      @manager = make_manager(@release)
      @blobstore.stub(:create).and_return("new-object-id")

      new_blob = Tempfile.new("new-blob")
      new_blob.write("test")
      new_blob.close

      @manager.add_blob(new_blob.path, "foo")
      @manager.process_blobs_directory
      @manager.new_blobs.should == %w(foo)

      @manager.add_blob(new_blob.path, "bar")
      @manager.process_blobs_directory
      @manager.new_blobs.sort.should == %w(bar foo)

      @manager.upload_blob("bar")

      new_blob.open
      new_blob.write("stuff")
      new_blob.close

      @manager.add_blob(new_blob.path, "bar")
      @manager.process_blobs_directory
      @manager.new_blobs.sort.should == %w(foo)
      @manager.updated_blobs.sort.should == %w(bar)
    end

    it "downloads missing blobs" do
      index = {
        "foo" => {
          "size" => 1000,
          "sha" => Digest::SHA1.hexdigest("foo"),
          "object_id" => "da-foo"
        },
        "bar" => {
          "size" => 500,
          "sha" => Digest::SHA1.hexdigest("bar"),
          "object_id" => "da-bar"
        }
      }

      File.open(File.join(@config_dir, "blobs.yml"), "w") do |f|
        Psych.dump(index, f)
      end

      foo = Tempfile.new("foo")
      foo.write("foo")
      foo.close

      bar = Tempfile.new("bar")
      bar.write("bar")
      bar.close

      @manager = make_manager(@release)
      @manager.should_receive(:download_blob).with("foo").and_return(foo.path)
      @manager.should_receive(:download_blob).with("bar").and_return(bar.path)

      @manager.process_index

      File.read(File.join(@blobs_dir, "foo")).should == "foo"
      File.read(File.join(@blobs_dir, "bar")).should == "bar"
    end
  end
end
