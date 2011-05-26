require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::Apply do

  before(:each) do
    setup_tmp_base_dir

    Bosh::Agent::Config.state = Bosh::Agent::State.new(Tempfile.new("state").path)

    Bosh::Agent::Config.blobstore_provider = "simple"
    Bosh::Agent::Config.blobstore_options = {}

    FileUtils.mkdir_p(File.join(base_dir, 'monit'))
    Bosh::Agent::Monit.setup_monit_user

    # FIXME: use Dummy platform for tests
    system_root = Bosh::Agent::Config.system_root
    FileUtils.mkdir_p(File.join(system_root, 'etc', 'logrotate.d'))

    @httpclient = mock("httpclient")
    HTTPClient.stub!(:new).and_return(@httpclient)
  end

  it 'should set deployment in agents state if blank' do
    state = Bosh::Agent::Message::State.new(nil)
    state.stub!(:job_state).and_return("running")

    handler = Bosh::Agent::Message::Apply.new([{"deployment" => "foo"}])
    handler.apply

    state.state['deployment'].should == "foo"
  end

  it 'should install packages' do
    response = mock("response")
    response.stub!(:status).and_return(200)

    state = Bosh::Agent::Message::State.new(nil)

    package_sha1 = Digest::SHA1.hexdigest(dummy_package_data)
    apply_data = {
      "configuration_hash" => "bogus",
      "deployment" => "foo",
      "job" => { "name" => "bubba", "template" => "bubba", "blobstore_id" => "some_blobstore_id", "version" => "77" },
      "release" => { "version" => "99" },
      "networks" => { "network_a" => { "ip" => "11.0.0.1" } },
      "packages" =>
        {"bubba" =>
          { "name" => "bubba", "version" => "2", "blobstore_id" => "some_blobstore_id", "sha1" => package_sha1 }
      },
    }
    get_args = [ "/resources/some_blobstore_id", {}, {} ]
    @httpclient.should_receive(:get).with(*get_args).and_yield(dummy_package_data).and_return(response)

    handler = Bosh::Agent::Message::Apply.new([apply_data])
    handler.stub!(:apply_job)

    job_dir = File.join(Bosh::Agent::Config.base_dir, 'data', 'jobs', 'bubba', '77', 'packages')
    FileUtils.mkdir_p(job_dir)

    handler.apply
  end

  it 'should install a job' do
    response = mock("response")
    response.stub!(:status).and_return(200)

    state = Bosh::Agent::Message::State.new(nil)

    job_sha1 = Digest::SHA1.hexdigest(dummy_job_data)
    apply_data = {
      "configuration_hash" => "bogus",
      "deployment" => "foo",
      "job" => { "name" => "bubba", "template" => "bubba", "blobstore_id" => "some_blobstore_id", "version" => "77", "sha1" => job_sha1 },
      "release" => { "version" => "99" },
      "networks" => { "network_a" => { "ip" => "11.0.0.1" } }
    }
    get_args = [ "/resources/some_blobstore_id", {}, {} ]
    @httpclient.should_receive(:get).with(*get_args).and_yield(dummy_job_data).and_return(response)

    handler = Bosh::Agent::Message::Apply.new([apply_data])
    handler.stub!(:apply_packages)
    handler.apply

    bin_dir = File.join(Bosh::Agent::Config.base_dir, 'data', 'jobs', 'bubba', '77', 'bin')
    File.directory?(bin_dir).should == true

    bin_file = File.join(bin_dir, 'my_sinatra_app')
    File.executable?(bin_file).should == true
  end

end

