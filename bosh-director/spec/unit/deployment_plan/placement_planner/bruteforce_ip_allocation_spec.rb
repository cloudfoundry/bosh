require 'spec_helper'

module Bosh::Director::DeploymentPlan::PlacementPlanner
  describe BruteForceIpAllocation do
    subject(:bruteforce_ip_allocation) do
      described_class.new(networks_to_static_ips)
    end

    context 'when easy' do
      let(:networks_to_static_ips) do
        {
          'network-1' => [
            NetworksToStaticIps::StaticIpToAzs.new('ip-1', ['z2', 'z1']),
            NetworksToStaticIps::StaticIpToAzs.new('ip-2', ['z2']),
          ],
          'network-2' => [
            NetworksToStaticIps::StaticIpToAzs.new('ip-3', ['z2']),
            NetworksToStaticIps::StaticIpToAzs.new('ip-4', ['z1']),
          ],
        }
      end

      it 'returns combination of IPs to one AZ per network with even distribution of IPs per AZ' do
        expected_networks_to_static_ips = {
          'network-1' => [
            NetworksToStaticIps::StaticIpToAzs.new('ip-1', ['z1']),
            NetworksToStaticIps::StaticIpToAzs.new('ip-2', ['z2']),
          ],
          'network-2' => [
            NetworksToStaticIps::StaticIpToAzs.new('ip-3', ['z2']),
            NetworksToStaticIps::StaticIpToAzs.new('ip-4', ['z1']),
          ],
        }

        expect(
          bruteforce_ip_allocation.find_best_combination
        ).to eq(
            expected_networks_to_static_ips
          )
      end
    end

    context 'when complex' do
      let(:networks_to_static_ips) do
        {
          'network-1' => [
            NetworksToStaticIps::StaticIpToAzs.new('ip-1', ['z2', 'z1', 'z3']),
            NetworksToStaticIps::StaticIpToAzs.new('ip-2', ['z1', 'z2', 'z3']),
            NetworksToStaticIps::StaticIpToAzs.new('ip-3', ['z3', 'z2', 'z1']),
          ],
          'network-2' => [
            NetworksToStaticIps::StaticIpToAzs.new('ip-4', ['z3', 'z1']),
            NetworksToStaticIps::StaticIpToAzs.new('ip-5', ['z2']),
            NetworksToStaticIps::StaticIpToAzs.new('ip-6', ['z1', 'z3']),
          ],
          'network-3' => [
            NetworksToStaticIps::StaticIpToAzs.new('ip-7', ['z1']),
            NetworksToStaticIps::StaticIpToAzs.new('ip-8', ['z2', 'z3']),
            NetworksToStaticIps::StaticIpToAzs.new('ip-9', ['z3', 'z2']),
          ],
        }
      end

      it 'returns combination of IPs to one AZ per network with even distribution of IPs per AZ' do
        allocated_ips = bruteforce_ip_allocation.find_best_combination
        expect(allocated_ips['network-1'].map(&:az_names)).to match_array([['z1'], ['z2'], ['z3']])
        expect(allocated_ips['network-2'].map(&:az_names)).to match_array([['z1'], ['z2'], ['z3']])
        expect(allocated_ips['network-3'].map(&:az_names)).to match_array([['z1'], ['z2'], ['z3']])
      end
    end

    context 'when a lot of instances' do

      let(:networks_to_static_ips) do
        number_of_instances = 12
        azs = ['z1', 'z2', 'z3']
        {
          'network-1' => ips_for_network(number_of_instances, azs),
          'network-2' => ips_for_network(number_of_instances, azs),
          'network-3' => ips_for_network(number_of_instances, azs),
        }
      end

      it 'returns combination of IPs to one AZ per network with even distribution of IPs per AZ' do
        allocated_ips_per_networks = bruteforce_ip_allocation.find_best_combination
        z1_ips = 0
        z2_ips = 0
        z3_ips = 0

        allocated_ips_per_networks.each do |_, ips|
          z1_ips += ips.select do |ip_to_azs|
            ip_to_azs.az_names.first == 'z1'
          end.size
          z2_ips += ips.select do |ip_to_azs|
            ip_to_azs.az_names.first == 'z2'
          end.size
          z3_ips += ips.select do |ip_to_azs|
            ip_to_azs.az_names.first == 'z3'
          end.size
        end

        expect(z1_ips).to eq(12)
        expect(z2_ips).to eq(12)
        expect(z3_ips).to eq(12)
      end
    end

    context 'when not even distribution' do
      let(:networks_to_static_ips) do
        {
          'network-1' => [
            ips_for_network(20, ['z1']),
            ips_for_network(10, ['z1', 'z2'])
          ].flatten,
          'network-2' => [
            ips_for_network(20, ['z1']),
            ips_for_network(10, ['z1', 'z2'])
          ].flatten
        }
      end

      it 'returns IPs distributed by zone requirements ' do
        allocated_ips_per_networks = bruteforce_ip_allocation.find_best_combination
        z1_ips = 0
        z2_ips = 0

        allocated_ips_per_networks.each do |_, ips|
          z1_ips += ips.select do |ip_to_azs|
            ip_to_azs.az_names.first == 'z1'
          end.size
          z2_ips += ips.select do |ip_to_azs|
            ip_to_azs.az_names.first == 'z2'
          end.size
        end

        expect(z1_ips).to eq(40)
        expect(z2_ips).to eq(20)
      end
    end

    context 'when it is not possible to find a good combination' do
      let(:networks_to_static_ips) do
        {
          'network-1' => [
            NetworksToStaticIps::StaticIpToAzs.new('ip-1', ['z1', 'z2']),
            NetworksToStaticIps::StaticIpToAzs.new('ip-2', ['z2', 'z3']),
          ],
          'network-2' => [
            NetworksToStaticIps::StaticIpToAzs.new('ip-3', ['z4']),
            NetworksToStaticIps::StaticIpToAzs.new('ip-4', ['z1', 'z3']),
          ]
        }
      end

      it 'returns nil' do
        expect(
          bruteforce_ip_allocation.find_best_combination
        ).to eq(nil)
      end
    end

    def ips_for_network(number_of_instances, azs)
      ips = []
      number_of_instances.times do |i|
        ips << NetworksToStaticIps::StaticIpToAzs.new("ip-#{i}", azs)
      end
      ips
    end

  end
end
