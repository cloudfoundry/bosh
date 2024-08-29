require 'spec_helper'

module Bosh
  module Director
    module DeploymentPlan
      module Steps
        describe DeleteVmStep do
          subject { DeleteVmStep.new(store_event, force, allow_virtual) }
          let(:store_event) { true }
          let(:force) { false }
          let(:allow_virtual) { false }
          let(:instance_model) do
            FactoryBot.create(:models_instance,
              uuid: SecureRandom.uuid,
              index: 5,
              job: 'fake-job',
              deployment: deployment,
              availability_zone: 'az1',
            )
          end
          let(:vm_model) { FactoryBot.create(:models_vm, cid: 'vm-cid', instance_id: instance_model.id, cpi: 'cpi1') }
          let(:deployment) { FactoryBot.create(:models_deployment, name: 'deployment_name') }
          let(:report) { Stages::Report.new.tap { |r| r.vm = vm_model } }

          describe '#perform' do
            let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
            let(:cloud_factory) { instance_double(CloudFactory) }
            let(:job) { instance_double(Bosh::Director::Jobs::BaseJob) }
            let(:instance_group) { FactoryBot.build(:deployment_plan_instance_group) }
            let(:variables_interpolator) { double(Bosh::Director::ConfigServer::VariablesInterpolator) }
            let(:instance) do
              instance = DeploymentPlan::Instance.create_from_instance_group(
                instance_group,
                5,
                'started',
                deployment,
                {},
                nil,
                logger,
                variables_interpolator,
              )
              instance.bind_existing_instance_model(instance_model)
              instance
            end
            let!(:event_manager) { Api::EventManager.new(true) }
            let!(:local_dns_record) { Models::LocalDnsRecord.create(ip: '1.2.3.4', instance_id: instance.model.id) }

            before do
              instance_model.active_vm = vm_model
              allow(CloudFactory).to receive(:create).and_return(cloud_factory)
              allow(cloud_factory).to receive(:get).with('cpi1', nil).and_return(cloud)
              allow(Config).to receive(:local_dns_enabled?).and_return(true)
              allow(Config).to receive(:current_job).and_return(job)
              allow(job).to receive(:event_manager).and_return(event_manager)
              allow(job).to receive(:username).and_return('fake-username')
              allow(job).to receive(:task_id).and_return('fake-task-id')
            end

            it 'deletes the instances vm and stores an event' do
              expect(job).to receive(:event_manager).twice.and_return(event_manager)
              expect(job).to receive(:username).twice.and_return('fake-username')
              expect(job).to receive(:task_id).twice.and_return('fake-task-id')

              expect(logger).to receive(:info).with('Deleting VM')
              expect(Config).to receive(:current_job).and_return(job).exactly(6).times
              expect(Models::LocalDnsRecord.all).to eq([local_dns_record])
              expect(cloud).to receive(:delete_vm).with('vm-cid')

              expect { subject.perform(report) }.to(change { Models::Event.count }.from(0).to(2))
            end

            context 'when the vm has manual network IPs' do
            let!(:ip_address_model) do
              FactoryBot.create(:models_ip_address).tap do |ip|
                ip.vm = vm_model
                ip.instance = instance_model
                ip.save
              end
            end

              it 'disassociates the ip from the vm' do
                expect(vm_model.ip_addresses).to include(ip_address_model)
                expect(cloud).to receive(:delete_vm).with('vm-cid')

                subject.perform(report)

                expect(ip_address_model.reload.vm).to be_nil
              end
            end

            context 'when store_event is false' do
              let(:store_event) { false }
              it 'deletes the instance and does not store an event' do
                expect(cloud).to receive(:delete_vm).with('vm-cid')

                expect { subject.perform(report) }.not_to(change { Models::Event.count })
              end
            end

            context 'when vm has already been deleted from the IaaS' do
              it 'should log a warning' do
                expect(logger).to receive(:info).with('Deleting VM')
                expect(logger).to receive(:warn)
                  .with("VM '#{vm_model.cid}' might have already been deleted from the cloud")
                expect(cloud).to receive(:delete_vm).with(vm_model.cid).and_raise Bosh::Clouds::VMNotFound

                subject.perform(report)
              end
            end

            context 'when virtual delete is enabled' do
              let(:allow_virtual) { true }

              it 'skips calling delete_vm on the cloud' do
                expect(logger).to receive(:info).with('Deleting VM')
                expect(cloud).not_to receive(:delete_vm)
                subject.perform(report)
              end
            end

            context 'when VM has a stemcell API version' do
              let(:vm_model) do
                FactoryBot.create(:models_vm,
                  cid: 'vm-cid',
                  instance_id: instance_model.id,
                  cpi: 'cpi1',
                  stemcell_api_version: 25
                )
              end

              it 'creates requests a cloud instance with that stemcell api version' do
                expect(cloud_factory).to receive(:get).with('cpi1', 25).and_return(cloud)
                expect(job).to receive(:event_manager).twice.and_return(event_manager)
                expect(job).to receive(:username).twice.and_return('fake-username')
                expect(job).to receive(:task_id).twice.and_return('fake-task-id')

                expect(logger).to receive(:info).with('Deleting VM')
                expect(Config).to receive(:current_job).and_return(job).exactly(6).times
                expect(Models::LocalDnsRecord.all).to eq([local_dns_record])
                expect(cloud).to receive(:delete_vm).with('vm-cid')

                expect { subject.perform(report) }.to(change { Models::Event.count }.from(0).to(2))
              end
            end

            context 'when trying to delete VM mutiple times' do
              it 'deletes the instances vm and stores an event' do
                expect(logger).to receive(:info).with('Deleting VM').twice
                expect(Models::LocalDnsRecord.all).to eq([local_dns_record])
                expect(cloud).to receive(:delete_vm).with('vm-cid').twice

                subject.perform(report)
                expect { subject.perform(report) }.to_not raise_error
              end
            end
          end
        end
      end
    end
  end
end
