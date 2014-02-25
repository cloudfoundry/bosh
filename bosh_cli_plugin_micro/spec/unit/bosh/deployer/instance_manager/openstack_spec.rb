require 'spec_helper'
require 'bosh/deployer/instance_manager/openstack'
require 'bosh/deployer/registry'

module Bosh::Deployer
  describe InstanceManager::Openstack do
    subject(:openstack) { described_class.new(instance_manager, config, logger) }

    let(:instance_manager) { instance_double('Bosh::Deployer::InstanceManager') }
    let(:config) do
      instance_double(
        'Bosh::Deployer::Configuration',
        cloud_options: {
          'properties' => {
            'registry' => {
              'endpoint' => 'fake-registry-endpoint',
            },
            'openstack' => {
              'private_key' => 'fake-private-key',
            },
          },
        },
      )
    end
    let(:logger) { instance_double('Logger') }
    let(:registry) { instance_double('Bosh::Deployer::Registry') }

    before do
      allow(Registry).to receive(:new).and_return(registry)
      allow(File).to receive(:exists?).with(/\/fake-private-key$/).and_return(true)
    end

    ip_address_methods = %w(internal_services_ip agent_services_ip client_services_ip)
    ip_address_methods.each do |method|
      describe "##{method}" do
        let(:state) { double('state', vm_cid: nil) }

        it 'returns instance managers idea of what bosh_ip should be' do
          allow(instance_manager).to receive(:state).and_return(state)
          allow(instance_manager).to receive(:bosh_ip).and_return('fake bosh ip')

          expect(openstack.send(method)).to eq('fake bosh ip')
        end
      end
    end
  end
end
