require 'system/spec_helper'

describe 'network configuration' do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  before(:all) do
    load_deployment_spec
    use_static_ip
    @requirements.requirement(deployment, @spec) # 2.5 min on local vsphere
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  describe 'resolving DNS entries' do
    before { pending 'director not configured with dns' unless dns? }

    let(:dns) { Resolv::DNS.new(nameserver: @env.director) }

    it 'forward looks up instance' do
      address = dns.getaddress("0.batlight.static.bat.#{bosh_tld}").to_s
      address.should eq(static_ip)
    end

    it 'reverse looks up instance' do
      name = dns.getname(static_ip).to_s
      name.should eq("0.batlight.static.bat.#{bosh_tld}")
    end

    it 'resolves instance names from deployed VM' do
      cmd = 'dig +short 0.batlight.static.bat.bosh a 0.batlight.static.bat.microbosh a'
      ssh(static_ip, 'vcap', cmd, ssh_options).should include(static_ip)
    end
  end

  describe 'changing instance DNS (exercises configure_networks CPI method)' do
    before do
      unless @requirements.stemcell.supports_network_reconfiguration?
        pending "network reconfiguration does not work for #{@requirements.stemcell}"
      end
    end

    let(:manifest_with_different_dns) do
      # Need to include a valid DNS host so that other tests
      # can still use dns resolution on the deployed VM
      use_additional_dns_server('127.0.0.5')
      with_deployment
    end

    after { manifest_with_different_dns.delete }

    it 'successfully reconfigures VM with new DNS nameservers' do
      bosh("deployment #{manifest_with_different_dns.to_path}").should succeed
      bosh('deploy').should succeed
      ssh(static_ip, 'vcap', 'cat /etc/resolv.conf', ssh_options).should include('127.0.0.5')
    end
  end
end
