require 'spec_helper'

module Bosh::Director
  describe ProblemResolver do
    let(:event_manager) { Bosh::Director::Api::EventManager.new(true) }
    let(:job) { instance_double(Bosh::Director::Jobs::BaseJob, username: 'user', task_id: task.id, event_manager: event_manager) }
    let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:task) { Bosh::Director::Models::Task.make(id: 42, username: 'user') }
    let(:task_writer) { Bosh::Director::TaskDBWriter.new(:event_output, task.id) }
    let(:event_log) { Bosh::Director::EventLog::Log.new(task_writer) }
    let(:factory) { double }
    let(:deployment_plan) { double }
    let(:parallel_problem_resolution) { true }
    let(:parallel_update_config) { instance_double('Bosh::Director::DeploymentPlan::UpdateConfig', serial?: false) }
    let(:num_problem_instance_groups) { 4 }
    let(:problems_per_instance_group) { 3 }
    let(:igs) do
      igs = []
      (1..num_problem_instance_groups).each do |i|
        igs << instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: "ig-#{i}", update: parallel_update_config)
      end
      igs
    end
    let(:disk_igs) do
      [instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'disk-ig-1', update: parallel_update_config)]
    end

    before(:each) do
      @deployment = Models::Deployment.make(name: 'mycloud')

      allow(DeploymentPlan::PlannerFactory).to receive(:create).and_return(factory)
      allow(factory).to receive(:create_from_model).with(@deployment).and_return(deployment_plan)
      allow(deployment_plan).to receive(:instance_groups).and_return(igs)

      allow(Bosh::Director::Config).to receive(:current_job).and_return(job)
      allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
      allow(Bosh::Director::Config).to receive(:parallel_problem_resolution).and_return(parallel_problem_resolution)

      allow(Bosh::Director::CloudFactory).to receive(:create).and_return(cloud_factory)
      allow(cloud_factory).to receive(:get).with('', nil).and_return(cloud)
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

    def test_instance_apply_resolutions(max_in_flight_overrides={})
      problem_resolutions = {}
      (1..num_problem_instance_groups).each do |n|
        problems_per_instance_group.times do
          instance = Models::Instance.make(job: "ig-#{n}", deployment_id: @deployment.id)
          problem = Models::DeploymentProblem.make(
            deployment_id: @deployment.id,
            resource_id: instance.id,
            type: 'missing_vm',
            state: 'open',
          )
          problem_resolutions[problem.id.to_s] = 'recreate_vm'
        end
      end

      resolver = make_resolver(@deployment)
      allow_any_instance_of(ProblemHandlers::MissingVM).to receive(:apply_resolution).with('recreate_vm')

      expect(resolver.apply_resolutions(problem_resolutions, max_in_flight_overrides)).to eq([problem_resolutions.size, nil])
      expect(Models::DeploymentProblem.filter(state: 'open').count).to eq(0)
    end

    describe '#apply_resolutions' do
      context 'when execution succeeds' do
        let(:max_in_flight) { 5 }

        before do
          allow(parallel_update_config).to receive(:max_in_flight).and_return(max_in_flight)
        end

        context 'when parallel resurrection is turned on' do
          context 'when only one problem exists per instance group' do
            let(:num_problem_instance_groups) { 1 }
            let(:problems_per_instance_group) { 1 }

            it 'does not create a threadpool for processing the problem' do
              test_instance_apply_resolutions
              expect(ThreadPool).not_to have_received(:new)
            end
          end

          context 'when max_in_flight is one' do
            let(:max_in_flight) { 1 }

            it 'only creates one threadpool for instance groups with problems' do
              test_instance_apply_resolutions
              expect(ThreadPool).to have_received(:new).once
              expect(ThreadPool).to have_received(:new).with(max_threads: num_problem_instance_groups)
            end
          end

          context 'when the number instances with problems is smaller than max_in_flight' do
            it 'respects number of instances with problems' do
              test_instance_apply_resolutions
              expect(ThreadPool).to have_received(:new).once.with(max_threads: num_problem_instance_groups)
              expect(ThreadPool).to have_received(:new)
                .exactly(num_problem_instance_groups).times
                .with(max_threads: problems_per_instance_group)
            end
          end

          context 'when max_in_flight is smaller than the number of instances with problems' do
            let(:max_in_flight) { 2 }

            it 'respects max_in_flight' do
              test_instance_apply_resolutions
              expect(ThreadPool).to have_received(:new).once.with(max_threads: num_problem_instance_groups)
              expect(ThreadPool).to have_received(:new)
                .exactly(num_problem_instance_groups).times
                .with(max_threads: max_in_flight)
            end
          end

          context 'when serial is true for some instance groups' do
            let(:serial_update_config) { instance_double('Bosh::Director::DeploymentPlan::UpdateConfig', serial?: true) }
            let(:igs) do
              [
                instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'ig-1', update: serial_update_config),
                instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'ig-2', update: parallel_update_config),
                instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'ig-3', update: parallel_update_config),
                instance_double('Bosh::Director::DeploymentPlan::InstanceGroup', name: 'ig-4', update: serial_update_config),
              ]
            end
            before do
              allow(serial_update_config).to receive(:max_in_flight).and_return(max_in_flight)
            end

            it 'respects serial' do
              test_instance_apply_resolutions
              non_serial_igs_with_problems = 2
              expect(ThreadPool).to have_received(:new).once.with(max_threads: non_serial_igs_with_problems)
              expect(ThreadPool).to have_received(:new).exactly(
                num_problem_instance_groups,
              ).times.with(max_threads: problems_per_instance_group)
            end
          end

          context 'when max_in_flight_overrides are provided' do
            let(:num_problem_instance_groups) { 3 }
            let(:problems_per_instance_group) { 10 }
            let(:max_in_flight_overrides) do
              {
                'ig-2' => '2',
                'ig-3' => '40%',
              }
            end

            it 'overrides max_in_flight for the instance groups overridden' do
              test_instance_apply_resolutions(max_in_flight_overrides)
              expect(ThreadPool).to have_received(:new).once.with(max_threads: num_problem_instance_groups)
              expect(ThreadPool).to have_received(:new).once.with(max_threads: max_in_flight)
              expect(ThreadPool).to have_received(:new).once.with(max_threads: 2)
              expect(ThreadPool).to have_received(:new).once.with(max_threads: 4)
            end
          end
        end

        context 'when parallel resurrection is turned off' do
          let(:parallel_problem_resolution) { false }

          it 'resolves the problems serial' do
            test_instance_apply_resolutions
            expect(ThreadPool).not_to have_received(:new)
          end

          context 'when max_in_flight_overrides are provided' do
            let(:num_problem_instance_groups) { 3 }
            let(:problems_per_instance_group) { 10 }
            let(:max_in_flight_overrides) do
              {
                'ig-2' => '2',
                'ig-3' => '40%',
              }
            end

            it 'does not use them' do
              test_instance_apply_resolutions(max_in_flight_overrides)
              expect(ThreadPool).not_to have_received(:new)
            end
          end
        end

        context 'when instance group contains disk problems' do
          let(:agent) { double('agent') }

          it 'can resolve persistent disk problems' do
            disks = []
            problems = []

            expect(agent).to receive(:list_disk).and_return([])
            expect(cloud).to receive(:detach_disk).exactly(1).times
            allow(AgentClient).to receive(:with_agent_id).and_return(agent)

            allow(deployment_plan).to receive(:instance_groups).and_return(disk_igs)
            allow(Models::Instance).to receive(:make).and_return(
              Models::Instance.make(job: 'disk-ig-1', deployment_id: @deployment.id),
              Models::Instance.make(job: 'disk-ig-1', deployment_id: @deployment.id),
            )

            2.times do
              disk = Models::PersistentDisk.make(active: false)
              disks << disk
              problem = inactive_disk(disk.id)
              problems << problem
            end

            resolver = make_resolver(@deployment)

            expect(resolver).to receive(:track_and_log).with(
              %r{Disk 'disk-cid-\d+' \(0M\) for instance 'disk-ig-\d+\/uuid-\d+ \(\d+\)' is inactive \(.*\): .*},
            ).twice.and_call_original
            expect(
              resolver.apply_resolutions(
                problems[0].id.to_s => 'delete_disk',
                problems[1].id.to_s => 'ignore',
              ),
            ).to eq([2, nil])
            expect(Models::PersistentDisk.find(id: disks[0].id)).to be_nil
            expect(Models::PersistentDisk.find(id: disks[1].id)).not_to be_nil
            expect(Models::DeploymentProblem.filter(state: 'open').count).to eq(0)
          end
        end

        it 'logs already resolved problem' do
          disk = Models::PersistentDisk.make
          problem = Models::DeploymentProblem.make(
            deployment_id: @deployment.id,
            resource_id: disk.id,
            type: 'inactive_disk',
            state: 'resolved',
          )
          resolver = make_resolver(@deployment)
          expect(resolver).to receive(:track_and_log).once.with("Ignoring problem #{problem.id} (state is 'resolved')")
          count, err_message = resolver.apply_resolutions(problem.id.to_s => 'delete_disk')
          expect(count).to eq(0)
          expect(err_message).to be_nil
        end

        it 'ignores non-existing problems' do
          resolver = make_resolver(@deployment)
          expect(
            resolver.apply_resolutions(
              '9999999' => 'ignore',
              '318' => 'do_stuff',
            ),
          ).to eq([0, nil])
        end
      end

      context 'when problem resolution fails' do
        let(:backtrace) { anything }
        let(:disk) { Models::PersistentDisk.make(active: false) }
        let(:problem) { inactive_disk(disk.id) }
        let(:resolver) { make_resolver(@deployment) }

        it 'rescues ProblemHandlerError and logs' do
          expect(resolver).to receive(:track_and_log)
            .and_raise(Bosh::Director::ProblemHandlerError.new('Resolution failed'))
          expect(logger).to receive(:error).with("Error resolving problem '#{problem.id}': Resolution failed")
          expect(logger).to receive(:error).with(backtrace)

          count, error_message = resolver.apply_resolutions(problem.id.to_s => 'ignore')

          expect(error_message).to eq("Error resolving problem '#{problem.id}': Resolution failed")
          expect(count).to eq(1)
        end

        it 'rescues StandardError and logs' do
          expect(ProblemHandlers::Base).to receive(:create_from_model)
            .and_raise(StandardError.new('Model creation failed'))
          expect(logger).to receive(:error).with("Error resolving problem '#{problem.id}': Model creation failed")
          expect(logger).to receive(:error).with(backtrace)

          count, error_message = resolver.apply_resolutions(problem.id.to_s => 'ignore')

          expect(error_message).to eq("Error resolving problem '#{problem.id}': Model creation failed")
          expect(count).to eq(0)
        end
      end
    end
  end
end
