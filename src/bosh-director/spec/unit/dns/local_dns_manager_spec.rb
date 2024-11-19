require 'spec_helper'

module Bosh::Director
  describe LocalDnsManager do
    subject(:local_dns_manager) do
      LocalDnsManager.new(Config.root_domain, local_dns_records_repo, blobstore_dns_publisher, per_spec_logger)
    end

    let(:instance_model) { FactoryBot.create(:models_instance) }
    let(:instance_plan) { instance_double(DeploymentPlan::InstancePlan, instance: deployment_instance) }
    let(:deployment_instance) { instance_double(DeploymentPlan::Instance, model: instance_model) }
    let(:local_dns_records_repo) { instance_double(LocalDnsRecordsRepo) }
    let(:blobstore_dns_publisher) { instance_double(BlobstoreDnsPublisher) }

    describe '.create' do
      it 'should create a dns repo and blobstore_dns_publisher and make a new dns manager' do
        expect(LocalDnsRecordsRepo).to receive(:new).with(per_spec_logger, Config.root_domain)
        expect(BlobstoreDnsPublisher).to receive(:new).with(anything, Config.root_domain, anything, per_spec_logger)

        expect(LocalDnsManager.create(Config.root_domain, per_spec_logger)).to be_a(LocalDnsManager)
      end
    end

    describe '#update_dns_for_instance' do
      it 'should delegate to local_dns_records_repo and publish' do
        expect(local_dns_records_repo).to receive(:update_for_instance).with(instance_plan)
        expect(blobstore_dns_publisher).to receive(:publish_and_send_to_instance).with(instance_model)

        local_dns_manager.update_dns_record_for_instance(instance_plan)
      end
    end

    describe '#delete_dns_record_for_instance' do
      it 'should delegate to local_dns_records_repo and publish' do
        expect(local_dns_records_repo).to receive(:delete_for_instance).with(instance_model)
        expect(blobstore_dns_publisher).to receive(:publish_and_broadcast)

        local_dns_manager.delete_dns_for_instance(instance_model)
      end
    end
  end
end
