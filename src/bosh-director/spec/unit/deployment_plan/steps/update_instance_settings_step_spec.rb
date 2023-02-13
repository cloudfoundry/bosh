require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe UpdateInstanceSettingsStep do
        subject(:step) { UpdateInstanceSettingsStep.new(instance_plan) }

        let(:instance_model) { Models::Instance.make(cloud_properties: '{}') }
        let(:cloud_props) do
          { 'prop1' => 'value1' }
        end
        let(:agent_client) { instance_double(AgentClient, update_settings: nil) }
        let(:instance) { instance_double(Instance, model: instance_model, cloud_properties: cloud_props, update_instance_settings: nil) }
        let(:trusted_certs) { 'fake-cert' }
        let(:old_trusted_certs_sha1) { 'old-fake-cert' }
        let!(:vm) do
          Models::Vm.make(
            instance: instance_model,
            trusted_certs_sha1: old_trusted_certs_sha1,
            active: false,
            cpi: 'vm-cpi',
          )
        end
        let(:report) { Stages::Report.new.tap { |r| r.vm = vm } }
        let(:instance_plan) { instance_double(InstancePlan, instance: instance) }

        describe '#perform' do
          before do
            allow(AgentClient).to receive(:with_agent_id).and_return(agent_client)
            allow(Config).to receive(:trusted_certs).and_return(trusted_certs)
            allow(vm).to receive(:update)
            allow(instance).to receive(:compilation?).and_return(false)
            Config.enable_short_lived_nats_bootstrap_credentials = true
            Config.enable_short_lived_nats_bootstrap_credentials_compilation_vms = false
          end

          it 'should update the instance settings with the proper VM and force nats rotation' do
            step.perform(report)
            expect(instance).to have_received(:update_instance_settings).with(vm, true)
          end

          it 'should update any cloud_properties provided' do
            expect { step.perform(report) }.to change {
              instance_model.cloud_properties
            }.from('{}').to(JSON.dump(cloud_props))
          end

          it 'should set the permanent_nats_credentials flag to true' do
            step.perform(report)
            expect(vm).to have_received(:update).with(permanent_nats_credentials: true)
          end

          context 'when enable_short_lived_nats_bootstrap_credentials is deactivated' do
            before do
              Config.enable_short_lived_nats_bootstrap_credentials = false
            end

            it 'should update the instance settings with the proper VM and do not force nats rotation' do
              step.perform(report)
              expect(instance).to have_received(:update_instance_settings).with(vm, false)
            end

            it 'should set the permanent_nats_credentials flag to false' do
              step.perform(report)
              expect(vm).to have_received(:update).with(permanent_nats_credentials: false)
            end
          end

          context 'with a compilation vm' do
            before { allow(instance).to receive(:compilation?).and_return(true) }

            it 'should update the instance settings with the proper VM and do not force nats rotation' do
              step.perform(report)
              expect(instance).to have_received(:update_instance_settings).with(vm, false)
            end

            it 'should set the permanent_nats_credentials flag to false' do
              step.perform(report)
              expect(vm).to have_received(:update).with(permanent_nats_credentials: false)
            end

            context 'when enable_short_lived_nats_bootstrap_credentials_compilation_vms is activated' do
              before do
                Config.enable_short_lived_nats_bootstrap_credentials_compilation_vms = true
              end

              it 'should update the instance settings with the proper VM and force nats rotation' do
                step.perform(report)
                expect(instance).to have_received(:update_instance_settings).with(vm, true)
              end

              it 'should set the permanent_nats_credentials flag to true' do
                step.perform(report)
                expect(vm).to have_received(:update).with(permanent_nats_credentials: true)
              end
            end
          end
        end
      end
    end
  end
end
