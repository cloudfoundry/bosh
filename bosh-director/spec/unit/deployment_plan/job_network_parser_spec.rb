require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe JobNetworksParser do
    include Bosh::Director::IpUtil

    let(:job_networks_parser) { JobNetworksParser.new(Network::VALID_DEFAULTS) }
    let(:job_spec) do
      job = Bosh::Spec::Deployments.simple_manifest['jobs'].first
      job_network = job['networks'].first
      job_network['static_ips'] = ['192.168.1.1', '192.168.1.2']
      job
    end
    let(:manifest_networks) { [ManualNetwork.new('a', [], logger)] }

    context 'when instance group references a network not mentioned in the networks spec' do
      let(:manifest_networks) { [ManualNetwork.new('my-network', [], logger)] }

      it 'raises JobUnknownNetwork' do
        expect {
          job_networks_parser.parse(job_spec, 'job-name', manifest_networks)
        }.to raise_error BD::JobUnknownNetwork, "Instance group 'job-name' references an unknown network 'a'"
      end
    end

    context 'when instance group spec is missing network information' do
      let(:job_spec) do
        job = Bosh::Spec::Deployments.simple_manifest['jobs'].first
        job['networks'] = []
        job
      end

      it 'raises JobMissingNetwork' do
        expect {
          job_networks_parser.parse(job_spec, 'job-name', manifest_networks)
        }.to raise_error BD::JobMissingNetwork, "Instance group 'job-name' must specify at least one network"
      end
    end

    context 'when instance group network spec references dynamic network with static IPs' do
      let(:dynamic_network) { BD::DeploymentPlan::DynamicNetwork.new('a', [], logger)}
      let(:job_spec) do
        job = Bosh::Spec::Deployments.simple_manifest['jobs'].first
        job['networks'] = [{
          'name' => 'a',
          'static_ips' => ['10.0.0.2']
        }]
        job
      end

      it 'raises JobStaticIPNotSupportedOnDynamicNetwork' do
        expect {
          job_networks_parser.parse(job_spec, 'job-name', [dynamic_network])
        }.to raise_error BD::JobStaticIPNotSupportedOnDynamicNetwork, "Instance group 'job-name' using dynamic network 'a' cannot specify static IP(s)"
      end
    end

    context 'when instance group uses the same static IP more than once' do
      let(:job_spec) do
        job = Bosh::Spec::Deployments.simple_manifest['jobs'].first
        job_network = job['networks'].first
        job_network['static_ips'] = ['192.168.1.2', '192.168.1.2']
        job
      end

      it 'raises an error' do
        expect {
          job_networks_parser.parse(job_spec, 'job-name', manifest_networks)
        }.to raise_error BD::JobInvalidStaticIPs, "Instance group 'job-name' specifies static IP '192.168.1.2' more than once"
      end
    end

    context 'when called with a valid instance group spec' do
      it 'adds static ips to instance group networks in order as they are in manifest' do
        networks = job_networks_parser.parse(job_spec, 'job-name', manifest_networks)

        expect(networks.count).to eq(1)
        expect(networks.first).to be_a_job_network(
            JobNetwork.new('a', ['192.168.1.1', '192.168.1.2'], ['dns', 'gateway'], manifest_networks.first)
          )
        expect(networks.first.static_ips).to eq([ip_to_i('192.168.1.1'), ip_to_i('192.168.1.2')])
      end
    end

    RSpec::Matchers.define :be_a_job_network do |expected|
      match do |actual|
        actual.name == expected.name &&
          actual.static_ips == expected.static_ips.map { |ip_to_i| NetAddr::CIDR.create(ip_to_i) } &&
          actual.deployment_network == expected.deployment_network
      end
    end
  end
end
