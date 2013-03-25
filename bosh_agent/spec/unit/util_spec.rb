# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'common/exec'

describe Bosh::Agent::Util do

  before(:each) do
    Bosh::Agent::Config.blobstore_provider = "simple"
    Bosh::Agent::Config.blobstore_options = {}

    @httpclient = mock("httpclient")
    HTTPClient.stub!(:new).and_return(@httpclient)
  end

  it "should unpack a blob" do
    response = mock("response")
    response.stub!(:status).and_return(200)

    get_args = [ "/resources/some_blobstore_id", {}, {} ]
    @httpclient.should_receive(:get).with(*get_args).and_yield(dummy_package_data).and_return(response)

    install_dir = File.join(Bosh::Agent::Config.base_dir, 'data', 'packages', 'foo', '2')
    blobstore_id = "some_blobstore_id"
    sha1 = Digest::SHA1.hexdigest(dummy_package_data)

    Bosh::Agent::Util.unpack_blob(blobstore_id, sha1, install_dir)
  end

  it "should raise an exception when sha1 is doesn't match blob data" do
    response = mock("response")
    response.stub!(:status).and_return(200)

    get_args = [ "/resources/some_blobstore_id", {}, {} ]
    @httpclient.should_receive(:get).with(*get_args).and_yield(dummy_package_data).and_return(response)

    install_dir = File.join(Bosh::Agent::Config.base_dir, 'data', 'packages', 'foo', '2')
    blobstore_id = "some_blobstore_id"

    expect {
      Bosh::Agent::Util.unpack_blob(blobstore_id, "bogus_sha1", install_dir)
    }.to raise_error(Bosh::Agent::MessageHandlerError, /Expected sha1/)
  end

  it "should return a binding with config variable" do
    config_hash = { "job" => { "name" => "funky_job_name"} }
    config_binding = Bosh::Agent::Util.config_binding(config_hash)

    template = ERB.new("job name: <%= spec.job.name %>")

    expect {
      template.result(binding)
    }.to raise_error(NameError)

    template.result(config_binding).should == "job name: funky_job_name"
  end

  it "should handle hook" do
    base_dir = Bosh::Agent::Config.base_dir

    job_name = "hubba"
    job_bin_dir = File.join(base_dir, 'jobs', job_name, 'bin')
    FileUtils.mkdir_p(job_bin_dir)

    hook_file = File.join(job_bin_dir, 'post-install')

    File.exists?(hook_file).should be_false
    Bosh::Agent::Util.run_hook('post-install', job_name).should == nil

    File.open(hook_file, 'w') do |fh|
      fh.puts("#!/bin/bash\necho -n 'yay'") # sh echo doesn't support -n (at least on OSX)
    end

    expect {
      Bosh::Agent::Util.run_hook('post-install', job_name)
    }.to raise_error(Bosh::Agent::MessageHandlerError, "`post-install' hook for `hubba' job is not an executable file")

    FileUtils.chmod(0700, hook_file)
    Bosh::Agent::Util.run_hook('post-install', job_name).should == "yay"
  end

  it 'should return the block device size' do
    block_device = "/dev/sda1"
    File.should_receive(:blockdev?).with(block_device).and_return true
    Bosh::Agent::Util.should_receive(:sh).with("/sbin/sfdisk -s #{block_device} 2>&1").and_return(Bosh::Exec::Result.new("/sbin/sfdisk -s #{block_device} 2>&1", '1024', 0))
    Bosh::Agent::Util.block_device_size(block_device).should == 1024
  end

  it 'should raise exception when not a block device' do
    block_device = "/dev/not_a_block_device"
    File.should_receive(:blockdev?).with(block_device).and_return false
    expect { Bosh::Agent::Util.block_device_size(block_device) }.to raise_error(Bosh::Agent::MessageHandlerError, "Not a blockdevice")
  end

  it 'should raise exception when output is not an integer' do
    block_device = "/dev/not_a_block_device"
    File.should_receive(:blockdev?).with(block_device).and_return true
    Bosh::Agent::Util.should_receive(:sh).with("/sbin/sfdisk -s #{block_device} 2>&1").and_return(Bosh::Exec::Result.new("/sbin/sfdisk -s #{block_device} 2>&1", 'foobar', 0))
    expect { Bosh::Agent::Util.block_device_size(block_device) }.to raise_error(Bosh::Agent::MessageHandlerError, "Unable to determine disk size")
  end

end
