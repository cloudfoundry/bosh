require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe PrepareInstanceStep do
        subject(:step) { PrepareInstanceStep.new(instance_plan, use_active_vm:) }

        let(:instance) { FactoryBot.create(:models_instance) }
        let(:deployment_instance) { instance_double(Instance, model: instance) }
        let(:instance_plan) { instance_double(InstancePlan, instance: deployment_instance) }
        let(:spec) { instance_double(InstanceSpec, as_apply_spec: apply_spec, as_jobless_apply_spec: jobless_apply_spec) }
        let(:report) { Stages::Report.new }
        let(:blobstore) { instance_double(Bosh::Director::Blobstore::BaseClient) }
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
        before do
          allow(InstanceSpec).to receive(:create_from_instance_plan).with(instance_plan).and_return spec
          allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
          allow(blobstore).to receive(:headers).and_return({})
        end

        shared_examples_for 'perform' do
          context 'with an instance plan referring to an instance with both new and old vms' do
            let(:active_agent) { instance_double(AgentClient) }
            let(:lazy_agent) { instance_double(AgentClient) }

            before do
              active = FactoryBot.create(:models_vm, instance:, agent_id: 'active-agent', active: true, stemcell_api_version: 3)
              FactoryBot.create(:models_vm, instance:, agent_id: 'lazy-agent', active: false, stemcell_api_version: 3)
              allow(AgentClient).to receive(:with_agent_id).with('active-agent', instance.name).and_return(active_agent)
              allow(AgentClient).to receive(:with_agent_id).with('lazy-agent', instance.name).and_return(lazy_agent)
              allow(instance).to receive(:active_vm).and_return(active)
            end

            context 'when preparing the active vm' do
              let(:use_active_vm) { true }

              it 'sends the full spec to the active vms agent' do
                expect(active_agent).to receive(:prepare).with(expected_apply_spec)
                step.perform(report)
              end
            end

            context 'when preparing the inactive vm' do
              let(:use_active_vm) { false }

              it 'sends the jobless spec to the other vms agent' do
                expect(lazy_agent).to receive(:prepare).with(expected_jobless_apply_spec)
                step.perform(report)
              end
            end
          end

          context 'with an instance plan with only an old vm' do
            let(:old_agent) { instance_double(AgentClient) }

            before do
              active = FactoryBot.create(:models_vm, instance:, agent_id: 'old-agent', active: true, stemcell_api_version: 3)
              allow(AgentClient).to receive(:with_agent_id).with('old-agent', instance.name).and_return(old_agent)
              allow(instance).to receive(:active_vm).and_return(active)
            end

            context 'when preparing the active vm' do
              let(:use_active_vm) { true }

              it 'sends the full spec to the active vms agent' do
                expect(old_agent).to receive(:prepare).with(expected_apply_spec)
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
              FactoryBot.create(:models_vm, instance:, agent_id: 'new-agent', active: false, stemcell_api_version: 3)
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
                expect(new_agent).to receive(:prepare).with(expected_jobless_apply_spec)
                step.perform(report)
              end
            end
          end
        end

        describe '#perform' do
          context 'with url signing disabled' do
            let(:expected_apply_spec) do
              {
                'test' => 'apply-me',
                'packages' => { 'pkg' => { 'blobstore_id' => 'blob1' } },
                'rendered_templates_archive' => { 'blobstore_id' => 'blob2' },
              }
            end
            let(:expected_jobless_apply_spec) do
              {
                'test' => 'unemployed',
                'packages' => { 'pkg' => { 'blobstore_id' => 'blob3' } },
                'rendered_templates_archive' => { 'blobstore_id' => 'blob4' },
              }
            end
            before do
              allow(blobstore).to receive(:can_sign_urls?).and_return(false)
            end

            it_behaves_like 'perform'
          end

          context 'with url signing enabled' do
            let(:expected_apply_spec) do
              {
                'test' => 'apply-me',
                'packages' => { 'pkg' => { 'blobstore_id' => 'blob1', 'signed_url' => 'http://sig1' } },
                'rendered_templates_archive' => { 'blobstore_id' => 'blob2' },
              }
            end
            let(:expected_jobless_apply_spec) do
              {
                'test' => 'unemployed',
                'packages' => { 'pkg' => { 'blobstore_id' => 'blob3', 'signed_url' => 'http://sig3' } },
                'rendered_templates_archive' => { 'blobstore_id' => 'blob4' },
              }
            end
            before do
              allow(blobstore).to receive(:can_sign_urls?).and_return(true)
              allow(blobstore).to receive(:sign).with('blob1', 'get').and_return('http://sig1')
              allow(blobstore).to receive(:sign).with('blob2', 'get').and_return('http://sig2')
              allow(blobstore).to receive(:sign).with('blob3', 'get').and_return('http://sig3')
            end

            it_behaves_like 'perform'

            context 'when blobstore encryption is enabled' do
              let(:expected_apply_spec) do
                {
                  'test' => 'apply-me',
                  'packages' => { 'pkg' => { 'blobstore_id' => 'blob1', 'signed_url' => 'http://sig1' } },
                  'rendered_templates_archive' => { 'blobstore_id' => 'blob2' },
                }
              end
              let(:expected_jobless_apply_spec) do
                {
                  'test' => 'unemployed',
                  'packages' => { 'pkg' => { 'blobstore_id' => 'blob3', 'signed_url' => 'http://sig3' } },
                  'rendered_templates_archive' => { 'blobstore_id' => 'blob4' },
                }
              end

              before do
                allow(blobstore).to receive(:headers).and_return({})
              end

              it_behaves_like 'perform'
            end
          end
        end
      end
    end
  end
end
