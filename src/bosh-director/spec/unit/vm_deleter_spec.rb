require 'spec_helper'

module Bosh
  module Director
    describe VmDeleter do
      subject { VmDeleter.new(logger) }

      let(:cloud) { Config.cloud }
      let(:cloud_factory) { instance_double(CloudFactory) }
      let(:event_manager) { Api::EventManager.new(true)}
      let(:vm_type) { DeploymentPlan::VmType.new({'name' => 'fake-vm-type', 'cloud_properties' => {'ram' => '2gb'}}) }
      let(:stemcell_model) { Models::Stemcell.make(:cid => 'stemcell-id', name: 'fake-stemcell', version: '123') }
      let(:stemcell) do
        stemcell_model
        stemcell = DeploymentPlan::Stemcell.parse({'name' => 'fake-stemcell', 'version' => '123'})
        stemcell.add_stemcell_models
        stemcell
      end
      let(:env) { DeploymentPlan::Env.new({}) }
      let(:instance_group) do
        template_model = BD::Models::Template.make
        job = BD::DeploymentPlan::Job.new(nil, 'fake-job-name', deployment.name)
        job.bind_existing_model(template_model)

        instance_group = BD::DeploymentPlan::InstanceGroup.new(logger)
        instance_group.name = 'fake-job'
        instance_group.vm_type = vm_type
        instance_group.stemcell = stemcell
        instance_group.env = env
        instance_group.jobs << job
        instance_group.default_network = {"gateway" => "name"}
        instance_group.update = BD::DeploymentPlan::UpdateConfig.new({'canaries' => 1, 'max_in_flight' => 1, 'canary_watch_time' => '1000-2000', 'update_watch_time' => '1000-2000'})
        instance_group
      end
      let(:job) { instance_double(BD::Jobs::BaseJob) }
      let(:deployment) { Models::Deployment.make(name: 'deployment_name') }
      let(:vm_model) { Models::Vm.make(cid: 'vm-cid', instance_id: instance_model.id, cpi: 'cpi1') }
      let(:instance_model) { Models::Instance.make(uuid: SecureRandom.uuid, index: 5, job: 'fake-job', deployment: deployment, availability_zone: 'az1') }
      let(:instance) do
        instance = DeploymentPlan::Instance.create_from_instance_group(
            instance_group,
            5,
            'started',
            deployment,
            {},
            nil,
            logger
        )
        instance.bind_existing_instance_model(instance_model)
        instance
      end

      before do
        instance_model.active_vm = vm_model

        allow(CloudFactory).to receive(:create).and_return(cloud_factory)
        allow(cloud_factory).to receive(:get).with(nil).and_return(cloud)
      end

      describe '#delete_for_instance' do
        let!(:local_dns_record) { Models::LocalDnsRecord.create(ip: '1.2.3.4', instance_id: instance.model.id) }

        before do
          expect(instance_model).to receive(:active_vm=).with(nil).and_call_original
          allow(cloud_factory).to receive(:get).with('cpi1').and_return(cloud)
          allow(Config).to receive(:local_dns_enabled?).and_return(true)
        end

        it 'deletes the instance and stores an event' do
          expect(job).to receive(:event_manager).twice.and_return(event_manager)
          expect(job).to receive(:username).twice.and_return('fake-username')
          expect(job).to receive(:task_id).twice.and_return('fake-task-id')

          expect(logger).to receive(:info).with('Deleting VM')
          expect(Config).to receive(:current_job).and_return(job).exactly(6).times
          expect(Models::LocalDnsRecord.all).to eq([local_dns_record])
          expect(cloud).to receive(:delete_vm).with('vm-cid')

          expect {
            subject.delete_for_instance(instance_model)
          }.to change { Models::Event.count }.from(0).to(2)
        end

        context 'when store_event is false' do
          it 'deletes the instance and does not store an event' do
            expect(cloud).to receive(:delete_vm).with('vm-cid')

            expect {
              subject.delete_for_instance(instance_model, false)
            }.not_to change { Models::Event.count }
          end
        end

        context 'when vm has already been deleted from the IaaS' do
          it 'should log a warning' do
            expect(logger).to receive(:info).with('Deleting VM')
            expect(logger).to receive(:warn).with("VM '#{vm_model.cid}' might have already been deleted from the cloud")
            expect(cloud).to receive(:delete_vm).with(vm_model.cid).and_raise Bosh::Clouds::VMNotFound

            subject.delete_for_instance(instance_model, false)
          end
        end

        context 'when virtual delete is enabled' do
          subject { VmDeleter.new(logger, false, true) }

          it 'skips calling delete_vm on the cloud' do
            expect(logger).to receive(:info).with('Deleting VM')
            expect(cloud).not_to receive(:delete_vm)
            subject.delete_for_instance(instance_model, false)
          end
        end
      end

      describe '#delete_vm_by_cid' do
        it 'calls delete_vm if only one cloud is configured' do
          allow(cloud_factory).to receive(:uses_cpi_config?).and_return(false)

          expect(logger).to receive(:info).with('Deleting VM')
          expect(cloud).to receive(:delete_vm).with(vm_model.cid)
          subject.delete_vm_by_cid(vm_model.cid)
        end

        it 'does not call delete_vm if multiple clouds are configured' do
          allow(cloud_factory).to receive(:uses_cpi_config?).and_return(true)

          expect(logger).to receive(:info).with('Deleting VM')
          expect(cloud).to_not receive(:delete_vm).with(vm_model.cid)
          subject.delete_vm_by_cid(vm_model.cid)
        end

        context 'when virtual delete is enabled' do
          subject { VmDeleter.new(logger, false, true) }

          it 'skips calling delete_vm on the cloud' do
            allow(cloud_factory).to receive(:uses_cpi_config?).and_return(false)

            expect(logger).to receive(:info).with('Deleting VM')
            expect(cloud).not_to receive(:delete_vm)
            subject.delete_vm_by_cid(vm_model.cid)
          end
        end
      end
    end
  end
end
