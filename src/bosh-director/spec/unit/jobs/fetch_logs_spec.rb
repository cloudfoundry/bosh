require 'spec_helper'
require 'bosh/director/log_bundles_cleaner'

module Bosh::Director
  describe Jobs::FetchLogs do
    subject(:fetch_logs) { Jobs::FetchLogs.new(instances, 'filters' => 'filter1,filter2') }
    let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }
    let(:task) { FactoryBot.create(:models_task, id: 42) }
    let(:task_writer) {Bosh::Director::TaskDBWriter.new(:event_output, task.id)}
    let(:event_log) {Bosh::Director::EventLog::Log.new(task_writer)}

    before {
      allow(Config).to receive(:event_log).and_return(event_log)
      allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore)
      allow(blobstore).to receive(:can_sign_urls?).and_return(false)
    }

    describe 'DJ job class expectations' do
      let(:job_type) { :fetch_logs }
      let(:queue) { :normal }
      it_behaves_like 'a DJ job'
    end

    describe '#perform' do
      let(:instance) do
        Models::Instance.make(deployment: deployment, job: 'fake-job-name', index: '42', uuid: 'uuid-1')
      end

      let(:deployment) { FactoryBot.create(:models_deployment) }

      context 'when only one instance to get logs' do
        let(:instances) { [instance.id] }

        context 'when instance is associated with a vm' do
          before do
            vm = Models::Vm.make(cid: 'vm-1', instance_id: instance.id)
            instance.active_vm = vm
          end

          before { allow(AgentClient).to receive(:with_agent_id).with(instance.agent_id, instance.name).and_return(agent) }
          let(:agent) { instance_double('Bosh::Director::AgentClient', fetch_logs: {'blobstore_id' => 'new-fake-blobstore-id'}) }

          it 'cleans old log bundles' do
            old_log_bundle = Models::LogBundle.make(timestamp: Time.now - 12*24*60*60, blobstore_id: 'previous-fake-blobstore-id') # 12 days
            expect(blobstore).to receive(:delete).with('previous-fake-blobstore-id')

            fetch_logs.perform

            expect(Models::LogBundle.all).not_to include old_log_bundle
          end

          context 'when deleting blob from blobstore fails' do
            it 'cleans the old log bundle if it was not found in the blobstore' do
              old_log_bundle = Models::LogBundle.make(timestamp: Time.now - 12*24*60*60, blobstore_id: 'previous-fake-blobstore-id') # 12 days
              expect(blobstore).to receive(:delete).with('previous-fake-blobstore-id').and_raise(Bosh::Blobstore::NotFound)

              fetch_logs.perform

              expect(Models::LogBundle.all).not_to include old_log_bundle
            end

            it 'does not clean the old log bundle if any other error is returned' do
              old_log_bundle = Models::LogBundle.make(timestamp: Time.now - 12*24*60*60, blobstore_id: 'previous-fake-blobstore-id') # 12 days
              expect(blobstore).to receive(:delete).with('previous-fake-blobstore-id').and_raise(Bosh::Blobstore::NotImplemented)

              fetch_logs.perform

              new_log_bundle = Models::LogBundle.first(blobstore_id: 'new-fake-blobstore-id')
              expect(Models::LogBundle.all).to eq [old_log_bundle, new_log_bundle]
            end
          end

          context 'when agent returns blobstore id in its response to fetch_logs' do
            it 'asks agent to fetch logs and returns blobstore id' do
              expect(agent).to receive(:fetch_logs).
                  with('job', 'filter1,filter2').
                  and_return('blobstore_id' => 'fake-blobstore-id')

              expect(fetch_logs.perform).to eq('fake-blobstore-id')
            end

            it 'registers returned blobstore id as a log bundle' do
              expect(Models::LogBundle.all).to be_empty

              fetch_logs.perform
              expect(Models::LogBundle.where(blobstore_id: 'new-fake-blobstore-id')).not_to be_empty
            end
          end

          context 'when agent does not return blobstore id in its response to fetch_logs' do
            before { allow(agent).to receive(:fetch_logs).and_return({}) }

            it 'raises an exception' do
              expect {
                fetch_logs.perform
              }.to raise_error(AgentTaskNoBlobstoreId, "Agent didn't return a blobstore object id for packaged logs")
            end

            it 'does not register non-existent blobstore id as a log bundle' do
              expect(Models::LogBundle.all).to be_empty
              expect { fetch_logs.perform }
                .to raise_error(Bosh::Director::AgentTaskNoBlobstoreId, /Agent didn't return a blobstore object id for packaged logs/)
              expect(Models::LogBundle.all).to be_empty
            end
          end
        end

        context 'when instance is not associated with a vm' do
          it 'raises an exception because there is no agent to contact' do
            expect {
              fetch_logs.perform
            }.to raise_error(InstanceVmMissing, "'fake-job-name/#{instance.uuid} (42)' doesn't reference a VM")
          end
        end
      end

      context 'when several isntances to get logs' do
        let(:instance_1) do
          is = Models::Instance.make(deployment: deployment, job: 'fake-job-name', index: '44', uuid: 'uuid-2')
          vm = Models::Vm.make(cid: 'vm-1', instance_id: is.id)
          is.active_vm = vm
          is.save
        end
        let(:instance_2) do
          is = Models::Instance.make(deployment: deployment, job: 'fake-job-name', index: '43', uuid: 'uuid-3')
          vm = Models::Vm.make(cid: 'vm-2', instance_id: is.id)
          is.active_vm = vm
          is.save
        end
        let(:instances) do
          [instance_1.id, instance_2.id]
        end

        before do
          allow(AgentClient).to receive(:with_agent_id).with(instance_1.agent_id, instance_1.name).and_return(agent_1)
          allow(AgentClient).to receive(:with_agent_id).with(instance_2.agent_id, instance_2.name).and_return(agent_2)
          allow(blobstore).to receive(:delete)
          allow(blobstore).to receive(:get)
          allow(blobstore).to receive(:create).and_return('common-blobstore-id')
        end

        let(:agent_1) { instance_double('Bosh::Director::AgentClient', fetch_logs: {'blobstore_id' => 'fake-blobstore-id-1'}) }
        let(:agent_2) { instance_double('Bosh::Director::AgentClient', fetch_logs: {'blobstore_id' => 'fake-blobstore-id-2'}) }
        let(:archiver) { Core::TarGzipper.new }

        context 'when temporary blob exists' do
          it 'should be deleted' do
            expect(blobstore).to receive(:delete).with('fake-blobstore-id-1')
            expect(blobstore).to receive(:delete).with('fake-blobstore-id-2')
            fetch_logs.perform
          end

          it 'should be not registered' do
            fetch_logs.perform
            expect(Models::LogBundle.where(blobstore_id: 'fake-blobstore-id-1')).to be_empty
            expect(Models::LogBundle.where(blobstore_id: 'fake-blobstore-id-2')).to be_empty
          end
        end

        it 'raises an exception when agent does not return blobstore id in its response to fetch_logs' do
          allow(agent_2).to receive(:fetch_logs).and_return({})
          expect {
            fetch_logs.perform
          }.to raise_error(AgentTaskNoBlobstoreId, "Agent didn't return a blobstore object id for packaged logs")
        end

        it 'raises an exception because there is no agent to contact' do
          instance_1.active_vm = nil
          expect {
            fetch_logs.perform
          }.to raise_error(InstanceVmMissing, "'fake-job-name/#{instance_1.uuid} (44)' doesn't reference a VM")
        end

        context 'when common logs file is generated' do
          before do
            allow(blobstore).to receive(:get)
            allow(Core::TarGzipper).to receive(:new).and_return(archiver)
            Timecop.freeze(Time.new(2011, 10, 9, 11, 55, 45))
          end
          after { Timecop.return }

          it 'should store all logs together' do
            expect(archiver).to receive(:compress) { |download_dir, sources, output_path|
              expect(Dir.entries(download_dir)).to include('fake-job-name.uuid-2.2011-10-09-11-55-45.tgz', 'fake-job-name.uuid-3.2011-10-09-11-55-45.tgz')
              File.write(output_path, 'Some glorious content')
            }
            fetch_logs.perform
          end

          it 'registers returned blobstore id as a log bundle' do
            expect(Models::LogBundle.all).to be_empty

            fetch_logs.perform
            expect(Models::LogBundle.where(blobstore_id: 'common-blobstore-id')).not_to be_empty
          end
        end
      end
    end
  end
end
