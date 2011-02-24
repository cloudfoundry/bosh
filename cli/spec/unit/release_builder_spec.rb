require "spec_helper"
require "fileutils"

describe Bosh::Cli::ReleaseBuilder do

  before(:each) do
    @work_dir = Dir.mktmpdir
  end

  def new_builder
    Bosh::Cli::ReleaseBuilder.new(@work_dir, [], [])
  end

  it "uses version 1 if no previous releases have been created" do
    new_builder.version.should == 1
  end

  it "builds a release" do
    builder = new_builder
    builder.build

    expected_tarball_path = File.join(@work_dir, "dev_releases", "bosh_release-1.tgz")

    builder.tarball_path.should == expected_tarball_path
    File.file?(expected_tarball_path).should be_true
  end

  it "doesn't build a new release if nothing has changed" do
    builder = new_builder
    builder.build

    lambda {
      builder.build
    }.should raise_error(Bosh::Cli::GracefulExit)

    File.file?(File.join(@work_dir, "dev_releases", "bosh_release-1.tgz")).should be_true
    File.file?(File.join(@work_dir, "dev_releases", "bosh_release-2.tgz")).should be_false
  end

end
