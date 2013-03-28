# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Api::ApiHelper do
  include Bosh::Director::Api::ApiHelper

  before(:each) do
    @tmpdir = Dir.mktmpdir("base_dir")
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