# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Api::ApiHelper do
  include Bosh::Director::Api::ApiHelper

  before(:each) do
    @tmpdir = Dir.mktmpdir("base_dir")
  end

  describe :check_available_disk_space do
    before :each do
      @stat = double("stat")
      Sys::Filesystem.stub(:stat).and_return(@stat)
    end

    it "should return true if there is available disk space" do
      @stat.should_receive(:block_size).and_return(1024)
      @stat.should_receive(:blocks_available).and_return(1024)
      check_available_disk_space(@tmpdir, 1048).should be(true)
    end

    it "should return false if there is no available disk space" do
      @stat.should_receive(:block_size).and_return(1024)
      @stat.should_receive(:blocks_available).and_return(1)
      check_available_disk_space(@tmpdir, 1048).should be(false)
    end

    it "should return false if there is an exception when checking dir stats"do
      @stat.should_receive(:block_size).and_raise(Errno::EACCES)
      check_available_disk_space(@tmpdir, 1048).should be(false)
    end
  end

  describe :write_file do
    it "should write a file" do
      file_in = StringIO.new("contents")
      file_out = File.join(@tmpdir, SecureRandom.uuid)

      write_file(file_out, file_in)
      File.read(file_out).should == "contents"
    end

    it "should raise an exception if there's any system error call" do
      file_in = StringIO.new("contents")
      file_out = File.join(@tmpdir, SecureRandom.uuid)
      File.should_receive(:open).with(file_out, "w").and_raise(Errno::ENOSPC)

      expect {
        write_file(file_out, file_in)
      }.to raise_exception(Bosh::Director::SystemError)
    end
  end
end
