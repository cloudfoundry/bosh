# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::ReleaseBuilder do

  before(:each) do
    @release_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@release_dir, "config"))
    @release = Bosh::Cli::Release.new(@release_dir)
  end

  def new_builder
    Bosh::Cli::ReleaseBuilder.new(@release, [], [])
  end

  it "uses version 0.1-dev if no previous releases have been created" do
    new_builder.version.should == "0.1-dev"
  end

  it "builds a release" do
    builder = new_builder
    builder.build

    expected_tarball_path = File.join(@release_dir,
                                      "dev_releases",
                                      "bosh_release-0.1-dev.tgz")

    builder.tarball_path.should == expected_tarball_path
    File.file?(expected_tarball_path).should be_true
  end

  it "doesn't build a new release if nothing has changed" do
    builder = new_builder
    builder.build
    builder.build

    File.file?(File.join(@release_dir, "dev_releases",
                         "bosh_release-0.1-dev.tgz")).
        should be_true
    File.file?(File.join(@release_dir, "dev_releases",
                         "bosh_release-0.2-dev.tgz")).
        should be_false
  end

  it "has a list of jobs affected by building this release" do
    job1 = mock(:job, :new_version? => true,
                :packages => %w(bar baz), :name => "job1")
    job2 = mock(:job, :new_version? => false,
                :packages => %w(foo baz), :name => "job2")
    job3 = mock(:job, :new_version? => false,
                :packages => %w(baz zb), :name => "job3")
    job4 = mock(:job, :new_version? => false,
                :packages => %w(bar baz), :name => "job4")

    package1 = mock(:package, :name => "foo", :new_version? => true)
    package2 = mock(:package, :name => "bar", :new_version? => false)
    package3 = mock(:package, :name => "baz", :new_version? => false)
    package4 = mock(:package, :name => "zb", :new_version? => true)

    builder = Bosh::Cli::ReleaseBuilder.new(@release,
                                            [package1, package2,
                                             package3, package4],
                                            [job1, job2, job3, job4])
    builder.affected_jobs.should =~ [job1, job2, job3]
  end

  it "bumps dev version in sync with final version" do
    final_index = Bosh::Cli::VersionsIndex.new(File.join(@release_dir,
                                                         "releases"))

    final_index.add_version("deadbeef", { "version" => 2 }, "payload")

    builder = new_builder
    builder.version.should == "2.1-dev"
    builder.build

    final_index.add_version("deadbeef", { "version" => 7 }, "payload")
    builder = new_builder
    builder.version.should == "7.1-dev"
  end

  it "has packages and jobs fingerprints in spec" do
    job = mock(
      Bosh::Cli::JobBuilder,
      :name => "job1",
      :version => "1.1",
      :new_version? => true,
      :packages => %w(foo),
      :fingerprint => "deadbeef",
      :checksum => "cafebad"
    )

    package = mock(
      Bosh::Cli::PackageBuilder,
      :name => "foo",
      :version => "42",
      :new_version? => true,
      :fingerprint => "deadcafe",
      :checksum => "baddeed",
      :dependencies => []
    )

    builder = Bosh::Cli::ReleaseBuilder.new(@release, [package], [job])
    builder.should_receive(:copy_jobs)
    builder.should_receive(:copy_packages)

    builder.build

    manifest = YAML.load_file(builder.manifest_path)

    manifest["jobs"][0]["fingerprint"].should == "deadbeef"
    manifest["packages"][0]["fingerprint"].should == "deadcafe"
  end

end
