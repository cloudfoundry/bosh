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
      let(:job) do
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
        allow(instance_group).to receive(:username).and_return('fake-username')
        allow(instance_group).to receive(:task_id).and_return('fake-task-id')
        allow(instance_group).to receive(:event_manager).and_return(event_manager)
        instance_group
      end
      let(:deployment) { Models::Deployment.make(name: 'deployment_name') }
      let(:vm_model) { Models::Vm.make(cid: 'vm-cid') }
      let(:instance_model) do
        is = Models::Instance.make(uuid: SecureRandom.uuid, index: 5, job: 'fake-job', deployment: deployment, availability_zone: 'az1')
        is.add_vm vm_model
        is.active_vm = vm_model
        is
      end
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
        allow(instance).to receive(:deployment).and_return(deployment)
        allow(instance).to receive(:job).and_return(job)
        allow(instance).to receive(:spec).and_return(JSON.parse('{"networks":[["name",{"ip":"1.2.3.4"}]],"job":{"name":"job_name"},"deployment":"bosh"}'))
        allow(instance).to receive(:id).and_return(1)
        instance
      end

      before do
        allow(CloudFactory).to receive(:new).and_return(cloud_factory)
        allow(cloud_factory).to receive(:default_from_director_config).and_return(cloud)
      end

      describe '#delete_for_instance' do
        let!(:uuid_local_dns_record) { Models::LocalDnsRecord.create(name: "#{instance.uuid}.job_name.name.bosh.bosh",
                                                                     ip: '1.2.3.4',
                                                                     instance_id: instance.id) }

        let!(:index_local_dns_record) { Models::LocalDnsRecord.create(name: "#{instance.index}.job_name.name.bosh.bosh",
                                                                      ip: '1.2.3.4',
                                                                      instance_id: instance.id) }

        before do
          expect(instance_model).to receive(:active_vm=).with(nil).and_call_original
          expect(subject).to receive(:delete_vm).with(instance_model)
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
        before do
          expect(cloud_factory).to receive(:for_availability_zone).with(instance_model.availability_zone).and_return(cloud)
        end

        it 'calls delete_vm on the cloud' do
          expect(logger).to receive(:info).with('Deleting VM')
          expect(cloud).to receive(:delete_vm).with(vm_model.cid)
          subject.delete_vm(instance_model)
        end

        context 'when vm has already been deleted from the IaaS' do
          it 'should log a warning' do
            expect(logger).to receive(:info).with('Deleting VM')
            expect(logger).to receive(:warn).with("VM '#{vm_model.cid}' might have already been deleted from the cloud")
            expect(cloud).to receive(:delete_vm).with(vm_model.cid).and_raise Bosh::Clouds::VMNotFound

            subject.delete_vm(instance_model)
          end
        end

        context 'when virtual delete is enabled' do
          subject { VmDeleter.new(logger, false, true) }

          it 'skips calling delete_vm on the cloud' do
            expect(logger).to receive(:info).with('Deleting VM')
            expect(cloud).not_to receive(:delete_vm)
            subject.delete_vm(instance_model)
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
