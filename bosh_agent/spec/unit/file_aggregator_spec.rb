# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::FileAggregator do

  before(:each) do
    @dir = Dir.mktmpdir
  end

  after(:each) do
    FileUtils.rm_rf(@dir)
  end

  def make_aggregator
    Bosh::Agent::FileAggregator.new
  end

  it "generates a tarball with all requested entries" do
    matcher = Bosh::Agent::FileMatcher.new(@dir)
    matcher.globs = ["**/*"]

    aggregator = make_aggregator
    aggregator.matcher = matcher

    %w(foo bar baz).each do |dirname|
      FileUtils.mkdir_p(File.join(@dir, dirname))
    end

    files = [
             File.join(@dir, "foo", "file1"),
             File.join(@dir, "bar", "file2"),
             File.join(@dir, "bar", "file3"),
             File.join(@dir, "baz", "file4"),
             File.join(@dir, "zb")
            ]

    files.each_with_index do |file, i|
      File.open(file, "w") { |f| f.write("test#{i+1}\n") }
    end

    tarball_path = aggregator.generate_tarball

    File.exists?(tarball_path).should be(true)

    out_dir = File.join(@dir, "out")
    FileUtils.mkdir_p(out_dir)
    FileUtils.cp(tarball_path, out_dir, :preserve => true)

    Dir.chdir(out_dir) do
      `tar xzf #{File.basename(tarball_path)}`
      File.directory?("foo").should be(true)
      File.directory?("bar").should be(true)
      File.directory?("baz").should be(true)

      files.each_with_index do |path, index|
        File.exists?(path).should be(true)
        File.read(path).should == "test#{index+1}\n"
      end
    end
  end

  it "cleans up after itself" do
    matcher = Bosh::Agent::FileMatcher.new(@dir)
    matcher.globs = ["**/*"]

    aggregator = make_aggregator
    aggregator.matcher = matcher

    tarball1 = aggregator.generate_tarball
    tarball2 = aggregator.generate_tarball

    File.exists?(File.dirname(tarball1)).should be(true)
    File.exists?(File.dirname(tarball2)).should be(true)

    aggregator.cleanup

    File.exists?(File.dirname(tarball1)).should be(false)
    File.exists?(File.dirname(tarball2)).should be(false)
  end

end
