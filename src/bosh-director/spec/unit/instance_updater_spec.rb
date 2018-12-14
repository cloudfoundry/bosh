require 'spec_helper'

module Bosh::Director
  describe InstanceUpdater do
    let(:updater) { InstanceUpdater.new_instance_updater(ip_provider, template_blob_cache, dns_encoder) }

    let(:blobstore_client) { instance_double(Bosh::Blobstore::Client) }
    let(:deployment_model) { Models::Deployment.make }
    let(:dns_encoder) { instance_double(DnsEncoder) }
    let(:instance_model) { Models::Instance.make }
    let(:ip_provider) { DeploymentPlan::IpProvider.new(ip_repo, [], logger) }
    let(:ip_repo) { DeploymentPlan::InMemoryIpRepo.new(logger) }
    let(:template_blob_cache) { instance_double(Core::Templates::TemplateBlobCache) }
    let(:instance_plan_changed) { false }
    let(:needs_shutting_down) { false }

    let(:instance_plan) do
      instance_double(
        DeploymentPlan::InstancePlan,
        instance: instance,
        needs_shutting_down?: needs_shutting_down,
        changed?: instance_plan_changed,
        changes: [],
      )
    end

    let(:instance) do
      instance_double(
        DeploymentPlan::Instance,
        deployment_model: deployment_model,
        model: instance_model,
      )
    end

    let(:update_procedure) do
      instance_double(
        InstanceUpdater::UpdateProcedure,
        to_proc: -> {},
        action: 'action',
        context: 'context',
      )
    end

    before do
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore_client)
      allow(InstanceUpdater::InstanceState).to receive(:with_instance_update_and_event_creation)
      allow(Config).to receive_message_chain(:current_job, :event_manager).and_return(Api::EventManager.new({}))
      allow(Config).to receive_message_chain(:current_job, :username).and_return('user')
      allow(Config).to receive_message_chain(:current_job, :task_id).and_return('task-1', 'task-2')
    end

    describe '#update' do
      before do
        allow(InstanceUpdater::UpdateProcedure).to receive(:new).and_return(update_procedure)

        updater.update(instance_plan)
      end

      context 'if instance_plan has not changed' do
        it 'calls updates instance state' do
          expect(InstanceUpdater::InstanceState)
            .to have_received(:with_instance_update_and_event_creation)
            .with(
              instance_model,
              nil,
              deployment_model.name,
              'action',
            )

          expect(update_procedure).to have_received(:to_proc)
        end
      end

      context 'if instance_plan has changed' do
        let(:instance_plan_changed) { true }

        it 'does the same, but with parent_id' do
          expect(InstanceUpdater::InstanceState)
            .to have_received(:with_instance_update_and_event_creation)
            .with(
              instance_model,
              1,
              deployment_model.name,
              'action',
            )

        end
      end
    end

    describe '#needs_recreate?' do
      context 'when instance_plan needs_shutting_down?' do
        let(:needs_shutting_down) { true }

        it 'returns true' do
          expect(updater.needs_recreate?(instance_plan)).to eq true
        end
      end

      context 'when instance_plan does not needs_shutting_down?' do
        let(:needs_shutting_down) { false }

        it 'returns false' do
          expect(updater.needs_recreate?(instance_plan)).to eq false
        end
      end
    end
  end
end
