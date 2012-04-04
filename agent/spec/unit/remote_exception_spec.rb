# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../spec_helper'

describe Bosh::Agent::RemoteException do

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

  it "should return valid json" do
    message = "message"
    backtrace = "backtrace"
    remote_exception = Bosh::Agent::RemoteException.new(message, backtrace)
    hash = remote_exception.to_hash
    hash.should have_key :exception
    exception = hash[:exception]
    exception.should have_key :message
    exception[:message].should == message
    exception.should have_key :backtrace
    exception[:backtrace].should == backtrace
    exception.should_not have_key :blobstore_id
  end

  it "should return valid json with blob" do
    message = "message"
    backtrace = "backtrace"
    blob = "blob"
    remote_exception = Bosh::Agent::RemoteException.new(message, backtrace, blob)
    hash = remote_exception.to_hash
    hash.should have_key :exception
    exception = hash[:exception]
    exception.should have_key :blobstore_id
    exception[:blobstore_id].should_not be_nil
  end

  it "should set a backtrace if none is provided" do
    message = "message"
    remote_exception = Bosh::Agent::RemoteException.new(message)
    remote_exception.backtrace.should_not be_nil
  end

  it "should have a helper constructor" do
    message = "message"
    blob = "blob"
    begin
      raise Bosh::Agent::MessageHandlerError.new(message, blob)
    rescue Bosh::Agent::MessageHandlerError => e
      re = Bosh::Agent::RemoteException.from(e)
    end

    # e = Bosh::Agent::MessageHandlerError.new(message, blob)
    # re = Bosh::Agent::RemoteException.from(e)
    re.message.should == message
    re.backtrace.should_not be_empty
    re.blob.should == blob
  end

end
