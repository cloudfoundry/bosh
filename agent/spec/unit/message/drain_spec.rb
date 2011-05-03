require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::Drain do

  before(:each) do
    setup_tmp_base_dir
    logger = mock('logger')
    logger.stub!(:info)
    Bosh::Agent::Config.logger = logger

    @base_dir = Bosh::Agent::Config.base_dir

    @state_handler = mock('state_handler')
    Bosh::Agent::Message::State.stub(:new).and_return(@state_handler)
  end

  it "should receive drain type and an optional argument" do
    @state_handler.should_receive(:state).and_return(old_spec)
    handler = Bosh::Agent::Message::Drain.new(["shutdown"])
  end

  it "should handle shutdown drain type" do
    @state_handler.should_receive(:state).and_return(old_spec)

    bindir = File.join(@base_dir, 'jobs', 'cloudcontroller', 'bin')
    drain_script = File.join(bindir, 'drain')
    FileUtils.mkdir_p(bindir)

    handler = Bosh::Agent::Message::Drain.new(["shutdown"])

    FileUtils.mkdir_p(File.join(base_dir, 'tmp'))

    drain_out = File.join(base_dir, 'tmp', 'yay.out')

    File.open(drain_script, 'w') do |fh|
      fh.puts "#!/bin/bash\necho $@ > #{drain_out}\necho -n '10'"
    end
    FileUtils.chmod(0777, drain_script)

    handler.drain.should == 10

    File.read(drain_out).should == "job_shutdown hash_unchanged\n"
  end


  it "should handle update drain type" do
    @state_handler.should_receive(:state).and_return(old_spec)

    bindir = File.join(@base_dir, 'jobs', 'cloudcontroller', 'bin')
    drain_script = File.join(bindir, 'drain')
    FileUtils.mkdir_p(bindir)

    File.open(drain_script, 'w') do |fh|
      fh.puts "#!/bin/bash\necho $@ > /tmp/yay.out\necho -n '10'"
    end
    FileUtils.chmod(0777, drain_script)

    handler = Bosh::Agent::Message::Drain.new(["update", new_spec])
    handler.drain.should == 10
  end


  it "should return 0 if it receives an update but doesn't have a previouisly applied job" do
    @state_handler.should_receive(:state).and_return({})

    handler = Bosh::Agent::Message::Drain.new(["update", new_spec])
    handler.drain.should == 0
  end

  it "should pass job update state to drain script" do
    @state_handler.should_receive(:state).and_return(old_spec)

    job_update_spec = new_spec
    job_update_spec['job']['sha1'] = "some_sha1"

    handler = Bosh::Agent::Message::Drain.new(["update", job_update_spec])

    handler.stub!(:drain_script_exists?).and_return(true)
    handler.stub!(:run_drain_script).and_return(10)
    handler.should_receive(:run_drain_script).with("job_changed", "hash_unchanged", ["mysqlclient"])
    handler.drain.should == 10
  end

  it "should pass the name of updated packages to drain script" do
    @state_handler.should_receive(:state).and_return(old_spec)

    pkg_update_spec = new_spec
    pkg_update_spec['packages']['ruby']['sha1'] = "some_other_sha1"

    handler = Bosh::Agent::Message::Drain.new(["update", pkg_update_spec])

    handler.stub!(:drain_script_exists?).and_return(true)
    handler.stub!(:run_drain_script).and_return(10)
    handler.should_receive(:run_drain_script).with("job_unchanged", "hash_unchanged", ["mysqlclient", "ruby"])
    handler.drain.should == 10
  end


  it "should set BOSH_CURRENT_STATE environment varibale"
  it "should set BOSH_APPLY_SPEC environment variable"

  def old_spec
    {
      "configuration_hash"=>"bfa2468a257de0ead95e1812038030209dc5b0b7",
      "packages"=>{
        "mysqlclient"=>{
          "name"=>"mysqlclient", "blobstore_id"=>"7eb0da76-2563-445c-81a2-e25a3f446473",
          "sha1"=>"9e81d6e1cd2aa612598b78f362d94534cedaff87", "version"=>"1.1"
        },
        "cloudcontroller"=>{
          "name"=>"cloudcontroller", "blobstore_id"=>"8cc08509-c5ff-42ce-9ad9-423a80beee83",
          "sha1"=>"40d5b9f0756aa5a22141bf78094b16b6d2c2b5e8", "version"=>"1.1-dev.1"
        },
        "ruby"=>{
          "name"=>"ruby", "blobstore_id"=>"12fbfc36-69be-4f40-81c8-bab238aaa19d",
          "sha1"=>"c5daee2106b4e948d722c7601ce8f5901e790627", "version"=>"1.1"
        }
      },
      "job"=>{
        "name"=>"cloudcontroller",
        "template" => "cloudcontroller",
        "blobstore_id"=>"fd03f94d-95c2-4581-8ae1-d11c96ca6910",
        "sha1"=>"9989206a20fe1ee70eb115287ab4d311a4236564",
        "version"=>"1.1-dev"
      },
      "index"=>0
    }
  end

  def new_spec
    tmp_spec = old_spec.dup
    tmp_spec['packages']['mysqlclient']['sha1'] = "foo_sha1"
    tmp_spec
  end


end
