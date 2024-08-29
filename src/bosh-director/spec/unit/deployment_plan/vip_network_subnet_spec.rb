require 'spec_helper'
require 'unit/deployment_plan/subnet_spec'

describe Bosh::Director::DeploymentPlan::VipNetworkSubnet do
  include Bosh::Director::IpUtil

  let(:network_name) { 'network' }

  let(:subnet_spec) do
    {
      'azs' => %w[z1 z2],
      'static' => ['69.69.69.69', '70.70.70.70-70.70.70.71', '80.80.80.0/31'],
    }
  end

  let(:azs) do
    [
      Bosh::Director::DeploymentPlan::AvailabilityZone.new('z1', {}),
      Bosh::Director::DeploymentPlan::AvailabilityZone.new('z2', {}),
    ]
  end

  it_behaves_like 'a subnet'

  describe :parse do
    it 'parses the static ips from the list of requested ips' do
      vip_subnet = Bosh::Director::DeploymentPlan::VipNetworkSubnet.parse(subnet_spec, network_name, azs)
      expect(vip_subnet.static_ips.size).to eq(5)

      vip_static_ips = vip_subnet.static_ips.map do |static_ip|
        format_ip(static_ip)
      end
      expect(vip_static_ips).to include(
        '69.69.69.69',
        '70.70.70.70',
        '70.70.70.71',
        '80.80.80.0',
        '80.80.80.1',
      )
    end

    it 'checks the availability zones for their validity' do
      vip_subnet = Bosh::Director::DeploymentPlan::VipNetworkSubnet.parse(subnet_spec, network_name, azs)
      expect(vip_subnet.availability_zone_names).to eq(%w[z1 z2])
    end
  end
end
