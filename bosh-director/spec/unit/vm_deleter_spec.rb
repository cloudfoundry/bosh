require 'spec_helper'

module Bosh
  module Director
    describe VmDeleter do
      subject { VmDeleter.new(cloud, logger) }

      let(:cloud) { instance_double('Bosh::Cloud') }
      let(:event_manager) { Api::EventManager.new(true)}
      let(:vm_type) { DeploymentPlan::VmType.new({'name' => 'fake-vm-type', 'cloud_properties' => {'ram' => '2gb'}}) }
      let(:stemcell_model) { Models::Stemcell.make(:cid => 'stemcell-id', name: 'fake-stemcell', version: '123') }
      let(:stemcell) do
        stemcell_model
        stemcell = DeploymentPlan::Stemcell.parse({'name' => 'fake-stemcell', 'version' => '123'})
        stemcell.add_stemcell_model
        stemcell
      end
      let(:env) { DeploymentPlan::Env.new({}) }
      let(:job) do
        template_model = BD::Models::Template.make
        job = BD::DeploymentPlan::Job.new(nil, 'fake-job-name')
        job.bind_existing_model(template_model)

        instance_group = BD::DeploymentPlan::InstanceGroup.new(logger)
        instance_group.name = 'fake-job'
        instance_group.vm_type = vm_type
        instance_group.stemcell = stemcell
        instance_group.env = env
        instance_group.jobs << job
        instance_group.default_network = {"gateway" => "name"}
        instance_group.update = BD::DeploymentPlan::UpdateConfig.new({'canaries' => 1, 'max_in_flight' => 1, 'canary_watch_time' => '1000-2000', 'update_watch_time' => '1000-2000'})
        allow(instance_group).to receive(:username).and_return('fake-username')
        allow(instance_group).to receive(:task_id).and_return('fake-task-id')
        allow(instance_group).to receive(:event_manager).and_return(event_manager)
        instance_group
      end
      let(:deployment) { Models::Deployment.make(name: 'deployment_name') }
      let(:instance_model) { Models::Instance.make(uuid: SecureRandom.uuid, index: 5, job: 'fake-job', deployment: deployment) }
      let(:instance) do
        instance = DeploymentPlan::Instance.create_from_job(
            job,
            5,
            'started',
            deployment,
            {},
            nil,
            logger
        )
        instance.bind_existing_instance_model(instance_model)
        allow(instance).to receive(:apply_spec).and_return({})
        allow(instance).to receive(:vm_cid).and_return('vm-cid')
        allow(instance).to receive(:deployment).and_return(deployment)
        allow(instance).to receive(:job).and_return(job)
        allow(instance).to receive(:spec).and_return(JSON.parse('{"networks":[["name",{"ip":"1.2.3.4"}]],"job":{"name":"job_name"},"deployment":"bosh"}'))
        allow(instance).to receive(:id).and_return(1)
        instance
      end

      describe '#delete_for_instance' do
        let!(:uuid_local_dns_record) { Models::LocalDnsRecord.create(name: "#{instance.uuid}.job_name.name.bosh.bosh",
                                                                     ip: '1.2.3.4',
                                                                     instance_id: instance.id) }

        let!(:index_local_dns_record) { Models::LocalDnsRecord.create(name: "#{instance.index}.job_name.name.bosh.bosh",
                                                                      ip: '1.2.3.4',
                                                                      instance_id: instance.id) }

        before do
          expect(instance_model).to receive(:update).with(vm_cid: nil, agent_id: nil, trusted_certs_sha1: nil, credentials: nil)
          expect(subject).to receive(:delete_vm).with(instance_model.vm_cid)
          allow(Config).to receive(:local_dns_enabled?).and_return(true)
        end

        it 'deletes the instance and stores an event' do
          expect(Config).to receive(:current_job).and_return(job).exactly(6).times
          expect(Models::LocalDnsRecord.all).to eq([uuid_local_dns_record, index_local_dns_record])

          expect {
            subject.delete_for_instance(instance_model)
          }.to change { Models::Event.count }.from(0).to(2)
        end

        context 'when store_event is false' do
          it 'deletes the instance and does not store an event' do
            expect {
              subject.delete_for_instance(instance_model, false)
            }.not_to change { Models::Event.count }
          end
        end
      end

      describe '#delete_vm' do
        it 'calls delete_vm on the cloud' do
          expect(logger).to receive(:info).with('Deleting VM')
          expect(cloud).to receive(:delete_vm).with('vm-cid')
          subject.delete_vm('vm-cid')
        end

        context 'when virtual delete is enabled' do
          subject { VmDeleter.new(cloud, logger, false, true) }

          it 'skips calling delete_vm on the cloud' do
            expect(logger).to receive(:info).with('Deleting VM')
            expect(cloud).not_to receive(:delete_vm)
            subject.delete_vm('vm-cid')
          end
        end
      end
    end
  end
end
