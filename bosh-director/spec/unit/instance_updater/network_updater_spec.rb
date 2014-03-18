require 'spec_helper'
require 'logger'

module Bosh::Director
  describe InstanceUpdater::NetworkUpdater do
    subject(:updater) { described_class.new(instance, vm_model, agent_client, resource_pool_updater, cloud, logger) }
    let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance', :recreate= => nil) }
    let(:vm_model) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-vm-cid') }

    let(:agent_client) do
      instance_double('Bosh::Director::AgentClient', {
        prepare_network_change: nil,
        wait_until_ready: nil,
      })
    end

    let(:resource_pool_updater) do
      instance_double('Bosh::Director::InstanceUpdater', {
        update_resource_pool: nil,
      })
    end

    let(:cloud) { instance_double('Bosh::Cloud') }
    let(:logger) { Logger.new('/dev/null') }

    describe '#update' do
      context 'when instance does not require network changes' do
        before { allow(instance).to receive(:networks_changed?).with(no_args).and_return(false) }

        it 'does not reconfigure vm with same network changes' do
          expect(cloud).to_not receive(:configure_networks)
          updater.update
        end

        it 'does not communicate with agent in any way' do
          expect(agent_client).to_not receive(:prepare_network_change)
          expect(agent_client).to_not receive(:wait_until_ready)
          updater.update
        end
      end

      context 'instance requires network change' do
        before { allow(instance).to receive(:networks_changed?).with(no_args).and_return(true) }

        before { allow(instance).to receive(:network_settings).with(no_args).and_return(network_settings) }
        let(:network_settings) { double('fake-network-settings') }

        before { allow(updater).to receive(:sleep) }

        it 'tries to configure vm with new network settings via the cloud' do
          expect(cloud).to receive(:configure_networks).with('fake-vm-cid', network_settings)
          updater.update
        end

        context 'when cloud supports re-configuring vm with network settings' do
          before { allow(cloud).to receive(:configure_networks).and_return(nil) }

          it 'sends prepare_network_change message to the agent and waits until agent is ready' do
            expect(agent_client).to receive(:prepare_network_change).with(network_settings).ordered

            # Since current implementation of prepare_network_change is to kill the agent
            # we need to spend some time waiting before asking if agent is back and ready
            # to make sure that old agent does not respond with i'm ready message.
            # (Ideally we would not kill the agent)
            expect(updater).to receive(:sleep).with(5).ordered

            expect(agent_client).to receive(:wait_until_ready).with(no_args).ordered

            updater.update
          end
        end

        context 'when cloud does not support re-configuring vm with network settings' do
          before { allow(cloud).to receive(:configure_networks).and_raise(Bosh::Clouds::NotSupported) }

          it 'asks instance updater to recreate instance vm' do
            expect(instance).to receive(:recreate=).with(true).ordered

            expect(resource_pool_updater).to receive(:update_resource_pool).with(no_args).ordered

            updater.update
          end

          it 'does not communicate with agent in any way' do
            expect(agent_client).to_not receive(:prepare_network_change)
            expect(agent_client).to_not receive(:wait_until_ready)
            updater.update
          end
        end
      end
    end
  end
end
