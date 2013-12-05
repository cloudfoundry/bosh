# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Bosh::Agent::Message::FetchLogs do

  before(:each) do
    @tmp_dir = Dir.mktmpdir
    @base_dir = File.join(@tmp_dir, "basedir")
    @blobstore_dir = File.join(@tmp_dir, "blobstore")

    FileUtils.mkdir_p(File.join(@tmp_dir, "blobstore"))
    FileUtils.mkdir_p(@base_dir)

    Bosh::Agent::Config.base_dir = @base_dir
    Bosh::Agent::Config.state = Bosh::Agent::State.new(File.join(@base_dir, "state.yml"))

    Bosh::Agent::Config.blobstore_provider = "local"
    Bosh::Agent::Config.blobstore_options = { "blobstore_path" => @blobstore_dir }
  end

  after(:each) do
    FileUtils.rm_rf(@tmp_dir)
    Bosh::Agent::Config.state = nil
  end

  def write_state(state = nil)
    Bosh::Agent::Config.state.write(state || yield)
  end

  def make_handler(*args)
    Bosh::Agent::Message::FetchLogs.new(args)
  end

  def process(*args)
    handler = make_handler(*args)
    handler.process
  end

  def test_handler(*args, &block)
    result = process(*args)
    test_tarball(result["blobstore_id"], &block)
  end

  def test_tarball(blobstore_id)
    blobstore_id.should_not be_nil
    tarball = File.join(@blobstore_dir, blobstore_id)
    File.exists?(tarball).should be(true)

    out_dir = File.join(@tmp_dir, "out")
    FileUtils.mkdir_p(out_dir)

    tar_out = `tar -C #{out_dir} -xzf #{tarball} 2>&1`
    $?.exitstatus.should == 0

    Dir.chdir(out_dir) { yield }
  ensure
    FileUtils.rm_rf(out_dir)
  end

  it "is a long running task" do
    Bosh::Agent::Message::FetchLogs.long_running?.should be(true)
  end

  it "fetches job logs and uploads them to blobstore"  do
    write_state do
      { "job" => { "template" => "job_a" } }
    end

    log_dir = File.join(@base_dir, "sys", "log", "job_a")
    FileUtils.mkdir_p(log_dir)

    log1 = File.join(log_dir, "zb.log")
    log2 = File.join(log_dir, "zb.log.1")

    File.open(log1, "w") { |f| f.write("log1") }
    File.open(log2, "w") { |f| f.write("log2") }

    result = process(:job)
    blobstore_id = result["blobstore_id"]

    test_tarball(blobstore_id) do
      File.exists?("job_a/zb.log").should be(true)
      File.read("job_a/zb.log").should == "log1"
      File.exists?("job_a/zb.log.1").should be(false)
    end
  end

  it "fetches agent logs" do
    log_dir = File.join(@base_dir, "bosh", "log")
    FileUtils.mkdir_p(log_dir)

    log1 = File.join(log_dir, "log1")
    log2 = File.join(log_dir, "log2")

    File.open(log1, "w") { |f| f.write("log1") }
    File.open(log2, "w") { |f| f.write("log2") }

    result = process(:agent)
    blobstore_id = result["blobstore_id"]

    test_tarball(blobstore_id) do
      File.exists?("log1").should be(true)
      File.read("log1").should == "log1"
      File.exists?("log2").should be(true)
      File.read("log2").should == "log2"
    end
  end

  it "raises error if there is no job or agent logs directory" do
    lambda {
      process(:agent)
    }.should raise_error(Bosh::Agent::MessageHandlerError, "unable to find agent logs directory")

    lambda {
      process(:job)
    }.should raise_error(Bosh::Agent::MessageHandlerError, "unable to find job logs directory")
  end

  it "raises an error if there is a problem uploading logs" do
    log_dir = File.join(@base_dir, "bosh", "log")
    FileUtils.mkdir_p(log_dir)

    bad_client = double(Bosh::Blobstore::Client)
    Bosh::Blobstore::Client.stub(:safe_create).and_return(bad_client)

    bad_client.stub(:create).and_raise(
      Bosh::Blobstore::BlobstoreError.new("no mood to upload today"))

    lambda {
      process(:agent)
    }.should raise_error(
      Bosh::Agent::MessageHandlerError,
      "unable to upload logs to blobstore: no mood to upload today",
    )
  end

  it "raises an error if there is a problem packing logs" do
    log_dir = File.join(@base_dir, "bosh", "log")
    FileUtils.mkdir_p(log_dir)

    bad_aggregator = Bosh::Agent::FileAggregator.new
    bad_aggregator.stub(:add_file).and_return(true)
    bad_aggregator.stub(:generate_tarball).and_raise(
      Bosh::Agent::FileAggregator::PackagingError.new("come back later"))

    handler = make_handler(:agent)
    handler.aggregator = bad_aggregator

    lambda {
      handler.process
    }.should raise_error(Bosh::Agent::MessageHandlerError, "error aggregating logs: come back later")
  end

  it "supports custom log filters defined in job state" do
    write_state do
      {
        "job" => {
          "template" => "job_a",
          "logs" => {
            "foos" => "foo/*",
            "bars" => "bar/*"
          }
        }
      }
    end

    log_dir = File.join(@base_dir, "sys", "log")
    FileUtils.mkdir_p(log_dir)

    %w(foo bar).each do |dir|
      FileUtils.mkdir_p(File.join(log_dir, dir))
    end

    log1 = File.join(log_dir, "foo", "log1")
    log2 = File.join(log_dir, "bar", "log2")
    log3 = File.join(log_dir, "log3")

    [ log1, log2, log3 ].each { |file| FileUtils.touch(file) }

    test_handler(:job, ["foos"]) do
      File.exists?("foo/log1").should be(true)
      File.exists?("bar/log2").should be(false)
      File.exists?("log3").should be(false)
    end

    test_handler(:job, ["bars"]) do
      File.exists?("foo/log1").should be(false)
      File.exists?("bar/log2").should be(true)
      File.exists?("log3").should be(false)
    end

    test_handler(:job, ["foos", "bars"]) do
      File.exists?("foo/log1").should be(true)
      File.exists?("bar/log2").should be(true)
      File.exists?("log3").should be(false)
    end

    test_handler(:job, ["all"]) do
      File.exists?("foo/log1").should be(true)
      File.exists?("bar/log2").should be(true)
      File.exists?("log3").should be(true)
    end
  end

  it "ignores invalid logs spec" do
    write_state do
      {
        "job" => {
          "template" => "job_a",
          "logs" => [ "invalid format" ]
        }
      }
    end

    log_dir = File.join(@base_dir, "sys", "log")
    FileUtils.mkdir_p(log_dir)

    FileUtils.mkdir_p(File.join(log_dir, "foo"))

    log1 = File.join(log_dir, "foo", "log1")
    log2 = File.join(log_dir, "log2")
    log3 = File.join(log_dir, "log3.log")

    [ log1, log2, log3 ].each { |file| FileUtils.touch(file) }

    test_handler(:job, ["foos"]) do
      File.exists?("foo/log1").should be(false)
      File.exists?("log2").should be(false)
      File.exists?("log3.log").should be(false)
    end

    test_handler(:job, ["all"]) do
      File.exists?("foo/log1").should be(true)
      File.exists?("log2").should be(true)
      File.exists?("log3.log").should be(true)
    end
  end
end
