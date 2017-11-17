require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::InstanceNetworkReservations do
    let(:deployment_model) { Models::Deployment.make(name: 'foo-deployment') }
    let(:cloud_config) { Models::Config.make(:cloud_with_manifest_v2) }
    let(:runtime_config) { Models::Config.make(type: 'runtime') }
    let(:deployment) do
      DeploymentPlan::Planner.new(
        {name: 'foo-deployment', properties: {}},
        '',
        '',
        cloud_config,
        runtime_config,
        deployment_model
      )
    end
    let(:network) do
      DeploymentPlan::ManualNetwork.new('fake-network', [], logger)
    end
    let(:instance_model) { Models::Instance.make(deployment: deployment_model) }
    let!(:variable_set) { Models::VariableSet.make(deployment: deployment_model) }
    let(:ip_provider) { DeploymentPlan::IpProvider.new(DeploymentPlan::InMemoryIpRepo.new(logger), {'fake-network' => network}, logger) }
    before do
      allow(deployment).to receive(:network).with('fake-network').and_return(network)
      allow(deployment).to receive(:ip_provider).and_return(ip_provider)
    end

    describe 'create_from_db' do
      context 'when there are IP addresses in db' do
        let(:ip1) { NetAddr::CIDR.create('192.168.0.1').to_i }
        let(:ip2) { NetAddr::CIDR.create('192.168.0.2').to_i }

        before do
          ip_model1 = Models::IpAddress.make(address_str: ip1.to_s, network_name: 'fake-network')
          instance_model.add_ip_address(ip_model1)
          ip_model2 = Models::IpAddress.make(address_str: ip2.to_s, network_name: 'fake-network')
          instance_model.add_ip_address(ip_model2)
        end

        it 'creates reservations based on IP addresses' do
          reservations = DeploymentPlan::InstanceNetworkReservations.create_from_db(instance_model, deployment, logger)
          expect(reservations.map(&:ip)).to eq([ip1, ip2])
        end
      end

      context 'when instance has dynamic networks in spec' do
        let(:instance_model) { Models::Instance.make(deployment: deployment_model, spec: instance_spec) }
        let(:instance_spec) do
          {
            'networks' => {
              'dynamic-network' => {
                'type' => 'dynamic',
                'ip' => '10.10.0.10'
              }
            }
          }
        end

        let(:dynamic_network) do
          DeploymentPlan::DynamicNetwork.new('dynamic-network', [], logger)
        end
        before do
          allow(deployment).to receive(:network).with('dynamic-network').and_return(dynamic_network)
        end

        it 'creates reservations for dynamic networks' do
          reservations = DeploymentPlan::InstanceNetworkReservations.create_from_db(instance_model, deployment, logger)
          expect(reservations.first).to_not be_nil
          expect(reservations.first.ip).to eq(NetAddr::CIDR.create('10.10.0.10').to_i)
        end
      end
    end
  end
end
