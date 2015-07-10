require "spec_helper"

describe Bosh::Cli::BlobManager do

  def make_manager(release, max_parallel_downloads=1, renderer=nil)
    renderer ||= Bosh::Cli::InteractiveProgressRenderer.new
    Bosh::Cli::BlobManager.new(release, max_parallel_downloads, renderer)
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

    it "creates necessary directories in release dir" do
      make_manager(@release)
      expect(File.directory?(File.join(@dir, "blobs"))).to be(true)
      expect(File.directory?(File.join(@dir, ".blobs"))).to be(true)
    end

    it "has dirty flag cleared and upload list empty" do
      manager = make_manager(@release)
      expect(manager.dirty?).to be(false)
      expect(manager.blobs_to_upload).to eq([])
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
      expect(File.exists?(legacy_file)).to be(false)
      expect(Psych.load_file(File.join(@config_dir, "blobs.yml"))).to eq(test_hash)
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
      expect(File.exists?(blob_dst)).to be(true)
      expect(File.read(blob_dst)).to eq("blob contents")
      expect(File.symlink?(blob_dst)).to be(false)
      expect(File.stat(blob_dst).mode.to_s(8)[-4..-1]).to eq("0644")
      expect(File.exists?(@blob.path)).to be(true) # original still exists

      @manager.process_blobs_directory
      expect(@manager.dirty?).to be(true)
      expect(@manager.new_blobs).to eq(%w(foo/blob))
      expect(@manager.updated_blobs).to eq([])
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
      expect(File.read(blob_dst)).to eq("blob contents")
      @manager.add_blob(new_blob.path, "foo/blob")
      expect(File.read(blob_dst)).to eq("foobar")
    end
  end

  describe "downloading a blob" do
    it 'fails if blobstore is not configured' do
      allow(@release).to receive(:blobstore).and_return(nil)

      expect {
        make_manager(@release).download_blob('foo')
      }.to raise_error('Failed to download blobs: blobstore not configured')
    end

    it "cannot download blob if path is not in index" do
      @manager = make_manager(@release)

      expect {
        @manager.download_blob("foo")
      }.to raise_error(/Unknown blob path/)
    end

    it "downloads blob from blobstore" do
      blob_sha1 = Digest::SHA1.hexdigest("blob contents")
      index = {
        "foo" => {
          "size" => "1000",
          "object_id" => "deadbeef",
          "sha" => blob_sha1
        }
      }

      File.open(File.join(@config_dir, "blobs.yml"), "w") do |f|
        Psych.dump(index, f)
      end

      renderer = Bosh::Cli::InteractiveProgressRenderer.new
      expect(renderer).to receive(:progress).at_least(1).times
      expect(renderer).to receive(:finish).once

      @manager = make_manager(@release, 1, renderer)
      expect(@blobstore)
        .to receive(:get)
        .with("deadbeef", an_instance_of(File), {sha1: blob_sha1}) { |_, f | f.write("blob contents") }

      path = @manager.download_blob("foo")
      expect(File.read(path)).to eq("blob contents")
    end
  end

  describe "uploading a blob" do
    before(:each) do
      @manager = make_manager(@release)
    end

    it "fails if blobstore is not configured" do
      allow(@release).to receive(:blobstore).and_return(nil)

      expect {
        make_manager(@release).upload_blob("foo")
      }.to raise_error("Failed to upload blobs: blobstore not configured")
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

      renderer = Bosh::Cli::InteractiveProgressRenderer.new
      expect(renderer).to receive(:start).once
      expect(renderer).to receive(:finish).once
      @manager = make_manager(@release, 1, renderer)

      @manager.add_blob(new_blob, "foo")

      expect(@blobstore).to receive(:create).and_return("deadbeef")
      expect(@manager.upload_blob("foo")).to eq("deadbeef")

      blob_dst = File.join(@blobs_dir, "foo")
      checksum = Digest::SHA1.hexdigest("test blob")

      expect(File.symlink?(blob_dst)).to be(true)
      expect(File.readlink(blob_dst)).to eq(File.join(@dir, ".blobs", checksum))
      expect(File.read(blob_dst)).to eq("test blob")
    end
  end

  describe "syncing blobs" do
    it "includes several steps" do
      @manager = make_manager(@release)
      expect(@manager).to receive(:remove_symlinks).ordered
      expect(@manager).to receive(:process_blobs_directory).ordered
      expect(@manager).to receive(:process_index).ordered
      @manager.sync
    end

    it "processes blobs directory" do
      @manager = make_manager(@release)
      allow(@blobstore).to receive(:create).and_return("new-object-id")

      new_blob = Tempfile.new("new-blob")
      new_blob.write("test")
      new_blob.close

      @manager.add_blob(new_blob.path, "foo")
      @manager.process_blobs_directory
      expect(@manager.new_blobs).to eq(%w(foo))

      @manager.add_blob(new_blob.path, "bar")
      @manager.process_blobs_directory
      expect(@manager.new_blobs.sort).to eq(%w(bar foo))

      @manager.upload_blob("bar")

      new_blob.open
      new_blob.write("stuff")
      new_blob.close

      @manager.add_blob(new_blob.path, "bar")
      @manager.process_blobs_directory
      expect(@manager.new_blobs.sort).to eq(%w(foo))
      expect(@manager.updated_blobs.sort).to eq(%w(bar))
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

      allow(Bosh::ThreadPool).to receive(:new).and_call_original

      @manager = make_manager(@release, 99)
      expect(@manager).to receive(:download_blob).with("foo").and_return(foo.path)
      expect(@manager).to receive(:download_blob).with("bar").and_return(bar.path)

      @manager.process_index

      expect(File.read(File.join(@blobs_dir, "foo"))).to eq("foo")
      expect(File.read(File.join(@blobs_dir, "bar"))).to eq("bar")

      expect(Bosh::ThreadPool).to have_received(:new).with(:max_threads => 99, :logger => kind_of(Logging::Logger))
    end
  end
end
