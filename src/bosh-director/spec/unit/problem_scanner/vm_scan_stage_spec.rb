require 'spec_helper'

module Bosh::Director
  describe ProblemScanner::VmScanStage do
    subject(:vm_scanner) do
      described_class.new(
        instance_manager,
        problem_register,
        deployment,
        event_logger,
        double(:logger, info: nil, warn: nil)
      )
    end

    def create_vm(i, options = {})
      options = {state: 'started', lifecycle: 'service', ignore: false}.merge(options)
      job_name = "job-#{i}"
      instance = FactoryBot.create(:models_instance, deployment: deployment, job: job_name, index: i, state: options[:state], ignore: options[:ignore], spec_json: JSON.dump({lifecycle: options[:lifecycle]}))
      unless options[:no_vm]
        vm = Models::Vm.make(cid: "vm-cid-#{i}", agent_id: "agent-#{i}", instance_id: instance.id)
        instance.refresh
        instance.active_vm = vm
      end
      instance.save
    end

    let(:instance_manager) { instance_double(Api::InstanceManager) }
    let(:problem_register) { ProblemScanner::ProblemRegister.new(deployment, logger) }
    before do
      allow(problem_register).to receive(:get_disk).and_call_original
    end
    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:cloud_factory) { instance_double(Bosh::Director::AZCloudFactory) }
    let(:deployment) { FactoryBot.create(:models_deployment, name: 'fake-deployment') }
    let(:event_logger) { double(:event_logger, begin_stage: nil) }
    before do
      allow(event_logger).to receive(:track_and_log) do |_, &blk|
        blk.call if blk
      end
      allow(Bosh::Director::AZCloudFactory).to receive(:create_from_deployment).and_return(cloud_factory)
    end

    describe '#scan' do
      it 'scans a subset of vms' do
        instances = (1..3).collect do |i|
          create_vm(i)
        end

        allow(instance_manager).to receive(:find_by_name).with(deployment, 'job-1', 1).and_return(instances[0])
        allow(instance_manager).to receive(:find_by_name).with(deployment, 'job-2', 2).and_return(instances[1])
        allow(instance_manager).to receive(:find_by_name).with(deployment, 'job-3', 3).and_return(instances[2])

        expect(event_logger).to receive(:track_and_log).with('Checking VM states')
        expect(event_logger).to receive(:track_and_log).with('1 OK, 1 unresponsive, 0 missing, 0 unbound')

        good_agent_client = instance_double(AgentClient, list_disk: [])
        allow(AgentClient).to receive(:with_agent_id).with(
          instances[1].agent_id,
          instances[1].name,
          anything,
        ).and_return(good_agent_client)
        good_state = {
          'deployment' => 'fake-deployment',
          'job' => {'name' => 'job-2'},
          'index' => 2
        }
        expect(good_agent_client).to receive(:get_state).and_return(good_state)

        unresponsive_agent_client = instance_double(AgentClient)
        allow(AgentClient).to receive(:with_agent_id).with(
          instances[0].agent_id,
          instances[0].name,
          anything,
        ).and_return(unresponsive_agent_client)
        expect(unresponsive_agent_client).to receive(:get_state).and_raise(Bosh::Director::RpcTimeout)
        allow(cloud).to receive(:has_vm).and_raise(Bosh::Clouds::NotImplemented)
        expect(cloud_factory).to receive(:get_for_az).with(instances[0].availability_zone).and_return(cloud)

        expect(problem_register).to receive(:problem_found).with(
          :unresponsive_agent,
          instances[0]
        )

        expect(AgentClient).to_not receive(:with_agent_id).with(instances[2].agent_id, instances[2].name, anything)

        vm_scanner.scan([['job-1', 1], ['job-2', 2]])
      end

      context 'when service instance is detached' do
        let!(:detached_instance) { create_vm(0, state: 'detached', no_vm: true) }

        before(:each) do
          unresponsive_agent = double(AgentClient)
          agent_options = { timeout: 10, retry_methods: { get_state: 0}}
          allow(AgentClient).to receive(:with_agent_id).with(
            detached_instance.agent_id,
            detached_instance.name,
            agent_options,
          ).and_return(unresponsive_agent)
          allow(unresponsive_agent).to receive(:get_state).and_raise(RpcTimeout)
        end

        context 'when no vms are specified (cck cli command does not send missing vm info)' do
          it 'does not report any problem' do
            expect(event_logger).to receive(:track_and_log).with('Checking VM states')
            expect(event_logger).to receive(:track_and_log).with('0 OK, 0 unresponsive, 0 missing, 0 unbound')

            expect(problem_register).to_not receive(:problem_found)

            vm_scanner.scan
          end
        end

        context 'when a specific set of vms specified (HM sends info about which vms are missing)' do
          it 'does not report any problem' do
            allow(instance_manager).to receive(:find_by_name).with(deployment, 'job-1', 0).and_return(detached_instance)

            expect(event_logger).to receive(:track_and_log).with('Checking VM states')
            expect(event_logger).to receive(:track_and_log).with('0 OK, 0 unresponsive, 0 missing, 0 unbound')

            expect(problem_register).to_not receive(:problem_found)

            vm_scanner.scan([['job-1', 0]])
          end
        end
      end

      context "when instance lifecycle is 'errand'" do
        let!(:errand_vm) { create_vm(0, lifecycle: 'errand', no_vm: true) }

        before(:each) do
          unresponsive_agent = double(AgentClient)
          agent_options = { timeout: 10, retry_methods: { get_state: 0 } }
          allow(AgentClient).to receive(:with_agent_id).with(
            errand_vm.agent_id,
            errand_vm.name,
            agent_options,
          ).and_return(unresponsive_agent)
          allow(unresponsive_agent).to receive(:get_state).and_raise(RpcTimeout)
        end

        it 'does not report any problem' do
          expect(event_logger).to receive(:track_and_log).with('Checking VM states')
          expect(event_logger).to receive(:track_and_log).with('0 OK, 0 unresponsive, 0 missing, 0 unbound')

          expect(problem_register).to_not receive(:problem_found)

          vm_scanner.scan
        end
      end

      context 'when agent on a VM did not respond in time' do
        let!(:unresponsive_vm1) { create_vm(0) }
        let!(:unresponsive_vm2) { create_vm(1) }
        let!(:responsive_vm) { create_vm(2) }

        before do
          unresponsive_agent1 = double(AgentClient)
          unresponsive_agent2 = double(AgentClient)
          responsive_agent = double(AgentClient)
          agent_options = { timeout: 10, retry_methods: { get_state: 0}}

          allow(AgentClient).to receive(:with_agent_id).with(
            unresponsive_vm1.agent_id,
            unresponsive_vm1.name,
            agent_options,
          ).and_return(unresponsive_agent1)
          allow(AgentClient).to receive(:with_agent_id).with(
            unresponsive_vm2.agent_id,
            unresponsive_vm2.name,
            agent_options,
          ).and_return(unresponsive_agent2)
          allow(AgentClient).to receive(:with_agent_id).with(
            responsive_vm.agent_id,
            responsive_vm.name,
            agent_options,
          ).and_return(responsive_agent)

          # Unresponsive agent
          allow(unresponsive_agent1).to receive(:get_state).and_raise(RpcTimeout)
          allow(unresponsive_agent2).to receive(:get_state).and_raise(RpcTimeout)

          # Working agent
          good_state = {
            'deployment' => 'fake-deployment',
            'job' => {'name' => 'job-2'},
            'index' => 2
          }
          allow(responsive_agent).to receive(:get_state).and_return(good_state)
          allow(responsive_agent).to receive(:list_disk).and_return([])
        end

        context 'when instance has no VM assigned' do
          let!(:instance_without_vm) {create_vm(4, no_vm: true)}

          before(:each) {
            unresponsive_agent = double(AgentClient)
            agent_options = { timeout: 10, retry_methods: { get_state: 0}}
            allow(AgentClient).to receive(:with_agent_id).with(
              instance_without_vm.agent_id,
              instance_without_vm.name,
              agent_options,
            ).and_return(unresponsive_agent)
            allow(unresponsive_agent).to receive(:get_state).and_raise(RpcTimeout)
            allow(cloud).to receive(:has_vm).with('vm-cid-0').and_return(true)
            allow(cloud).to receive(:has_vm).with('vm-cid-1').and_return(true)
          }

          it 'registers missing VM problem' do
            expect(event_logger).to receive(:track_and_log).with('Checking VM states')
            expect(event_logger).to receive(:track_and_log).with('1 OK, 2 unresponsive, 1 missing, 0 unbound')

            expect(problem_register).to receive(:problem_found).with(
                :unresponsive_agent,
                unresponsive_vm1
            )

            expect(problem_register).to receive(:problem_found).with(
                :unresponsive_agent,
                unresponsive_vm2
            )

            expect(problem_register).to receive(:problem_found).with(
                :missing_vm,
                instance_without_vm
            )

            expect(cloud_factory).to receive(:get_for_az).with(unresponsive_vm1.availability_zone).and_return(cloud)
            expect(cloud_factory).to receive(:get_for_az).with(unresponsive_vm2.availability_zone).and_return(cloud)
            expect(cloud_factory).to receive(:get_for_az).with(instance_without_vm.availability_zone).and_return(cloud)

            vm_scanner.scan
          end
        end

        context 'when cloud implements has_vm' do
          before do
            allow(cloud).to receive(:has_vm).and_return(true)
          end

          context 'when cloud has VM' do
            it 'registers unresponsive agent problem' do
              expect(event_logger).to receive(:track_and_log).with('Checking VM states')
              expect(event_logger).to receive(:track_and_log).with('1 OK, 2 unresponsive, 0 missing, 0 unbound')

              expect(problem_register).to receive(:problem_found).with(
                :unresponsive_agent,
                unresponsive_vm1
              )

              expect(problem_register).to receive(:problem_found).with(
                :unresponsive_agent,
                unresponsive_vm2
              )

              expect(cloud_factory).to receive(:get_for_az).with(unresponsive_vm1.availability_zone).and_return(cloud)
              expect(cloud_factory).to receive(:get_for_az).with(unresponsive_vm2.availability_zone).and_return(cloud)

              vm_scanner.scan
            end
          end

          context 'when cloud does not have VM' do
            before do
              allow(cloud).to receive(:has_vm).with('vm-cid-0').and_return(false)
            end

            it 'registers missing VM problem' do
              expect(event_logger).to receive(:track_and_log).with('Checking VM states')
              expect(event_logger).to receive(:track_and_log).with('1 OK, 1 unresponsive, 1 missing, 0 unbound')

              expect(problem_register).to receive(:problem_found).with(
                :missing_vm,
                unresponsive_vm1
              )

              expect(problem_register).to receive(:problem_found).with(
                :unresponsive_agent,
                unresponsive_vm2
              )

              expect(cloud_factory).to receive(:get_for_az).with(unresponsive_vm1.availability_zone).and_return(cloud)
              expect(cloud_factory).to receive(:get_for_az).with(unresponsive_vm2.availability_zone).and_return(cloud)

              vm_scanner.scan
            end
          end
        end

        context 'when cloud does not implement has_vm' do
          before do
            allow(cloud).to receive(:has_vm).and_raise(Bosh::Clouds::NotImplemented)
          end

          it 'registers unresponsive agent problem' do
            expect(event_logger).to receive(:track_and_log).with('Checking VM states')
            expect(event_logger).to receive(:track_and_log).with('1 OK, 2 unresponsive, 0 missing, 0 unbound')

            expect(problem_register).to receive(:problem_found).with(
              :unresponsive_agent,
              unresponsive_vm1
            )

            expect(problem_register).to receive(:problem_found).with(
              :unresponsive_agent,
              unresponsive_vm2
            )

            expect(cloud_factory).to receive(:get_for_az).with(unresponsive_vm1.availability_zone).and_return(cloud)
            expect(cloud_factory).to receive(:get_for_az).with(unresponsive_vm2.availability_zone).and_return(cloud)

            vm_scanner.scan
          end
        end

        context 'when a VM is ignored' do
          before do
            ignored_unresponsive_vm = create_vm(4, ignore: true)
            ignored_responsive_vm = create_vm(5, ignore: true)

            ignored_unresponsive_agent = double(AgentClient)
            ignored_responsive_agent =   double(AgentClient)
            agent_options = { timeout: 10, retry_methods: { get_state: 0}}


            allow(AgentClient).to receive(:with_agent_id).with(
              ignored_unresponsive_vm.agent_id,
              ignored_unresponsive_vm.name,
              agent_options,
            ).and_return(ignored_unresponsive_agent)
            allow(AgentClient).to receive(:with_agent_id).with(
              ignored_responsive_vm.agent_id,
              ignored_responsive_vm.name,
              agent_options,
            ).and_return(ignored_responsive_agent)
            allow(ignored_unresponsive_agent).to receive(:get_state).and_raise(RpcTimeout)

            # Working agent
            good_state = {
                'deployment' => 'fake-deployment',
                'job' => {'name' => 'job-1'},
                'index' => 0
            }
            allow(ignored_responsive_agent).to receive(:get_state).and_return(good_state)
            allow(ignored_responsive_agent).to receive(:list_disk).and_return([])

            allow(cloud).to receive(:has_vm).and_return(true)
            expect(cloud_factory).to receive(:get_for_az).with(unresponsive_vm1.availability_zone).and_return(cloud)
            expect(cloud_factory).to receive(:get_for_az).with(unresponsive_vm2.availability_zone).and_return(cloud)
          end

          it 'it is not scanned' do
            expect(event_logger).to receive(:track_and_log).with('Checking VM states')
            expect(event_logger).to receive(:track_and_log).with('1 OK, 2 unresponsive, 0 missing, 0 unbound, 2 ignored')

            vm_scanner.scan
          end
        end
      end
    end

    describe 'agent_disks' do
      let(:instance) { create_vm(0) }
      before { allow(cloud).to receive(:has_vm).and_return(true) }

      let(:agent) { double('Bosh::Director::AgentClient') }
      before { allow(AgentClient).to receive(:with_agent_id).with(instance.agent_id, instance.name, anything).and_return(agent) }

      before do
        Models::PersistentDisk.make(instance_id: instance.id, active: true, disk_cid: 'fake-disk-cid')
      end

      before do
        good_state = {
          'deployment' => 'fake-deployment',
          'job' => {'name' => 'job-1'},
          'index' => 0
        }

        allow(agent).to receive(:get_state).and_return(good_state)
      end

      context 'when agent is not responsive' do
        before do
          allow(agent).to receive(:get_state).and_raise(RpcTimeout)
        end

        it 'returns disk cid registered on vm' do
          expect(cloud_factory).to receive(:get_for_az).with(instance.availability_zone).and_return(cloud)
          expect(problem_register).to receive(:problem_found).with(:unresponsive_agent, instance)
          vm_scanner.scan
          expect(vm_scanner.agent_disks['fake-disk-cid']).to eq(['vm-cid-0'])
        end
      end

      context 'when list_disk times out' do
        before do
          allow(agent).to receive(:list_disk).and_raise(Bosh::Director::RpcTimeout)
        end

        it 'returns empty owners' do
          expect(problem_register).to_not receive(:problem_found)
          vm_scanner.scan
          expect(vm_scanner.agent_disks.size).to eq(0)
        end
      end

      context 'when list_disk returns empty list' do
        before do
          allow(agent).to receive(:list_disk).and_return([])
        end

        it 'returns empty owners' do
          expect(problem_register).to_not receive(:problem_found)
          vm_scanner.scan
          expect(vm_scanner.agent_disks.size).to eq(0)
        end
      end

      context 'when disk is mounted twice' do
        before do
          second_instance = create_vm(1)

          agent_2 = double('agent-2')
          allow(AgentClient).to receive(:with_agent_id).with(
            second_instance.agent_id,
            second_instance.name,
            anything,
          ).and_return(agent_2)

          good_state_2 = {
            'deployment' => 'fake-deployment',
            'job' => {'name' => 'job-2'},
            'index' => 2
          }
          expect(agent_2).to receive(:get_state).and_return(good_state_2)

          expect(agent).to receive(:list_disk).and_return(['fake-disk-cid'])
          expect(agent_2).to receive(:list_disk).and_return(['fake-disk-cid'])
        end

        it 'returns all owners' do
          expect(problem_register).to_not receive(:problem_found)
          vm_scanner.scan
          expect(vm_scanner.agent_disks['fake-disk-cid']).to match_array(['vm-cid-0', 'vm-cid-1'])
        end
      end

      context 'when disk is mounted in different VM' do
        before do
          expect(agent).to receive(:list_disk).and_return(['fake-disk-cid-2'])
        end

        it 'returns the current VM' do
          expect(problem_register).to_not receive(:problem_found)
          vm_scanner.scan
          expect(vm_scanner.agent_disks['fake-disk-cid']).to be_nil
          expect(vm_scanner.agent_disks['fake-disk-cid-2']).to eq(['vm-cid-0'])
        end
      end
    end
  end
end
