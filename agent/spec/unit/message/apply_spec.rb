# Copyright (c) 2009-2012 VMware, Inc.

require File.dirname(__FILE__) + '/../../spec_helper'
require 'fileutils'

describe Bosh::Agent::Message::Apply do

  before(:each) do
    Bosh::Agent::Config.state = Bosh::Agent::State.new(Tempfile.new("state").path)

    Bosh::Agent::Config.blobstore_provider = "simple"
    Bosh::Agent::Config.blobstore_options = {}
    Bosh::Agent::Config.platform_name = "dummy"

    FileUtils.mkdir_p(File.join(base_dir, 'monit'))
    Bosh::Agent::Monit.setup_monit_user

    # FIXME: use Dummy platform for tests
    system_root = Bosh::Agent::Config.system_root
    FileUtils.mkdir_p(File.join(system_root, 'etc', 'logrotate.d'))

    @httpclient = mock("httpclient")
    HTTPClient.stub!(:new).and_return(@httpclient)
  end

  it "should raise a useful error when it fails to write an ERB template" do
    response = mock("response")
    response.stub!(:status).and_return(200)

    state = Bosh::Agent::Message::State.new

    job_sha1 = Digest::SHA1.hexdigest(dummy_job_data)
    apply_data = {
      "configuration_hash" => "bogus",
      "deployment" => "foo",
      "job" => { "name" => "bubba", "template" => "bubba", "blobstore_id" => "some_blobstore_id", "version" => "77", "sha1" => job_sha1 },
      "release" => { "version" => "99" }
    }
    get_args = [ "/resources/some_blobstore_id", {}, {} ]
    @httpclient.should_receive(:get).with(*get_args).and_yield(dummy_job_data).and_return(response)

    handler = Bosh::Agent::Message::Apply.new([apply_data])
    handler.stub!(:apply_packages)
    lambda {
      handler.apply
    }.should raise_error Bosh::Agent::MessageHandlerError,
    /Failed to install job 'bubba.bubba': failed to process configuration template 'thin.yml.erb': line 6, error:/
  end

  it 'should set deployment in agents state if blank' do
    state = Bosh::Agent::Message::State.new
    state.stub!(:job_state).and_return("running")

    handler = Bosh::Agent::Message::Apply.new([{"deployment" => "foo"}])
    handler.apply

    state.state['deployment'].should == "foo"
  end

  it 'should install packages' do
    state = Bosh::Agent::Message::State.new

    package_sha1 = Digest::SHA1.hexdigest(dummy_package_data)
    apply_data = {
      "configuration_hash" => "bogus",
      "deployment" => "foo",
      "job" => { "name" => "bubba", "template" => "bubba", "blobstore_id" => "some_blobstore_id", "version" => "77", "sha1" => "deadbeef" },
      "release" => { "version" => "99" },
      "networks" => { "network_a" => { "ip" => "11.0.0.1" } },
      "packages" =>
        {"bubba" =>
          { "name" => "bubba", "version" => "2", "blobstore_id" => "some_blobstore_id", "sha1" => package_sha1 }
      },
    }
    get_args = [ "/resources/some_blobstore_id", {}, {} ]
    @httpclient.should_receive(:get).with(*get_args).and_yield(dummy_package_data).and_return(http_200_response_mock)

    handler = Bosh::Agent::Message::Apply.new([apply_data])
    handler.stub!(:apply_job)

    job_dir = File.join(Bosh::Agent::Config.base_dir, 'data', 'jobs', 'bubba', '77', 'packages')
    FileUtils.mkdir_p(job_dir)

    handler.apply
  end

  # A bit of a mess - but we have to invoke apply 3 times with different apply specs in order for package GC to happen
  it "should clean up old packages" do
    state = Bosh::Agent::Message::State.new

    job_dir = File.join(base_dir, 'data', 'jobs', 'bubba', '77', 'packages')
    FileUtils.mkdir_p(job_dir)
    pkg_base = File.join(base_dir, 'data', 'packages')

    get_args = [ "/resources/some_blobstore_id", {}, {} ]
    @httpclient.should_receive(:get).exactly(7).times.with(*get_args).and_yield(dummy_package_data).and_return(http_200_response_mock)
    package_sha1 = Digest::SHA1.hexdigest(dummy_package_data)

    # 1st apply - against empty state
    apply_data1 = {
      "configuration_hash" => "bogus",
      "deployment" => "foo",
      "job" => { "name" => "bubba", "template" => "bubba", "blobstore_id" => "some_blobstore_id", "version" => "77", "sha1" => "deadbeef" },
      "release" => { "version" => "99" },
      "networks" => { "network_a" => { "ip" => "11.0.0.1" } },
      "packages" =>
        {"bubba0" => { "name" => "bubba0", "version" => "2", "blobstore_id" => "some_blobstore_id", "sha1" => package_sha1 },
         "bubba1" => { "name" => "bubba1", "version" => "2", "blobstore_id" => "some_blobstore_id", "sha1" => package_sha1 },
         "bubba2" => { "name" => "bubba2", "version" => "2", "blobstore_id" => "some_blobstore_id", "sha1" => package_sha1 },
         "bubba3" => { "name" => "bubba3", "version" => "2", "blobstore_id" => "some_blobstore_id", "sha1" => package_sha1 }
      },
    }
    handler1 = Bosh::Agent::Message::Apply.new([apply_data1])
    handler1.stub!(:apply_job)
    handler1.apply

    pkg_paths = spec_package_paths(pkg_base, apply_data1)
    pkg_paths.sort.should == installed_packages(pkg_base).sort

    # 2nd apply - package path list is the union of 1st and 2nd apply
    apply_data2 = apply_data1.dup
    apply_data2['packages'] =
      {
         "bubba3" => { "name" => "bubba3", "version" => "3", "blobstore_id" => "some_blobstore_id", "sha1" => package_sha1 },
         "bubba4" => { "name" => "bubba4", "version" => "2", "blobstore_id" => "some_blobstore_id", "sha1" => package_sha1 }
      }
    handler2 = Bosh::Agent::Message::Apply.new([apply_data2])
    handler2.stub!(:apply_job)
    handler2.apply

    pkg_paths2 = spec_package_paths(pkg_base, apply_data2)
    check_package_paths = pkg_paths2 + pkg_paths

    check_package_paths.sort.should == installed_packages(pkg_base).sort

    # 3rd apply - package path list is the union of 2nd and 3rd apply (with 1st deploy cleaned up)
    apply_data3 = apply_data2.dup
    apply_data3['packages'] =
      {
         "bubba4" => { "name" => "bubba3", "version" => "2", "blobstore_id" => "some_blobstore_id", "sha1" => package_sha1 }
      }
    handler3 = Bosh::Agent::Message::Apply.new([apply_data3])
    handler3.stub!(:apply_job)
    handler3.apply

    pkg_paths3 = spec_package_paths(pkg_base, apply_data3)
    check_package_paths = pkg_paths3 + pkg_paths2

    check_package_paths.sort.should == installed_packages(pkg_base).sort
  end

  it 'should install a job' do
    response = mock("response")
    response.stub!(:status).and_return(200)

    state = Bosh::Agent::Message::State.new

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

  it 'should install a job with a .monit file' do
    response = mock("response")
    response.stub!(:status).and_return(200)

    state = Bosh::Agent::Message::State.new

    job_data = read_asset('hubba.tgz')
    job_sha1 = Digest::SHA1.hexdigest(job_data)
    apply_data = {
      "configuration_hash" => "bogus",
      "deployment" => "foo",
      "job" => { "name" => "hubba", "template" => "hubba", "blobstore_id" => "some_blobstore_id", "version" => "77", "sha1" => job_sha1 },
      "release" => { "version" => "99" },
      "networks" => { "network_a" => { "ip" => "11.0.0.1" } }
    }
    get_args = [ "/resources/some_blobstore_id", {}, {} ]
    @httpclient.should_receive(:get).with(*get_args).and_yield(job_data).and_return(response)

    handler = Bosh::Agent::Message::Apply.new([apply_data])
    handler.stub!(:apply_packages)
    handler.apply

    monitrc = File.join(Bosh::Agent::Config.base_dir, 'data', 'jobs', 'hubba', '77', 'hubba.hubba_hubba.monitrc')
    File.exist?(monitrc).should == true
  end

  it 'should install two jobs with two .monit files' do
    response = mock("response")
    response.stub!(:status).and_return(200)

    state = Bosh::Agent::Message::State.new

    job_data = read_asset('hubba.tgz')
    job2_data = read_asset('hubba2.tgz')
    job_sha1 = Digest::SHA1.hexdigest(job_data)
    job2_sha1 = Digest::SHA1.hexdigest(job2_data)
    apply_data = {
      "configuration_hash" => "bogus",
      "deployment" => "foo",
      "job" => { "name" => "hubba", "templates" => [
        {"name" => "hubba", "blobstore_id" => "some_blobstore_id", "version" => "77", "sha1" => job_sha1 },
        {"name" => "hubba2", "blobstore_id" => "some_blobstore_id2", "version" => "77", "sha1" => job2_sha1 }] },
      "release" => { "version" => "99" },
      "networks" => { "network_a" => { "ip" => "11.0.0.1" } }
    }
    get_args = [ "/resources/some_blobstore_id", {}, {} ]
    get_args2 = [ "/resources/some_blobstore_id2", {}, {} ]
    @httpclient.should_receive(:get).with(*get_args).and_yield(job_data).and_return(response)
    @httpclient.should_receive(:get).with(*get_args2).and_yield(job2_data).and_return(response)

    handler = Bosh::Agent::Message::Apply.new([apply_data])
    handler.stub!(:apply_packages)
    handler.apply

    monitrc1 = File.join(Bosh::Agent::Config.base_dir, 'data', 'jobs', 'hubba', '77', 'hubba.hubba_hubba.monitrc')
    File.exist?(monitrc1).should == true

    monitrc2 = File.join(Bosh::Agent::Config.base_dir, 'data', 'jobs', 'hubba2', '77', 'hubba.hubba2_hubba.monitrc')
    File.exist?(monitrc2).should == true
  end

  def http_200_response_mock
    response = mock("response")
    response.stub!(:status).and_return(200)
    response
  end

  def installed_packages(pkg_base)
    installed_pkgs = Dir["#{pkg_base}/*/*"]
  end

  def spec_package_paths(pkg_base, apply_spec)
    pkg_paths = []
    apply_spec['packages'].each do |k, v|
      pkg_paths << File.join(pkg_base, v['name'], v['version'])
    end
    pkg_paths
  end


end

