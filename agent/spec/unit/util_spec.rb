require File.dirname(__FILE__) + '/../spec_helper'

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

    lambda {
      Bosh::Agent::Util.unpack_blob(blobstore_id, "bogus_sha1", install_dir)
    }.should raise_error(Bosh::Agent::MessageHandlerError, /Expected sha1/)
  end

  it "should return a binding with config variable" do
    config_hash = { "job" => { "name" => "funky_job_name"} }
    config_binding = Bosh::Agent::Util.config_binding(config_hash)

    template = ERB.new("job name: <%= spec.job.name %>")

    lambda {
      template.result(binding)
    }.should raise_error(NameError)

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

    lambda {
      Bosh::Agent::Util.run_hook('post-install', job_name)
    }.should raise_error(Bosh::Agent::MessageHandlerError, "`post-install' hook for `hubba' job is not an executable file")

    FileUtils.chmod(0700, hook_file)
    Bosh::Agent::Util.run_hook('post-install', job_name).should == "yay"
  end

end
