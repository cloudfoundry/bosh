# Copyright (c) 2012 VMware, Inc.

require "spec_helper"
require "resolv"

describe "dns" do
  before(:all) do
    if dns?
      requirement stemcell
      requirement release

      @dns = Resolv::DNS.new(:nameserver => bosh_director)

      load_deployment_spec
      use_static_ip
      @deployment = with_deployment
      bosh("deployment #{@deployment.to_path}")
      bosh("deploy")
    end
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
    it "should do forward lookups" do
      pending "director not configured with dns" unless dns?
      address = @dns.getaddress("0.batlight.static.bat.#{bosh_tld}").to_s
      address.should == static_ip
    end

    it "should do reverse lookups" do
      pending "director not configured with dns" unless dns?
      name = @dns.getname(static_ip)
      name.to_s.should == "0.batlight.static.bat.#{bosh_tld}"
    end
  end

  context "internal" do
    it "should be able to lookup of its own name", ssh: true do
      pending "director not configured with dns" unless dns?
      cmd = "dig +short 0.batlight.static.bat.bosh a 0.batlight.static.bat.microbosh a"
      ssh(static_ip, "vcap", cmd, ssh_options).should match /#{static_ip}/
    end
  end

end
