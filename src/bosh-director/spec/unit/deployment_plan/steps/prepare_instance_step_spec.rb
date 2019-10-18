require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe PrepareInstanceStep do
        subject(:step) { PrepareInstanceStep.new(instance_plan, use_active_vm: use_active_vm) }

        let(:instance) { Models::Instance.make }
        let(:deployment_instance) { instance_double(Instance, model: instance) }
        let(:instance_plan) { instance_double(InstancePlan, instance: deployment_instance) }
        let(:apply_spec) do
          {
            'test' => 'apply-me',
            'packages' => { 'pkg' => { 'blobstore_id' => 'blob1' } },
            'rendered_templates_archive' => { 'blobstore_id' => 'blob2' },
          }
        end
        let(:jobless_apply_spec) do
          {
            'test' => 'unemployed',
            'packages' => { 'pkg' => { 'blobstore_id' => 'blob3' } },
            'rendered_templates_archive' => { 'blobstore_id' => 'blob4' },
          }
        end
        let(:signed_apply_spec) do
          {
            'test' => 'apply-me',
            'packages' => { 'pkg' => { 'blobstore_id' => 'blob1', 'signed_url' => 'http://sig1' } },
            'rendered_templates_archive' => { 'blobstore_id' => 'blob2' },
          }
        end
        let(:signed_jobless_apply_spec) do
          {
            'test' => 'unemployed',
            'packages' => { 'pkg' => { 'blobstore_id' => 'blob3', 'signed_url' => 'http://sig3' } },
            'rendered_templates_archive' => { 'blobstore_id' => 'blob4' },
          }
        end
        let(:spec) { instance_double(InstanceSpec, as_apply_spec: apply_spec, as_jobless_apply_spec: jobless_apply_spec) }
        let(:report) { Stages::Report.new }
        let(:blobstore) { instance_double(Bosh::Blobstore::BaseClient) }

        before do
          allow(InstanceSpec).to receive(:create_from_instance_plan).with(instance_plan).and_return spec
          allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
        end

        describe '#perform' do
          context 'with url signing disabled' do
            before do
              allow(blobstore).to receive(:can_sign_urls?).and_return(false)
            end

            context 'with an instance plan referring to an instance with both new and old vms' do
              let(:active_agent) { instance_double(AgentClient) }
              let(:lazy_agent) { instance_double(AgentClient) }

              before do
                active = Models::Vm.make(instance: instance, agent_id: 'active-agent', active: true, stemcell_api_version: 3)
                Models::Vm.make(instance: instance, agent_id: 'lazy-agent', active: false, stemcell_api_version: 3)
                allow(AgentClient).to receive(:with_agent_id).with('active-agent', instance.name).and_return(active_agent)
                allow(AgentClient).to receive(:with_agent_id).with('lazy-agent', instance.name).and_return(lazy_agent)
                allow(instance).to receive(:active_vm).and_return(active)
              end

              context 'when preparing the active vm' do
                let(:use_active_vm) { true }

                it 'sends the full spec to the active vms agent' do
                  expect(active_agent).to receive(:prepare).with(
                    'test' => 'apply-me',
                    'packages' => { 'pkg' => { 'blobstore_id' => 'blob1' } },
                    'rendered_templates_archive' => { 'blobstore_id' => 'blob2' },
                  )

                  step.perform(report)
                end
              end

              context 'when preparing the inactive vm' do
                let(:use_active_vm) { false }

                it 'sends the jobless spec to the other vms agent' do
                  expect(lazy_agent).to receive(:prepare).with(
                    'test' => 'unemployed',
                    'packages' => { 'pkg' => { 'blobstore_id' => 'blob3' } },
                    'rendered_templates_archive' => { 'blobstore_id' => 'blob4' },
                  )

                  step.perform(report)
                end
              end
            end

            context 'with an instance plan with only an old vm' do
              let(:old_agent) { instance_double(AgentClient) }

              before do
                active = Models::Vm.make(instance: instance, agent_id: 'old-agent', active: true, stemcell_api_version: 3)
                allow(AgentClient).to receive(:with_agent_id).with('old-agent', instance.name).and_return(old_agent)
                allow(instance).to receive(:active_vm).and_return(active)
              end

              context 'when preparing the active vm' do
                let(:use_active_vm) { true }

                it 'sends the full spec to the active vms agent' do
                  expect(old_agent).to receive(:prepare).with(
                    'test' => 'apply-me',
                    'packages' => { 'pkg' => { 'blobstore_id' => 'blob1' } },
                    'rendered_templates_archive' => { 'blobstore_id' => 'blob2' },
                  )

                  step.perform(report)
                end
              end

              context 'when preparing the inactive vm' do
                let(:use_active_vm) { false }

                it 'raises error' do
                  expect { step.perform(report) }.to raise_error('no inactive VM available to prepare for instance')
                end
              end
            end

            context 'with an instance plan with only a new vm' do
              let(:new_agent) { instance_double(AgentClient) }

              before do
                Models::Vm.make(instance: instance, agent_id: 'new-agent', active: false, stemcell_api_version: 3)
                allow(AgentClient).to receive(:with_agent_id).with('new-agent', instance.name).and_return(new_agent)
              end

              context 'when preparing the active vm' do
                let(:use_active_vm) { true }

                it 'raises error' do
                  expect { step.perform(report) }.to raise_error('no active VM available to prepare for instance')
                end
              end

              context 'when preparing the inactive vm' do
                let(:use_active_vm) { false }

                it 'sends the jobless spec to the other vms agent' do
                  expect(new_agent).to receive(:prepare).with(
                    'test' => 'unemployed',
                    'packages' => { 'pkg' => { 'blobstore_id' => 'blob3' } },
                    'rendered_templates_archive' => { 'blobstore_id' => 'blob4' },
                  )

                  step.perform(report)
                end
              end
            end
          end

          context 'with url signing enabled' do
            before do
              allow(blobstore).to receive(:can_sign_urls?).and_return(true)
              allow(blobstore).to receive(:sign).with('blob1', 'get').and_return('http://sig1')
              allow(blobstore).to receive(:sign).with('blob2', 'get').and_return('http://sig2')
              allow(blobstore).to receive(:sign).with('blob3', 'get').and_return('http://sig3')
            end

            context 'with an instance plan referring to an instance with both new and old vms' do
              let(:active_agent) { instance_double(AgentClient) }
              let(:lazy_agent) { instance_double(AgentClient) }

              before do
                active = Models::Vm.make(instance: instance, agent_id: 'active-agent', active: true, stemcell_api_version: 3)
                Models::Vm.make(instance: instance, agent_id: 'lazy-agent', active: false, stemcell_api_version: 3)
                allow(AgentClient).to receive(:with_agent_id).with('active-agent', instance.name).and_return(active_agent)
                allow(AgentClient).to receive(:with_agent_id).with('lazy-agent', instance.name).and_return(lazy_agent)
                allow(instance).to receive(:active_vm).and_return(active)
              end

              context 'when preparing the active vm' do
                let(:use_active_vm) { true }

                it 'sends the full spec to the active vms agent' do
                  expect(active_agent).to receive(:prepare).with(signed_apply_spec)

                  step.perform(report)
                end
              end

              context 'when preparing the inactive vm' do
                let(:use_active_vm) { false }

                it 'sends the jobless spec to the other vms agent' do
                  expect(lazy_agent).to receive(:prepare).with(signed_jobless_apply_spec)

                  step.perform(report)
                end
              end
            end

            context 'with an instance plan with only an old vm' do
              let(:old_agent) { instance_double(AgentClient) }

              before do
                active = Models::Vm.make(instance: instance, agent_id: 'old-agent', active: true, stemcell_api_version: 3)
                allow(AgentClient).to receive(:with_agent_id).with('old-agent', instance.name).and_return(old_agent)
                allow(instance).to receive(:active_vm).and_return(active)
              end

              context 'when preparing the active vm' do
                let(:use_active_vm) { true }

                it 'sends the full spec to the active vms agent' do
                  expect(old_agent).to receive(:prepare).with(signed_apply_spec)

                  step.perform(report)
                end
              end

              context 'when preparing the inactive vm' do
                let(:use_active_vm) { false }

                it 'raises error' do
                  expect { step.perform(report) }.to raise_error('no inactive VM available to prepare for instance')
                end
              end
            end

            context 'with an instance plan with only a new vm' do
              let(:new_agent) { instance_double(AgentClient) }

              before do
                Models::Vm.make(instance: instance, agent_id: 'new-agent', active: false, stemcell_api_version: 3)
                allow(AgentClient).to receive(:with_agent_id).with('new-agent', instance.name).and_return(new_agent)
              end

              context 'when preparing the active vm' do
                let(:use_active_vm) { true }

                it 'raises error' do
                  expect { step.perform(report) }.to raise_error('no active VM available to prepare for instance')
                end
              end

              context 'when preparing the inactive vm' do
                let(:use_active_vm) { false }

                it 'sends the jobless spec to the other vms agent' do
                  expect(new_agent).to receive(:prepare).with(signed_jobless_apply_spec)

                  step.perform(report)
                end
              end
            end
          end
        end
      end
    end
  end
end
