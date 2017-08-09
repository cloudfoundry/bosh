require 'spec_helper'

module Bosh::Director
  describe Errand::Runner do
    subject { described_class.new('fake-job-name', errand_is_job_name, task_result, instance_manager, logs_fetcher) }
    let(:errand_is_job_name) { true }
    let(:instance_manager) { Bosh::Director::Api::InstanceManager.new }
    let(:logs_fetcher) { instance_double('Bosh::Director::LogsFetcher') }
    let(:event_log) {Bosh::Director::EventLog::Log.new(task_writer)}
    let(:task) {Bosh::Director::Models::Task.make(:id => 42, :username => 'user')}
    let(:task_writer) {Bosh::Director::TaskDBWriter.new(:event_output, task.id)}
    let(:task_result) { Bosh::Director::TaskDBWriter.new(:result_output, task.id) }

    before  do
      allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
      allow(Bosh::Director::Config).to receive(:result).and_return(task_result)
      current_job = instance_double(Jobs::BaseJob,
        username: 'some-name',
        event_manager: Api::EventManager.new(true),
        task_id: 'some-id'
      )
      allow(Config).to receive(:current_job).and_return(current_job)
    end

    context 'when there is at least 1 instance' do
      let(:instance) do
        instance_double('Bosh::Director::DeploymentPlan::Instance',
          uuid: 'fake-id',
          index: 0,
          configuration_hash: 'configuration_hash',
          current_packages: {'current' => 'packages'},
          job_name: 'fake-job-name',
          to_s: 'fake-job-name/fake-id (0)'
        )
      end

      before { allow(instance).to receive(:model).with(no_args).and_return(instance_model) }
      let(:instance_model) do
        is = Models::Instance.make(
          job: 'fake-job-name',
          index: 0,
          deployment: deployment,
        )
        vm_model = Models::Vm.make(agent_id: 'agent-id', instance_id: is.id)
        is.add_vm vm_model
        is.active_vm = vm_model
        is.spec = { 'job' => { 'template' => template_name} }
        is
      end
      let(:template_name) { 'fake-job-name' }

      let(:deployment) { Models::Deployment.make(name: 'fake-dep-name') }

      before { allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).with(instance_model.credentials, instance_model.agent_id).and_return(agent_client) }
      let(:agent_client) { instance_double('Bosh::Director::AgentClient') }

      describe '#run' do
        let(:event_log_stage) { instance_double('Bosh::Director::EventLog::Stage') }
        before { allow(Config.event_log).to receive(:begin_stage).and_return(event_log_stage) }

        before { allow(event_log_stage).to receive(:advance_and_track).and_yield }

        context 'when agent is able to run errands' do
          let(:exit_code) { 0 }
          let(:agent_task_result) do
            {
              'exit_code' => exit_code,
              'stdout' => 'fake-stdout',
              'stderr' => 'fake-stderr',
            }
          end

          before do
            allow(agent_client).to receive(:run_errand).
              and_return('agent_task_id' => 'fake-agent-task-id')

            allow(logs_fetcher).to receive(:fetch).
              and_return(['fake-logs-blobstore-id', 'fake-logs-blob-sha1'])

            allow(agent_client).to receive(:wait_for_task).and_return(agent_task_result)

            allow(agent_client).to receive(:info).
              and_return({'api_version' => 1})
          end

          context 'the errand is not the first job on an old stemcell' do
            let(:template_name) { 'first-job' }
            let(:errand_is_job_name) { true }
            let(:fake_block) { Proc.new {} }

            before do
              allow(agent_client).to receive(:info).
                and_return({'api_version' => 0})
            end

            context 'user pass in instance group name' do
              let(:errand_is_job_name) { false }

              it 'should not error' do
                subject.run(instance, &fake_block)
              end
            end

            it 'returns an error' do
              expect{ subject.run(instance, &fake_block) }.to raise_error(DirectorError, 'Multiple jobs are configured on an older stemcell, and "fake-job-name" is not the first job')
            end
          end

          it 'runs a block argument to run function while polling for errand to finish' do
            checkpoint_executed = false

            fake_block = lambda { checkpoint_executed = true }

            expect(agent_client).to receive(:info)

            expect(agent_client).to receive(:run_errand).with('fake-job-name')

            expect(agent_client).to receive(:wait_for_task) do |args, &blk|
              expect(args).to eq('fake-agent-task-id')
              blk.call
              agent_task_result
            end

            subject.run(instance, &fake_block)

            expect(checkpoint_executed).to be_truthy
          end

          it 'writes run_errand response with exit_code, stdout, stderr and logs result to task result file' do
            expect(task_result).to receive(:write) do |text|
              expect(JSON.parse(text)).to eq(
                'errand_name' => 'fake-job-name',
                'exit_code' => 0,
                'stdout' => 'fake-stdout',
                'stderr' => 'fake-stderr',
                'logs' => {
                  'blobstore_id' => 'fake-logs-blobstore-id',
                  'sha1' => 'fake-logs-blob-sha1',
                },
              )
            end
            subject.run(instance)
          end

          it 'records errand running in the event log' do
            event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
            expect(Config.event_log).to receive(:begin_stage).with('Running errand', 1).and_return(event_log_stage)
            expect(event_log_stage).to receive(:advance_and_track).with('fake-job-name/fake-id (0)').and_yield
            subject.run(instance)
          end

          # it 'creates a new errand run in the database if none exists' do
          #   expect { subject.run(instance) }.to change { Models::ErrandRun.count }.by(1)
          #   expect(Models::ErrandRun.first.successful).to be_truthy
          # end

          it 'creates events' do
            expect do
              subject.run instance
            end.to change { Models::Event.count }.from(0).to(2)
            parent_event = Models::Event.first
            expect(parent_event.parent_id).to eq(nil)
            expect(parent_event.user).to eq('some-name')
            expect(parent_event.action).to eq('run')
            expect(parent_event.object_type).to eq('errand')
            expect(parent_event.object_name).to eq('fake-job-name')
            expect(parent_event.task).to eq('some-id')
            expect(parent_event.deployment).to eq('fake-dep-name')
            expect(parent_event.instance).to eq('fake-job-name/fake-id (0)')
            expect(parent_event.error).to eq(nil)
            expect(parent_event.context).to eq({})

            result_event = Models::Event.last
            expect(result_event.parent_id).to eq(parent_event.id)
            expect(result_event.user).to eq('some-name')
            expect(result_event.action).to eq('run')
            expect(result_event.object_type).to eq('errand')
            expect(result_event.object_name).to eq('fake-job-name')
            expect(result_event.task).to eq('some-id')
            expect(result_event.deployment).to eq('fake-dep-name')
            expect(result_event.instance).to eq('fake-job-name/fake-id (0)')
            expect(result_event.error).to eq(nil)
            expect(result_event.context).to eq({'exit_code' => 0})
          end

          it 'will always record a terminal event even if there is an error' do
            expect(instance_manager).to receive(:agent_client_for).and_raise 'disaster'

            expect do
              expect { subject.run instance }.to raise_error 'disaster'
            end.to change { Models::Event.count }.from(0).to(2)
            parent_event = Models::Event.first
            expect(parent_event.parent_id).to eq(nil)
            expect(parent_event.user).to eq('some-name')
            expect(parent_event.action).to eq('run')
            expect(parent_event.object_type).to eq('errand')
            expect(parent_event.object_name).to eq('fake-job-name')
            expect(parent_event.task).to eq('some-id')
            expect(parent_event.deployment).to eq('fake-dep-name')
            expect(parent_event.instance).to eq('fake-job-name/fake-id (0)')
            expect(parent_event.error).to eq(nil)
            expect(parent_event.context).to eq({})

            result_event = Models::Event.last
            expect(result_event.parent_id).to eq(parent_event.id)
            expect(result_event.user).to eq('some-name')
            expect(result_event.action).to eq('run')
            expect(result_event.object_type).to eq('errand')
            expect(result_event.object_name).to eq('fake-job-name')
            expect(result_event.task).to eq('some-id')
            expect(result_event.deployment).to eq('fake-dep-name')
            expect(result_event.instance).to eq('fake-job-name/fake-id (0)')
            expect(result_event.error).to eq('disaster')
            expect(result_event.context).to eq({})
          end

          context 'when the errand has run previously' do
            let(:was_successful) { false }

            before do
              # Models::ErrandRun.make(successful: was_successful,
              #   instance_id: instance_model.id,
              #   successful_configuration_hash: 'last_successful_run_configuration',
              #   successful_packages_spec: '{"packages" => "last_successful_run_packages"}'
              # )
              # allow(instance).to receive(:current_packages).and_return({'successful' => 'package_spec'})
              # allow(instance).to receive(:configuration_hash).and_return('successful_hash')
            end

            # it 'updates the errand run model to reflect successful run' do
            #   expect { subject.run(instance) }.to change {
            #     Models::ErrandRun.where({successful: true,
            #       successful_configuration_hash: 'successful_hash',
            #       successful_packages_spec: '{"successful":"package_spec"}'}).count
            #   }.by 1
            # end

            # context 'when the errand does not succeed' do
            #   let(:exit_code) { 42 }
            #
            #   it 'updates the errand run model to reflect unsuccessful run' do
            #     subject.run(instance)
            #
            #     errand_run = Models::ErrandRun.first
            #     expect(errand_run.successful).to be_falsey
            #     expect(errand_run.successful_configuration_hash).to eq('')
            #     expect(errand_run.successful_packages_spec).to eq('')
            #   end
            # end

            # context 'when an unrescued error occurs' do
            #   let(:was_successful) { true }
            #
            #   before do
            #     allow(agent_client).to receive(:wait_for_task).and_raise
            #   end
            #
            #   it 'updates the errand run to be unsuccessful and then raises the error' do
            #     expect{
            #       subject.run(instance)
            #     }.to raise_error(Exception)
            #     errand_run = Models::ErrandRun.first
            #
            #     expect(errand_run.successful).to be_falsey
            #     expect(errand_run.successful_configuration_hash).to eq ''
            #     expect(errand_run.successful_packages_spec).to eq ''
            #   end
            # end
          end

          it 'returns an errand result' do
            expect(subject.run(instance)).to be_a(Bosh::Director::Errand::Result)
          end

          it 'fetches the logs from agent with correct job type and filters' do
            expect(logs_fetcher).to receive(:fetch).with(instance.model, 'job', nil, true)
            subject.run(instance)
          end

          it 'writes run_errand response with nil fetched lobs blobstore id if fetching logs fails' do
            expect(task_result).to receive(:write) do |text|
              expect(JSON.parse(text)).to eq(
                'errand_name' => 'fake-job-name',
                'exit_code' => 0,
                'stdout' => 'fake-stdout',
                'stderr' => 'fake-stderr',
                'logs' => {
                  'blobstore_id' => nil,
                  'sha1' => nil,
                },
              )
            end

            error = DirectorError.new
            expect(logs_fetcher).to receive(:fetch).and_raise(error)

            expect { subject.run(instance) }.to raise_error(error)
          end

          context 'when the errand name matches the instance group name' do
            let(:errand_is_job_name) { false }
            it 'runs the errand without errand name' do
              checkpoint_executed = false

              fake_block = lambda { checkpoint_executed = true }

              expect(agent_client).to receive(:run_errand).with(no_args)

              expect(agent_client).to receive(:wait_for_task) do |args, &blk|
                expect(args).to eq('fake-agent-task-id')
                blk.call
                agent_task_result
              end

              subject.run(instance, &fake_block)

              expect(checkpoint_executed).to be_truthy
            end
          end

          context 'when errand is canceled' do
            before do
              expect(agent_client).to receive(:cancel_task).with('fake-agent-task-id')
              allow(agent_client).to receive(:wait_for_task) do |args, &blk|
                blk.call if blk

                # Agent returns result after cancelling errand
                agent_task_result
              end
            end

            it 're-raises task cancelled exception is task is considered to be cancelled' do
              expect { subject.run(instance) { raise TaskCancelled } }.to raise_error(TaskCancelled)
            end

            it 'writes the errand result received from the agent\'s cancellation' do
              expect(task_result).to receive(:write) do |text|
                expect(JSON.parse(text)).to eq(
                  'exit_code' => 0,
                  'stdout' => 'fake-stdout',
                  'stderr' => 'fake-stderr',
                  'logs' => {
                    'blobstore_id' => 'fake-logs-blobstore-id',
                    'sha1' => 'fake-logs-blob-sha1',
                  },
                )
              end
              expect { subject.run(instance) { raise TaskCancelled } }.to raise_error
            end

            it 'raises cancel error even if fetching logs fails' do
              expect(logs_fetcher).to receive(:fetch).and_raise(DirectorError)
              expect { subject.run(instance) { raise TaskCancelled } }.to raise_error(TaskCancelled)
            end

            it 'writes run_errand response with nil blobstore_id if fetching logs fails' do
              expect(task_result).to receive(:write) do |text|
                expect(JSON.parse(text)).to eq(
                  'exit_code' => 0,
                  'stdout' => 'fake-stdout',
                  'stderr' => 'fake-stderr',
                  'logs' => {
                    'blobstore_id' => nil,
                  },
                )
              end

              expect(logs_fetcher).to receive(:fetch).and_raise(DirectorError)
              expect { subject.run(instance) { raise TaskCancelled } }.to raise_error
            end
          end
        end

        context 'when agent does not support run_errand command' do
          before do
            allow(agent_client).to receive(:run_errand).with('fake-job-name').and_raise(error)
            allow(agent_client).to receive(:info).and_return({ 'api_version' => 0 })
          end
          let(:error) { RpcRemoteException.new('unknown message {"method"=>"run_errand", "error"=>"details"}') }

          it 'raises an error' do
            expect { subject.run(instance) }.to raise_error(error)
          end

          it 'does write run_errand agent response to result file because we did not run errand' do
            expect(task_result).to_not receive(:write)
            expect { subject.run(instance) }.to raise_error
          end

          it 'does not try to fetch logs from the agent because we did not run errand' do
            expect(logs_fetcher).to_not receive(:fetch)
            expect { subject.run(instance) }.to raise_error
          end
        end

        context 'when agent times out responding to start errand task status check' do
          before do
            allow(agent_client).to receive(:run_errand).with('fake-job-name').and_raise(error)
            allow(agent_client).to receive(:info).and_return({ 'api_version' => 0 })
          end
          let(:error) { RpcRemoteException.new('timeout') }

          it 'raises original timeout error' do
            expect { subject.run(instance) }.to raise_error(error)
          end

          it 'does write run_errand agent response to result file because there is was no response' do
            expect(task_result).to_not receive(:write)
            expect { subject.run(instance) }.to raise_error
          end

          it 'does not try to fetch logs from the agent because we failed contacting it already' do
            expect(logs_fetcher).to_not receive(:fetch)
            expect { subject.run(instance) }.to raise_error
          end
        end

        context 'when job instance is not associated with any VM yet' do
          before { instance_model.active_vm = nil }

          it 'raises an error' do
            expect { subject.run(instance) }.to raise_error(InstanceVmMissing, "'fake-job-name/#{instance_model.uuid} (#{instance_model.index})' doesn't reference a VM")
          end
        end
      end
    end
  end
end
