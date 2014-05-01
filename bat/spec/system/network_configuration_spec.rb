require 'system/spec_helper'

describe 'network configuration' do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  before(:all) do
    load_deployment_spec
    use_static_ip
    use_vip
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
      address.should eq(public_ip)
    end

    it 'reverse looks up instance' do
      name = dns.getname(public_ip).to_s
      name.should eq("0.batlight.static.bat.#{bosh_tld}")
    end

    it 'resolves instance names from deployed VM' do
      # Temporarily add to debug why dig is returning 'connection timed out'
      resolv_conf = ssh(public_ip, 'vcap', 'cat /etc/resolv.conf', ssh_options)
      @logger.info("Contents of resolv.conf '#{resolv_conf}'")

      bosh('logs batlight 0 --agent --dir /tmp')

      cmd = 'dig +short 0.batlight.static.bat.bosh a 0.batlight.static.bat.microbosh a'
      ssh(public_ip, 'vcap', cmd, ssh_options).should include(public_ip)
    end
  end

  describe 'changing instance DNS (exercises configure_networks CPI method)' do
    before do
      pending 'director not configured with dns' unless dns?
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
      ssh(public_ip, 'vcap', 'cat /etc/resolv.conf', ssh_options).should include('127.0.0.5')
    end
  end

  context 'when using manual networking' do
    before do
      unless @requirements.stemcell.supports_changing_static_ip?(network_type)
        pending "network reconfiguration does not work for #{@requirements.stemcell}"
      end
    end

    it 'changes static IP address' do
      use_second_static_ip
      deployment = with_deployment
      bosh("deployment #{deployment.to_path}").should succeed
      bosh('deploy').should succeed

      ssh(public_ip, 'vcap', '/sbin/ifconfig', ssh_options).should include(second_static_ip)
    end
  end
end
