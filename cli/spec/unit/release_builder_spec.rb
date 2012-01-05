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
    builder.build

    File.file?(File.join(@work_dir, "dev_releases", "bosh_release-1.tgz")).should be_true
    File.file?(File.join(@work_dir, "dev_releases", "bosh_release-2.tgz")).should be_false
  end

  it "has a list of jobs affected by building this release" do
    job1 = mock(:job, :new_version? => true, :packages => ["bar", "baz"], :name => "job1")
    job2 = mock(:job, :new_version? => false, :packages => ["foo", "baz"], :name => "job2")
    job3 = mock(:job, :new_version? => false, :packages => ["baz", "zb"], :name => "job3")
    job4 = mock(:job, :new_version? => false, :packages => ["bar", "baz"], :name => "job4")

    package1 = mock(:package, :name => "foo", :new_version? => true)
    package2 = mock(:package, :name => "bar", :new_version? => false)
    package3 = mock(:package, :name => "baz", :new_version? => false)
    package4 = mock(:package, :name => "zb", :new_version? => true)

    builder = Bosh::Cli::ReleaseBuilder.new(@work_dir, [package1, package2, package3, package4], [job1, job2, job3, job4])
    builder.affected_jobs.should =~ [job1, job2, job3 ]
  end

end
