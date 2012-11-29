# Copyright (c) 2012 VMware, Inc.

require "spec_helper"
require "resolv"

describe "dns" do
  before(:all) do
    requirement stemcell
    requirement release

    @dns = Resolv::DNS.new(:nameserver => bosh_director)

    load_deployment_spec
    # TODO skip deployment if dns isn't enabled as this slows
    # down the testing
    use_static_ip
    @deployment = with_deployment
    bosh("deployment #{@deployment.to_path}")
    bosh("deploy")
  end

  after(:all) do
    bosh("delete deployment #{@deployment.name}")
    @deployment.delete

    cleanup release
    cleanup stemcell
  end

  before(:each) do
    load_deployment_spec
  end

  # raises Resolv::ResolvError if not found
  # Errno::ECONNREFUSED if not running
  # Resolv::ResolvTimeout
  context "external" do
    it "should to forward lookups" do
      pending "director not configured with dns" unless dns?
      address = @dns.getaddress("0.batlight.static.bat.bosh")
      address.to_s.should == static_ip
    end

    it "should do reverse lookups" do
      pending "director not configured with dns" unless dns?
      name = @dns.getname(static_ip)
      name.to_s.should == "0.batlight.static.bat.bosh"
    end
  end

  context "internal" do
    it "should be able to lookup of its own name" do
      pending "director not configured with dns" unless dns?
      cmd = "nslookup 0.batlight.static.bat.bosh"
      ssh(static_ip, "vcap", password, cmd).should match /#{static_ip}/
    end
  end

end
