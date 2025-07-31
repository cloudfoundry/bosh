require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe InstanceGroupNetworksParser do
    include Bosh::Director::IpUtil

    let(:instance_group_networks_parser) { InstanceGroupNetworksParser.new(Network::REQUIRED_DEFAULTS, Network::OPTIONAL_DEFAULTS) }
    let(:instance_group_spec) do
      instance_group = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups['instance_groups'].first
      instance_group_network = instance_group['networks'].first
      instance_group_network['static_ips'] = ['192.168.1.1', '192.168.1.2']
      instance_group
    end
    let(:manifest_networks) { [ManualNetwork.new('a', [], '32', per_spec_logger)] }

    context 'when instance group references a network not mentioned in the networks spec' do
      let(:manifest_networks) { [ManualNetwork.new('my-network', [], '32', per_spec_logger)] }

      it 'raises JobUnknownNetwork' do
        expect do
          instance_group_networks_parser.parse(instance_group_spec, 'instance-group-name', manifest_networks)
        end.to raise_error Bosh::Director::JobUnknownNetwork, "Instance group 'instance-group-name' references an unknown network 'a'"
      end
    end

    context 'when instance group spec is missing network information' do
      let(:instance_group_spec) do
        instance_group = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups['instance_groups'].first
        instance_group['networks'] = []
        instance_group
      end

      it 'raises JobMissingNetwork' do
        expect do
          instance_group_networks_parser.parse(instance_group_spec, 'instance-group-name', manifest_networks)
        end.to raise_error Bosh::Director::JobMissingNetwork, "Instance group 'instance-group-name' must specify at least one network"
      end
    end

    context 'when instance group network spec references dynamic network with static IPs' do
      let(:dynamic_network) { Bosh::Director::DeploymentPlan::DynamicNetwork.new('a', [], '32', per_spec_logger) }
      let(:instance_group_spec) do
        instance_group = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups['instance_groups'].first
        instance_group['networks'] = [{
          'name' => 'a',
          'static_ips' => ['10.0.0.2'],
        }]
        instance_group
      end

      it 'raises JobStaticIPNotSupportedOnDynamicNetwork' do
        expect do
          instance_group_networks_parser.parse(instance_group_spec, 'instance-group-name', [dynamic_network])
        end.to raise_error Bosh::Director::JobStaticIPNotSupportedOnDynamicNetwork, "Instance group 'instance-group-name' using dynamic network 'a' cannot specify static IP(s)"
      end
    end

    context 'when instance group uses the same static IP more than once' do
      let(:instance_group_spec) do
        instance_group = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups['instance_groups'].first
        instance_group_network = instance_group['networks'].first
        instance_group_network['static_ips'] = ['192.168.1.2', '192.168.1.2']
        instance_group
      end

      it 'raises an error' do
        expect do
          instance_group_networks_parser.parse(instance_group_spec, 'instance-group-name', manifest_networks)
        end.to raise_error Bosh::Director::JobInvalidStaticIPs, "Instance group 'instance-group-name' specifies static IP '192.168.1.2' more than once"
      end
    end

    context 'when called with a valid instance group spec' do
      let(:subnet_spec) do
        {
          'range' => '192.168.1.0/24',
          'gateway' => '192.168.1.1'
        }
      end
      let(:manifest_networks) { [ManualNetwork.new('a', [ManualNetworkSubnet.parse('a', subnet_spec, "")], '32', per_spec_logger)] }

      let(:instance_group_spec) do
        instance_group = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups['instance_groups'].first
        instance_group['networks'] = [{
          'name' => 'a',
          'static_ips' => ['192.168.1.1', '192.168.1.2'],
        }]
        instance_group
      end


      it 'adds static ips to instance group networks in order as they are in manifest' do
        networks = instance_group_networks_parser.parse(instance_group_spec, 'instance-group-name', manifest_networks)

        expect(networks.count).to eq(1)
        expect(networks.first).to be_an_instance_group_network(
                                    FactoryBot.build(:deployment_plan_job_network,
                                                     name: 'a',
                                                     static_ips: ['192.168.1.1', '192.168.1.2'],
                                                     default_for: %w[dns gateway],
                                                     deployment_network: manifest_networks.first                                    ),
        )
        expect(networks.first.static_ips).to eq(['192.168.1.1', '192.168.1.2'])
      end
    end

    context 'when called with a valid instance group spec containing two networks' do
      let(:subnet_spec) do
        {
          'range' => '192.168.1.0/24',
          'gateway' => '192.168.1.1'
        }
      end
      let(:subnet_spec_ipv6) do
        {
          'range' => '2001:db8::/112',
          'gateway' => '2001:db8::1'
        }
      end
      let(:manifest_network) { ManualNetwork.new('a', [ManualNetworkSubnet.parse('a', subnet_spec, "")], '32', per_spec_logger) }
      let(:manifest_network_ipv6) { ManualNetwork.new('a_ipv6', [ManualNetworkSubnet.parse('a_ipv6', subnet_spec_ipv6, "")], '128', per_spec_logger) }
      let(:two_manifest_networks) { [manifest_network, manifest_network_ipv6] }

      let(:instance_group_spec) do
        instance_group = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups['instance_groups'].first
        instance_group['networks'] = [{
          'name' => 'a',
          'static_ips' => ['192.168.1.1', '192.168.1.2'],
        },
        {
          'name' => 'a_ipv6',
          'static_ips' => ['2001:db8::1', '2001:db8::2'],
        }
        ]
        instance_group
      end
      let(:instance_group_spec_with_defaults) do
        instance_group = SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups['instance_groups'].first
        instance_group['networks'] = [{
          'name' => 'a',
          'static_ips' => ['192.168.1.1', '192.168.1.2'],
          'default' => ['dns', 'gateway'],
        },
        {
          'name' => 'a_ipv6',
          'static_ips' => ['2001:db8::1', '2001:db8::2'],
        }
        ]
        instance_group
      end


      it 'issues an error if no default for dns and gateway is defined' do
        expect do
          instance_group_networks_parser.parse(instance_group_spec, 'instance-group-name', two_manifest_networks)
        end.to raise_error Bosh::Director::JobNetworkMissingDefault, "Instance group 'instance-group-name' must specify which network is default for dns, gateway, since it has more than one network configured"
      end

      it 'adds static ips to instance group networks in order as they are in manifest' do
        networks = instance_group_networks_parser.parse(instance_group_spec_with_defaults, 'instance-group-name', two_manifest_networks)

        expect(networks.count).to eq(2)
        expect(networks.first).to be_an_instance_group_network(
                                    FactoryBot.build(:deployment_plan_job_network,
                                                     name: 'a',
                                                     static_ips: ['192.168.1.1', '192.168.1.2'],
                                                     default_for: %w[dns gateway],
                                                     deployment_network: manifest_network                                    ),
        )
        expect(networks.first.static_ips.map { |ip| ip.base_addr }).to eq(['192.168.1.1', '192.168.1.2'])
        expect(networks[1].static_ips.map { |ip| ip.base_addr }).to eq(['2001:db8::1', '2001:db8::2'])
      end
    end

    RSpec::Matchers.define :be_an_instance_group_network do |expected|
      match do |actual|
        actual.name == expected.name &&
          actual.static_ips.map { |ip| ip.base_addr } == expected.static_ips &&
          actual.deployment_network == expected.deployment_network
      end
    end
  end
end
