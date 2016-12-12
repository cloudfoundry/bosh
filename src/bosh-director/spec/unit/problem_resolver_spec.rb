require 'spec_helper'

module Bosh::Director
  describe ProblemResolver do
    let(:event_manager) { Bosh::Director::Api::EventManager.new(true)}
    let(:job) {instance_double(Bosh::Director::Jobs::BaseJob, username: 'user', task_id: task.id, event_manager: event_manager)}
    let(:cloud) { Config.cloud }
    let(:task) {Bosh::Director::Models::Task.make(:id => 42, :username => 'user')}
    let(:task_writer) {Bosh::Director::TaskDBWriter.new(:event_output, task.id)}
    let(:event_log) {Bosh::Director::EventLog::Log.new(task_writer)}
    before(:each) do
      @deployment = Models::Deployment.make(name: 'mycloud')
      @other_deployment = Models::Deployment.make(name: 'othercloud')
      allow(Bosh::Director::Config).to receive(:current_job).and_return(job)
      allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
    end

    def make_resolver(deployment)
      ProblemResolver.new(deployment)
    end

    def inactive_disk(id, deployment_id = nil)
      Models::DeploymentProblem.make(deployment_id: deployment_id || @deployment.id,
                                     resource_id: id,
                                     type: 'inactive_disk',
                                     state: 'open')
    end

    describe '#apply_resolutions' do
      context 'when execution succeeds' do
        it 'applies all resolutions' do
          disks = []
          problems = []

          agent = double('agent')
          expect(agent).to receive(:list_disk).and_return([])

          expect(cloud).to receive(:detach_disk).exactly(1).times

          allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).and_return(agent)

          2.times do
            disk = Models::PersistentDisk.make(:active => false)
            disks << disk
            problems << inactive_disk(disk.id)
          end

          resolver = make_resolver(@deployment)

          expect(resolver).to receive(:track_and_log).with(/Disk 'disk-cid-\d+' \(0M\) for instance 'job-\d+\/uuid-\d+ \(\d+\)' is inactive \(.*\): .*/).twice.and_call_original
          expect(resolver.apply_resolutions({ problems[0].id.to_s => 'delete_disk', problems[1].id.to_s => 'ignore' })).to eq([2, nil])

          expect(Models::PersistentDisk.find(id: disks[0].id)).to be_nil
          expect(Models::PersistentDisk.find(id: disks[1].id)).not_to be_nil

          expect(Models::DeploymentProblem.filter(state: 'open').count).to eq(0)
        end

        it 'notices and logs extra resolutions' do
          disks = (1..3).map { |_| Models::PersistentDisk.make(:active => false) }

          problems = [
              inactive_disk(disks[0].id),
              inactive_disk(disks[1].id),
              inactive_disk(disks[2].id, @other_deployment.id)
          ]

          resolver1 = make_resolver(@deployment)
          expect(resolver1.apply_resolutions({ problems[0].id.to_s => 'ignore', problems[1].id.to_s => 'ignore' })).to eq([2, nil])

          resolver2 = make_resolver(@deployment)

          messages = []
          expect(resolver2).to receive(:track_and_log).exactly(3).times { |message| messages << message }
          resolver2.apply_resolutions({
                                          problems[0].id.to_s => 'ignore',
                                          problems[1].id.to_s => 'ignore',
                                          problems[2].id.to_s => 'ignore',
                                          '9999999' => 'ignore',
                                          '318' => 'do_stuff'
                                      })

          expect(messages).to match_array([
                                              "Ignoring problem #{problems[0].id} (state is 'resolved')",
                                              "Ignoring problem #{problems[1].id} (state is 'resolved')",
                                              "Ignoring problem #{problems[2].id} (not a part of this deployment)",
                                          ])
        end
      end

      context 'when execution fails' do
        it 'raises error and logs' do
          backtrace = anything
          disk = Models::PersistentDisk.make(:active => false)
          problem = inactive_disk(disk.id)
          resolver = make_resolver(@deployment)

          expect(resolver).to receive(:track_and_log)
                                  .and_raise(Bosh::Director::ProblemHandlerError.new('Resolution failed'))
          expect(logger).to receive(:error).with("Error resolving problem '1': Resolution failed")
          expect(logger).to receive(:error).with(backtrace)

          count, error_message = resolver.apply_resolutions({ problem.id.to_s => 'ignore' })

          expect(error_message).to eq("Error resolving problem '1': Resolution failed")
          expect(count).to eq(1)
        end
      end

      context 'when execution fails because of other errors' do
        it 'raises error and logs' do
          backtrace = anything
          disk = Models::PersistentDisk.make(:active => false)
          problem = inactive_disk(disk.id)
          resolver = make_resolver(@deployment)

          expect(ProblemHandlers::Base).to receive(:create_from_model)
                                               .and_raise(StandardError.new('Model creation failed'))
          expect(logger).to receive(:error).with("Error resolving problem '1': Model creation failed")
          expect(logger).to receive(:error).with(backtrace)

          count, error_message = resolver.apply_resolutions({ problem.id.to_s => 'ignore' })

          expect(error_message).to eq("Error resolving problem '1': Model creation failed")
          expect(count).to eq(0)
        end
      end
    end
  end
end
