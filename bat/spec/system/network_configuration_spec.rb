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
    before { skip 'director not configured with dns' unless dns? }

    let(:dns) { Resolv::DNS.new(nameserver: @env.dns_host) }

    it 'forward looks up instance' do
      address = nil
      expect {
        address = dns.getaddress("0.batlight.static.bat.#{bosh_tld}").to_s
      }.not_to raise_error, "this test tries to resolve to the public IP of director, so you need to have incoming UDP enabled for it"
      expect(address).to eq(public_ip)
    end

    it 'reverse looks up instance' do
      name = dns.getname(public_ip).to_s
      expect(name).to eq("0.batlight.static.bat.#{bosh_tld}")
    end

    it 'resolves instance names from deployed VM' do
      # Temporarily add to debug why dig is returning 'connection timed out'
      resolv_conf = ssh(public_ip, 'vcap', 'cat /etc/resolv.conf', ssh_options)
      @logger.info("Contents of resolv.conf '#{resolv_conf}'")

      bosh('logs batlight 0 --agent --dir /tmp')

      cmd = 'dig +short 0.batlight.static.bat.bosh a 0.batlight.static.bat.microbosh a'
      expect(ssh(public_ip, 'vcap', cmd, ssh_options)).to include(public_ip)
    end
  end

  describe 'changing instance DNS (exercises configure_networks CPI method)' do
    before do
      skip 'director not configured with dns' unless dns?
      unless @requirements.stemcell.supports_network_reconfiguration?
        skip "network reconfiguration does not work for #{@requirements.stemcell}"
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
      expect(bosh("deployment #{manifest_with_different_dns.to_path}")).to succeed
      expect(bosh('deploy')).to succeed
      expect(ssh(public_ip, 'vcap', 'cat /etc/resolv.conf', ssh_options)).to include('127.0.0.5')
    end
  end

  context 'when using manual networking' do
    before do
      skip "not using manual networking" unless manual_networking?
    end

    it 'changes static IP address' do
      unless @requirements.stemcell.supports_changing_static_ip?(network_type)
        skip "network reconfiguration does not work for #{@requirements.stemcell}"
      end

      use_second_static_ip
      deployment = with_deployment
      expect(bosh("deployment #{deployment.to_path}")).to succeed
      expect(bosh('deploy')).to succeed

      expect(ssh(public_ip, 'vcap', '/sbin/ifconfig', ssh_options)).to include(second_static_ip)
    end

    it 'deploys multiple manual networks' do
      unless @requirements.stemcell.supports_multiple_manual_networks?
        skip "multiple manual networks are not supported for #{@requirements.stemcell}"
      end

      use_multiple_manual_networks
      deployment = with_deployment
      expect(bosh("deployment #{deployment.to_path}")).to succeed
      expect(bosh('deploy')).to succeed

      expect(ssh(public_ip, 'vcap', '/sbin/ifconfig', ssh_options)).to include(static_ips[0])
      expect(ssh(public_ip, 'vcap', '/sbin/ifconfig', ssh_options)).to include(static_ips[1])
    end
  end
end
