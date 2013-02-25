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

  # Have to look up both BOSH and MicroBOSH tld in these tests since we don't know what type of BOSH
  # we're testing against (*.bosh and *.microbosh)
  context "external" do
    it "should do forward lookups" do
      pending "director not configured with dns" unless dns?
      begin
        address_on_bosh = @dns.getaddress("0.batlight.static.bat.bosh").to_s
      rescue Resolv::ResolvError
        begin
          address_on_microbosh = @dns.getaddress("0.batlight.static.bat.microbosh").to_s
        rescue Resolv::ResolvError
        end
      end
      [address_on_bosh, address_on_microbosh].should include static_ip
    end

    it "should do reverse lookups" do
      pending "director not configured with dns" unless dns?
      name = @dns.getname(static_ip)
      ["0.batlight.static.bat.bosh", "0.batlight.static.bat.microbosh"].should include name.to_s
    end
  end

  context "internal" do
    it "should be able to lookup of its own name", ssh: true do
      pending "director not configured with dns" unless dns?
      cmd = "dig +short 0.batlight.static.bat.bosh a 0.batlight.static.bat.microbosh a"
      ssh(static_ip, "vcap", password, cmd).should match /#{static_ip}/
    end
  end

end
