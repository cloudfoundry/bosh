require "spec_helper"

require "tmpdir"
require "fileutils"

describe Bosh::Director::TarGziper do
  let(:src) { Dir.mktmpdir }
  let(:dest) { Tempfile.new("logs").path }
  let(:tar_gzipper) { described_class.new }

  before do
    path = File.join(src, "var", "vcap", "sys", "log1")
    FileUtils.mkdir_p(path)
    File.write(File.join(path, "hello.log"), "hello")

    path = File.join(src, "var", "vcap", "sys", "log2")
    FileUtils.mkdir_p(path)
    File.write(File.join(path, "goodbye.log"), "goodbye")
  end

  after do
    FileUtils.rm_rf(src)
    FileUtils.rm_rf(dest)
  end

  context "if the source directory does not exist" do
    let(:src) { "/tmp/this/is/not/here" }

    before do
      FileUtils.rm_rf(src)
    end

    it "raises an error" do
      expect {
        tar_gzipper.compress(src, dest)
      }.to raise_error(Bosh::Director::TarGziper::SourceNotFound, "The source directory #{src} could not be found.")
    end
  end

  context "if the source directory is not absolute" do
    let(:src) { "tmp/file" }

    it "raises an error" do
      expect {
        tar_gzipper.compress(src, dest)
      }.to raise_error(Bosh::Director::TarGziper::SourceNotAbsolute, "The source directory #{src} is not an absolute path.")
    end
  end

  it "packages the source directory into the destination tarball" do
    tar_gzipper.stub(tar_path: "tar")
    tar_gzipper.compress(src, dest)

    `tar tzvf #{dest}`.should match(%r{log1/hello.log})
  end

  it "moves the sources files to a temporary directory first to avoid errors if we change the files as we are tarring them" do
    tar_gzipper.stub(tar_path: "tar")
    tar_gzipper.compress(src, dest)

    `tar tzvf #{dest}`.should include("bosh_tgz")
  end

  it "uses the correct tar path" do
    command_runner = double("command runner")
    tar_gzipper.command_runner = command_runner
    command_runner.should_receive(:sh).with(%r{^/bin/tar })

    tar_gzipper.compress(src, dest)
  end

  context "if multiple source directories are specified" do
    let(:sources) { ["#{src}/var/vcap/sys/log1", "#{src}/var/vcap/sys/log2"]}

    it "packages the list of source directories into the destination tarball" do
      tar_gzipper.stub(tar_path: "tar")
      tar_gzipper.compress(sources, dest)

      tar_cmd = `tar tzvf #{dest}`
      expect(tar_cmd).to match(%r{log1/hello.log})
      expect(tar_cmd).to match(%r{log2/goodbye.log})
    end
  end
end