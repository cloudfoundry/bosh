require 'spec_helper'
require 'logger'

module Bosh::Director
  describe InstanceUpdater::NetworkUpdater do
    subject(:updater) { described_class.new(instance, vm_model, agent_client, vm_updater, cloud, logger) }
    let(:instance) { instance_double('Bosh::Director::DeploymentPlan::Instance', :recreate= => nil) }
    let(:vm_model) { instance_double('Bosh::Director::Models::Vm', cid: 'fake-vm-cid') }
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:vm_updater) { instance_double('Bosh::Director::InstanceUpdater::VmUpdater', update: nil) }
    let(:cloud) { instance_double('Bosh::Cloud') }

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

        it 'returns same vm model and agent client' do
          expect(updater.update).to eq([vm_model, agent_client])
        end
      end

      context 'instance requires network change' do
        before { allow(instance).to receive(:networks_changed?).with(no_args).and_return(true) }

        before { allow(instance).to receive(:network_settings).with(no_args).and_return(network_settings) }
        let(:network_settings) { double('fake-network-settings') }

        k1 = InstanceUpdater::NetworkUpdater::ConfigureNetworksStrategy
        before { allow(k1).to receive(:new).and_return(configure_networks_strategy) }
        let(:configure_networks_strategy) do
          instance_double(k1.to_s, {
            before_configure_networks: nil,
            after_configure_networks: nil,
          })
        end

        k2 = InstanceUpdater::NetworkUpdater::PrepareNetworkChangeStrategy
        before { allow(k2).to receive(:new).and_return(prepare_network_change_strategy) }
        let(:prepare_network_change_strategy) do
          instance_double(k2.to_s, {
            before_configure_networks: nil,
            after_configure_networks: nil,
          })
        end

        context 'when ConfigureNetworksStrategy strategy works' do
          before { allow(configure_networks_strategy).to receive(:before_configure_networks).and_return(true) }

          context 'when cloud supports re-configuring vm with network settings' do
            before { allow(cloud).to receive(:configure_networks).and_return(nil) }

            it 'configures network settings with ConfigureNetworksStrategy strategy' do
              expect(InstanceUpdater::NetworkUpdater::ConfigureNetworksStrategy).to receive(:new).
                 with(agent_client, network_settings, logger).
                 and_return(configure_networks_strategy)

              expect(configure_networks_strategy).to receive(:before_configure_networks).with(no_args).ordered
              expect(cloud).to receive(:configure_networks).with('fake-vm-cid', network_settings).ordered
              expect(configure_networks_strategy).to receive(:after_configure_networks).with(no_args).ordered
              updater.update
            end

            it 'does not try to use PrepareNetworkChangeStrategy strategy at all' do
              expect(prepare_network_change_strategy).to_not receive(:before_configure_networks)
              expect(prepare_network_change_strategy).to_not receive(:after_configure_networks)
              updater.update
            end

            it 'returns same vm model and agent client' do
              expect(updater.update).to eq([vm_model, agent_client])
            end
          end

          context 'when cloud does not support re-configuring vm with network settings' do
            before { allow(cloud).to receive(:configure_networks).and_raise(Bosh::Clouds::NotSupported) }

            it 'does not try to use ConfigureNetworksStrategy strategy after finding out that vm cannot be reconfigured' do
              expect(configure_networks_strategy).to_not receive(:after_configure_networks)
              updater.update
            end

            it 'does not try to use PrepareNetworkChangeStrategy strategy at all' do
              expect(prepare_network_change_strategy).to_not receive(:before_configure_networks)
              expect(prepare_network_change_strategy).to_not receive(:after_configure_networks)
              updater.update
            end

            it 'asks vm updater to recreate instance vm' do
              expect(instance).to receive(:recreate=).with(true).ordered
              expect(vm_updater).to receive(:update).with(nil).ordered
              updater.update
            end

            it 'returns newly recreated vm model and agent client' do
              new_vm_model = instance_double('Bosh::Director::Models::Vm')
              new_agent_client = instance_double('Bosh::Director::AgentClient')
              expect(vm_updater).to receive(:update).with(nil).and_return([new_vm_model, new_agent_client])
              expect(updater.update).to eq([new_vm_model, new_agent_client])
            end
          end
        end

        context 'when ConfigureNetworksStrategy strategy does not work' do
          before { allow(configure_networks_strategy).to receive(:before_configure_networks).and_return(false) }

          context 'when updater picks PrepareNetworkChangeStrategy strategy' do
            before { allow(prepare_network_change_strategy).to receive(:before_configure_networks).and_return(true) }

            context 'when cloud supports re-configuring vm with network settings' do
              before { allow(cloud).to receive(:configure_networks).and_return(nil) }

              it 'configures network settings with PrepareNetworkChangeStrategy strategy' do
                expect(InstanceUpdater::NetworkUpdater::PrepareNetworkChangeStrategy).to receive(:new).
                  with(agent_client, network_settings, logger).
                  and_return(prepare_network_change_strategy)

                expect(prepare_network_change_strategy).to receive(:before_configure_networks).with(no_args).ordered
                expect(cloud).to receive(:configure_networks).with('fake-vm-cid', network_settings).ordered
                expect(prepare_network_change_strategy).to receive(:after_configure_networks).with(no_args).ordered
                updater.update
              end

              it 'does not try to use ConfigureNetworksStrategy after using cpi configure_networks' do
                expect(configure_networks_strategy).to_not receive(:after_configure_networks)
                updater.update
              end

              it 'returns same vm model and agent client' do
                expect(updater.update).to eq([vm_model, agent_client])
              end
            end

            context 'when cloud does not support re-configuring vm with network settings' do
              before { allow(cloud).to receive(:configure_networks).and_raise(Bosh::Clouds::NotSupported) }

              it 'does not try to use ConfigureNetworksStrategy strategy after finding out that vm cannot be reconfigured' do
                expect(configure_networks_strategy).to_not receive(:after_configure_networks)
                updater.update
              end

              it 'does not try to use PrepareNetworkChangeStrategy strategy after finding out that vm cannot be reconfigured' do
                expect(prepare_network_change_strategy).to_not receive(:after_configure_networks)
                updater.update
              end

              it 'asks instance updater to recreate instance vm' do
                expect(instance).to receive(:recreate=).with(true).ordered
                expect(vm_updater).to receive(:update).with(nil).ordered
                updater.update
              end

              it 'returns newly recreated vm model and agent client' do
                new_vm_model = instance_double('Bosh::Director::Models::Vm')
                new_agent_client = instance_double('Bosh::Director::AgentClient')
                expect(vm_updater).to receive(:update).with(nil).and_return([new_vm_model, new_agent_client])
                expect(updater.update).to eq([new_vm_model, new_agent_client])
              end
            end
          end
        end
      end
    end
  end

  describe InstanceUpdater::NetworkUpdater::ConfigureNetworksStrategy do
    subject(:strategy) { described_class.new(agent_client, network_settings, logger) }
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:network_settings) { double('fake-network-settings') }

    describe '#before_configure_networks' do
      context 'when the prepare_configure_networks is not implemented on agent' do
        before { allow(agent_client).to receive(:prepare_configure_networks).and_raise(error) }
        let(:error) { RpcRemoteException.new('unknown message {"method"=>"prepare", "blah"=>"blah"}') }

        it 'returns false' do
          expect(strategy.before_configure_networks).to be(false)
        end
      end

      context 'when the prepare_configure_networks is implemented on agent and it succeeds' do
        before { allow(agent_client).to receive(:prepare_configure_networks).and_return({}) }

        it 'returns false' do
          expect(strategy.before_configure_networks).to be(true)
        end
      end

      context 'when the prepare_configure_networks is implemented on agent and it fails' do
        before { allow(agent_client).to receive(:prepare_configure_networks).and_raise(error) }
        let(:error) { RpcRemoteException.new('fake-agent-error') }

        it 'propagates received error' do
          expect {
            strategy.before_configure_networks
          }.to raise_error(error)
        end
      end
    end

    describe '#after_configure_networks' do
      it 'sends configure_networks message to the agent and waits until agent is ready' do
        expect(agent_client).to receive(:wait_until_ready).with(no_args).ordered
        expect(agent_client).to receive(:configure_networks).with(network_settings).ordered
        strategy.after_configure_networks
      end
    end
  end

  describe InstanceUpdater::NetworkUpdater::PrepareNetworkChangeStrategy do
    subject(:strategy) { described_class.new(agent_client, network_settings, logger) }
    let(:agent_client) { instance_double('Bosh::Director::AgentClient') }
    let(:network_settings) { double('fake-network-settings') }

    describe '#before_configure_networks' do
      it 'returns true' do
        expect(strategy.before_configure_networks).to be(true)
      end
    end

    describe '#after_configure_networks' do
      it 'sends prepare_network_change message to the agent and waits until agent is ready' do
        expect(agent_client).to receive(:wait_until_ready).with(no_args).ordered
        expect(agent_client).to receive(:prepare_network_change).with(network_settings).ordered
        expect(strategy).to receive(:sleep).with(5).ordered
        expect(agent_client).to receive(:wait_until_ready).with(no_args).ordered
        strategy.after_configure_networks
      end
    end
  end
end
