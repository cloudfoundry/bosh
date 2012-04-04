# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Agent::ApplyPlan::Package do

  before :each do
    @base_dir = Dir.mktmpdir
    Bosh::Agent::Config.base_dir = @base_dir
  end

  def make_package(*args)
    Bosh::Agent::ApplyPlan::Package.new(*args)
  end

  def make_job(*args)
    Bosh::Agent::ApplyPlan::Job.new(*args)
  end

  let(:valid_spec) do
    {
      "name" => "postgres",
      "version" => "2",
      "sha1" => "deadbeef",
      "blobstore_id" => "deadcafe"
    }
  end

  let(:job_spec) do
    {
      "name" => "ccdb",
      "template" => "postgres",
      "version" => "2",
      "sha1" => "badcafe",
      "blobstore_id" => "beefdad"
    }
  end

  describe "initialization" do
    it "expects Hash argument" do
      expect {
        make_package("test")
      }.to raise_error(ArgumentError, "Invalid package spec, " +
                                      "Hash expected, String given")
    end

    it "requires name, version, sha1 and blobstore_id to be in spec" do
      valid_spec.keys.each do |key|
        expect {
          make_package(valid_spec.merge(key => nil))
        }.to raise_error(ArgumentError, "Invalid spec, #{key} is missing")
      end
    end

    it "picks install path and link path" do
      install_path = File.join(@base_dir, "data", "packages", "postgres", "2")
      link_path = File.join(@base_dir, "packages", "postgres")

      package = make_package(valid_spec)
      package.install_path.should == install_path
      package.link_path.should == link_path

      File.exists?(install_path).should be_false
      File.exists?(link_path).should be_false
    end
  end

  describe "installation" do
    it "fetches package and creates symlink in packages and jobs" do
      package = make_package(valid_spec)
      job = make_job(job_spec)

      # TODO: make sure unpack_blob is tested elsewhere
      Bosh::Agent::Util.should_receive(:unpack_blob).
        with("deadcafe", "deadbeef", package.install_path).
        and_return { FileUtils.mkdir_p(package.install_path) }

      package.install_for_job(job)

      File.exists?(package.install_path).should be_true
      File.exists?(package.link_path).should be_true

      File.realpath(package.link_path).
        should == File.realpath(package.install_path)

      job_link_path = File.join(job.install_path, "packages", "postgres")

      File.realpath(job_link_path).
        should == File.realpath(package.install_path)
    end

  end

end
