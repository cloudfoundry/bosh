require 'spec_helper'

module Bosh::Director
  describe DeploymentDeleter do
    subject(:deleter) { described_class.new(event_log, logger, 3) }
    before do
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
    end
    let(:blobstore) { instance_double(Bosh::Blobstore::Client) }
    let(:instance_deleter) { instance_double(InstanceDeleter) }
    let(:vm_deleter) { instance_double(VmDeleter) }
    let(:dns_enabled) { false }
    let(:task) { FactoryBot.create(:models_task, id: 42) }
    let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }

    describe '#delete' do
      let!(:instance_1) { Models::Instance.make }
      let!(:instance_2) { Models::Instance.make }

      let!(:deployment_model) { FactoryBot.create(:models_deployment, name: 'fake-deployment') }

      let!(:deployment_stemcell) { FactoryBot.create(:models_stemcell) }
      let!(:deployment_release_version) { FactoryBot.create(:models_release_version) }
      before do
        deployment_model.add_instance(instance_1)
        deployment_model.add_instance(instance_2)

        deployment_model.add_stemcell(deployment_stemcell)
        deployment_model.add_release_version(deployment_release_version)
        deployment_model.add_property(FactoryBot.create(:models_deployment_property))

        allow(instance_deleter).to receive(:delete_instance_plans)
        allow(deployment_model).to receive(:destroy)
      end

      it 'deletes deployment instances' do
        expect(instance_deleter).to receive(:delete_instance_plans) do |instance_plans, stage, options|
          expect(instance_plans.map(&:existing_instance)).to eq(deployment_model.instances)
          expect(stage).to be_instance_of(EventLog::Stage)
          expect(options).to eq(max_threads: 3)
        end

        deleter.delete(deployment_model, instance_deleter, vm_deleter)
      end

      it 'removes all stemcells' do
        expect(deployment_stemcell.deployments).to include(deployment_model)
        deleter.delete(deployment_model, instance_deleter, vm_deleter)
        expect(deployment_stemcell.reload.deployments).to be_empty
      end

      it 'removes all releases' do
        expect(deployment_release_version.deployments).to include(deployment_model)
        deleter.delete(deployment_model, instance_deleter, vm_deleter)
        expect(deployment_release_version.reload.deployments).to be_empty
      end

      it 'deletes all properties' do
        deleter.delete(deployment_model, instance_deleter, vm_deleter)
        expect(Models::DeploymentProperty.all.size).to eq(0)
      end

      it 'destroys deployment model' do
        expect(deployment_model).to receive(:destroy)
        deleter.delete(deployment_model, instance_deleter, vm_deleter)
      end
    end
  end
end
