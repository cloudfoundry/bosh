require 'spec_helper'

module Bosh::Director
  describe DeploymentDeleter do
    subject(:deleter) { described_class.new(Config.event_log, logger, dns_manager, 3) }
    before do
      allow(Config).to receive(:cloud).and_return(cloud)
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
    end
    let(:cloud) { instance_double(Bosh::Cloud) }
    let(:blobstore) { instance_double(Bosh::Blobstore::Client) }
    let(:instance_deleter) { instance_double(InstanceDeleter) }
    let(:vm_deleter) { instance_double(VmDeleter) }
    let(:dns_manager) { instance_double(DnsManager) }
    let(:dns_enabled) { false }

    describe '#delete' do
      let!(:instance_1) { Models::Instance.make }
      let!(:instance_2) { Models::Instance.make }

      let!(:deployment_model) { Models::Deployment.make(name: 'fake-deployment') }

      let!(:deployment_stemcell) { Models::Stemcell.make }
      let!(:deployment_release_version) { Models::ReleaseVersion.make }
      before do
        deployment_model.add_instance(instance_1)
        deployment_model.add_instance(instance_2)

        deployment_model.add_stemcell(deployment_stemcell)
        deployment_model.add_release_version(deployment_release_version)
        deployment_model.add_property(Models::DeploymentProperty.make)

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
