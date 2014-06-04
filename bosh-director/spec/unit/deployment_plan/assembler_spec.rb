require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe Assembler do
      subject(:assembler) { described_class.new(deployment_plan) }
      let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner') }

      before { App.stub_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
      let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

      before { allow(Config).to receive(:cloud).and_return(cloud) }
      let(:cloud) { instance_double('Bosh::Cloud') }

      it 'should bind deployment' do
        deployment_plan.should_receive(:bind_model)
        assembler.bind_deployment
      end

      it 'should bind releases' do
        r1 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion')
        r2 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion')

        deployment_plan.should_receive(:releases).and_return([r1, r2])

        r1.should_receive(:bind_model)
        r2.should_receive(:bind_model)

        assembler.should_receive(:with_release_locks).and_yield
        assembler.bind_releases
      end

      it 'should bind existing VMs' do
        vm1 = Models::Vm.make
        vm2 = Models::Vm.make

        deployment_plan.stub(:vms).and_return([vm1, vm2])

        assembler.should_receive(:bind_existing_vm).with(vm1, an_instance_of(Mutex))
        assembler.should_receive(:bind_existing_vm).with(vm2, an_instance_of(Mutex))

        assembler.bind_existing_deployment
      end

      it 'should bind resource pools' do
        rp1 = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
        rp2 = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')

        deployment_plan.should_receive(:resource_pools).and_return([rp1, rp2])

        rp1.should_receive(:process_idle_vms)
        rp2.should_receive(:process_idle_vms)

        assembler.bind_resource_pools
      end

      it 'should bind stemcells' do
        sc1 = instance_double('Bosh::Director::DeploymentPlan::Stemcell')
        sc2 = instance_double('Bosh::Director::DeploymentPlan::Stemcell')

        rp1 = instance_double('Bosh::Director::DeploymentPlan::ResourcePool', :stemcell => sc1)
        rp2 = instance_double('Bosh::Director::DeploymentPlan::ResourcePool', :stemcell => sc2)

        deployment_plan.should_receive(:resource_pools).and_return([rp1, rp2])

        sc1.should_receive(:bind_model)
        sc2.should_receive(:bind_model)

        assembler.bind_stemcells
      end

      describe '#bind_templates' do
        it 'should bind templates' do
          r1 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion')
          r2 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion')

          deployment_plan.should_receive(:releases).and_return([r1, r2])
          allow(deployment_plan).to receive(:jobs).and_return([])

          r1.should_receive(:bind_templates)
          r2.should_receive(:bind_templates)

          assembler.bind_templates
        end

        it 'validates the jobs' do
          j1 = instance_double('Bosh::Director::DeploymentPlan::Job')
          j2 = instance_double('Bosh::Director::DeploymentPlan::Job')

          expect(deployment_plan).to receive(:jobs).and_return([j1, j2])
          allow(deployment_plan).to receive(:releases).and_return([])

          expect(j1).to receive(:validate_package_names_do_not_collide!).once
          expect(j2).to receive(:validate_package_names_do_not_collide!).once

          assembler.bind_templates
        end

        context 'when the job validation fails' do
          it "bubbles up the exception" do
            j1 = instance_double('Bosh::Director::DeploymentPlan::Job')
            j2 = instance_double('Bosh::Director::DeploymentPlan::Job')

            allow(deployment_plan).to receive(:jobs).and_return([j1, j2])
            allow(deployment_plan).to receive(:releases).and_return([])

            expect(j1).to receive(:validate_package_names_do_not_collide!).once
            expect(j2).to receive(:validate_package_names_do_not_collide!).once.and_raise('Unable to deploy manifest')

            expect { assembler.bind_templates }.to raise_error('Unable to deploy manifest')
          end
        end
      end

      describe '#bind_unallocated_vms' do
        it 'binds unallocated VMs for each job' do
          j1 = instance_double('Bosh::Director::DeploymentPlan::Job')
          j2 = instance_double('Bosh::Director::DeploymentPlan::Job')
          deployment_plan.should_receive(:jobs_starting_on_deploy).and_return([j1, j2])

          [j1, j2].each do |job|
            expect(job).to receive(:bind_unallocated_vms).with(no_args).ordered
          end

          assembler.bind_unallocated_vms
        end
      end

      describe '#bind_existing_vm' do
        before do
          @lock = Mutex.new
          @vm = Models::Vm.make(:agent_id => 'foo')
        end

        it 'should bind an instance' do
          instance = Models::Instance.make(:vm => @vm)
          state = { 'state' => 'foo' }
          reservations = { 'foo' => 'reservation' }

          assembler.should_receive(:get_state).with(@vm).
            and_return(state)
          assembler.should_receive(:get_network_reservations).
            with(state).and_return(reservations)
          assembler.should_receive(:bind_instance).
            with(instance, state, reservations)
          assembler.bind_existing_vm(@vm, @lock)
        end

        it 'should bind an idle vm' do
          state = { 'resource_pool' => { 'name' => 'baz' } }
          reservations = { 'foo' => 'reservation' }
          resource_pool = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')

          deployment_plan.stub(:resource_pool).with('baz').
            and_return(resource_pool)

          assembler.should_receive(:get_state).with(@vm).
            and_return(state)
          assembler.should_receive(:get_network_reservations).
            with(state).and_return(reservations)
          assembler.should_receive(:bind_idle_vm).
            with(@vm, resource_pool, state, reservations)
          assembler.bind_existing_vm(@vm, @lock)
        end

        it 'should delete no longer needed vms' do
          state = { 'resource_pool' => { 'name' => 'baz' } }
          reservations = { 'foo' => 'reservation' }

          deployment_plan.stub(:resource_pool).with('baz').
            and_return(nil)

          assembler.should_receive(:get_state).with(@vm).
            and_return(state)
          assembler.should_receive(:get_network_reservations).
            with(state).and_return(reservations)
          deployment_plan.should_receive(:delete_vm).with(@vm)
          assembler.bind_existing_vm(@vm, @lock)
        end
      end

      describe '#bind_idle_vm' do
        before do
          @network = instance_double('Bosh::Director::DeploymentPlan::Network')
          @network.stub(:name).and_return('foo')
          @reservation = instance_double('Bosh::Director::NetworkReservation')
          @resource_pool = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
          @resource_pool.stub(:name).and_return('baz')
          @resource_pool.stub(:network).and_return(@network)
          @idle_vm = instance_double('Bosh::Director::DeploymentPlan::IdleVm')
          @vm = Models::Vm.make
        end

        it 'should add the existing idle VM' do
          @resource_pool.should_receive(:add_idle_vm).and_return(@idle_vm)
          @idle_vm.should_receive(:vm=).with(@vm)
          @idle_vm.should_receive(:current_state=).with({ 'state' => 'foo' })

          assembler.bind_idle_vm(
            @vm, @resource_pool, { 'state' => 'foo' }, {})
        end

        it 'should release a static network reservation' do
          @reservation.stub(:static?).and_return(true)

          @resource_pool.should_receive(:add_idle_vm).and_return(@idle_vm)
          @idle_vm.should_receive(:vm=).with(@vm)
          @idle_vm.should_receive(:current_state=).with({ 'state' => 'foo' })
          @network.should_receive(:release).with(@reservation)

          assembler.bind_idle_vm(
            @vm, @resource_pool, { 'state' => 'foo' }, { 'foo' => @reservation })
        end

        it 'should reuse a valid network reservation' do
          @reservation.stub(:static?).and_return(false)

          @resource_pool.should_receive(:add_idle_vm).and_return(@idle_vm)
          @idle_vm.should_receive(:vm=).with(@vm)
          @idle_vm.should_receive(:current_state=).with({ 'state' => 'foo' })
          @idle_vm.should_receive(:use_reservation).with(@reservation)

          assembler.bind_idle_vm(
            @vm, @resource_pool, { 'state' => 'foo' }, { 'foo' => @reservation })
        end
      end

      describe '#bind_instance' do
        before { @model = Models::Instance.make(:job => 'foo', :index => 3) }

        it 'should associate the instance to the instance spec' do
          state = { 'state' => 'baz' }
          reservations = { 'net' => 'reservation' }

          instance = instance_double('Bosh::Director::DeploymentPlan::Instance')
          resource_pool = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
          job = instance_double('Bosh::Director::DeploymentPlan::Job')
          job.stub(:instance).with(3).and_return(instance)
          job.stub(:resource_pool).and_return(resource_pool)
          deployment_plan.stub(:job).with('foo').and_return(job)
          deployment_plan.stub(:job_rename).and_return({})
          deployment_plan.stub(:rename_in_progress?).and_return(false)

          instance.should_receive(:use_model).with(@model)
          instance.should_receive(:current_state=).with(state)
          instance.should_receive(:take_network_reservations).with(reservations)
          resource_pool.should_receive(:mark_active_vm)

          assembler.bind_instance(@model, state, reservations)
        end

        it 'should update the instance name if it is being renamed' do
          state = { 'state' => 'baz' }
          reservations = { 'net' => 'reservation' }

          instance = instance_double('Bosh::Director::DeploymentPlan::Instance')
          resource_pool = instance_double('Bosh::Director::DeploymentPlan::ResourcePool')
          job = instance_double('Bosh::Director::DeploymentPlan::Job')
          job.stub(:instance).with(3).and_return(instance)
          job.stub(:resource_pool).and_return(resource_pool)
          deployment_plan.stub(:job).with('bar').and_return(job)
          deployment_plan.stub(:job_rename).
            and_return({ 'old_name' => 'foo', 'new_name' => 'bar' })
          deployment_plan.stub(:rename_in_progress?).and_return(true)

          instance.should_receive(:use_model).with(@model)
          instance.should_receive(:current_state=).with(state)
          instance.should_receive(:take_network_reservations).with(reservations)
          resource_pool.should_receive(:mark_active_vm)

          assembler.bind_instance(@model, state, reservations)
        end

        it "should mark the instance for deletion when it's no longer valid" do
          state = { 'state' => 'baz' }
          reservations = { 'net' => 'reservation' }
          deployment_plan.stub(:job).with('foo').and_return(nil)
          deployment_plan.should_receive(:delete_instance).with(@model)
          deployment_plan.stub(:job_rename).and_return({})
          deployment_plan.stub(:rename_in_progress?).and_return(false)

          assembler.bind_instance(@model, state, reservations)
        end
      end

      describe '#get_network_reservations' do
        it 'should reserve all of the networks listed in the state' do
          foo_network = instance_double('Bosh::Director::DeploymentPlan::Network')
          bar_network = instance_double('Bosh::Director::DeploymentPlan::Network')

          deployment_plan.stub(:network).with('foo').and_return(foo_network)
          deployment_plan.stub(:network).with('bar').and_return(bar_network)

          foo_reservation = nil
          foo_network.should_receive(:reserve) do |reservation|
            reservation.ip.should == NetAddr::CIDR.create('1.2.3.4').to_i
            reservation.reserved = true
            foo_reservation = reservation
            true
          end

          bar_network.should_receive(:reserve) do |reservation|
            reservation.ip.should == NetAddr::CIDR.create('10.20.30.40').to_i
            reservation.reserved = false
            false
          end

          assembler.get_network_reservations(
            'networks' => {
              'foo' => {
                'ip' => '1.2.3.4'
              },
              'bar' => {
                'ip' => '10.20.30.40'
              }
            }
          ).should == { 'foo' => foo_reservation }
        end
      end

      describe '#get_state' do
        it 'should return the processed agent state' do
          state = { 'state' => 'baz' }

          vm = Models::Vm.make(:agent_id => 'agent-1')
          client = double('AgentClient')
          AgentClient.should_receive(:with_defaults).with('agent-1').and_return(client)

          client.should_receive(:get_state).and_return(state)
          assembler.should_receive(:verify_state).with(vm, state)
          assembler.should_receive(:migrate_legacy_state).
            with(vm, state)

          assembler.get_state(vm).should eq(state)
        end

        context 'when the returned state contains top level "release" key' do
          let(:agent_client) { double('AgentClient') }
          let(:vm) { Models::Vm.make(:agent_id => 'agent-1') }
          before do
            allow(AgentClient).to receive(:with_defaults).with('agent-1').and_return(agent_client)
          end

          it 'prunes the legacy "release" data to avoid unnecessary update' do
            legacy_state = { 'release' => 'cf', 'other' => 'data', 'job' => {} }
            final_state = { 'other' => 'data', 'job' => {} }
            agent_client.stub(:get_state).and_return(legacy_state)

            assembler.stub(:verify_state).with(vm, legacy_state)
            assembler.stub(:migrate_legacy_state).with(vm, legacy_state)

            assembler.get_state(vm).should eq(final_state)
          end

          context 'and the returned state contains a job level release' do
            it 'prunes the legacy "release" in job section so as to avoid unnecessary update' do
              legacy_state = {
                'release' => 'cf',
                'other' => 'data',
                'job' => {
                  'release' => 'sql-release',
                  'more' => 'data',
                },
              }
              final_state = {
                'other' => 'data',
                'job' => {
                  'more' => 'data',
                },
              }
              agent_client.stub(:get_state).and_return(legacy_state)

              assembler.stub(:verify_state).with(vm, legacy_state)
              assembler.stub(:migrate_legacy_state).with(vm, legacy_state)

              assembler.get_state(vm).should eq(final_state)
            end
          end

          context 'and the returned state does not contain a job level release' do
            it 'returns the job section as-is' do
              legacy_state = {
                'release' => 'cf',
                'other' => 'data',
                'job' => {
                  'more' => 'data',
                },
              }
              final_state = {
                'other' => 'data',
                'job' => {
                  'more' => 'data',
                },
              }
              agent_client.stub(:get_state).and_return(legacy_state)

              assembler.stub(:verify_state).with(vm, legacy_state)
              assembler.stub(:migrate_legacy_state).with(vm, legacy_state)

              assembler.get_state(vm).should eq(final_state)
            end
          end
        end

        context 'when the returned state does not contain top level "release" key' do
          let(:agent_client) { double('AgentClient') }
          let(:vm) { Models::Vm.make(:agent_id => 'agent-1') }
          before do
            allow(AgentClient).to receive(:with_defaults).with('agent-1').and_return(agent_client)
          end

          context 'and the returned state contains a job level release' do
            it 'prunes the legacy "release" in job section so as to avoid unnecessary update' do
              legacy_state = {
                'other' => 'data',
                'job' => {
                  'release' => 'sql-release',
                  'more' => 'data',
                },
              }
              final_state = {
                'other' => 'data',
                'job' => {
                  'more' => 'data',
                },
              }
              agent_client.stub(:get_state).and_return(legacy_state)

              assembler.stub(:verify_state).with(vm, legacy_state)
              assembler.stub(:migrate_legacy_state).with(vm, legacy_state)

              assembler.get_state(vm).should eq(final_state)
            end
          end

          context 'and the returned state does not contain a job level release' do
            it 'returns the job section as-is' do
              legacy_state = {
                'release' => 'cf',
                'other' => 'data',
                'job' => {
                  'more' => 'data',
                },
              }
              final_state = {
                'other' => 'data',
                'job' => {
                  'more' => 'data',
                },
              }
              agent_client.stub(:get_state).and_return(legacy_state)

              assembler.stub(:verify_state).with(vm, legacy_state)
              assembler.stub(:migrate_legacy_state).with(vm, legacy_state)

              assembler.get_state(vm).should eq(final_state)
            end
          end
        end
      end

      describe '#verify_state' do
        before do
          @deployment = Models::Deployment.make(:name => 'foo')
          @vm = Models::Vm.make(:deployment => @deployment, :cid => 'foo')
          deployment_plan.stub(:name).and_return('foo')
          deployment_plan.stub(:model).and_return(@deployment)
        end

        it 'should do nothing when VM is ok' do
          assembler.verify_state(@vm, { 'deployment' => 'foo' })
        end

        it 'should do nothing when instance is ok' do
          Models::Instance.make(
            :deployment => @deployment, :vm => @vm, :job => 'bar', :index => 11)
          assembler.verify_state(@vm, {
            'deployment' => 'foo',
            'job' => {
              'name' => 'bar'
            },
            'index' => 11
          })
        end

        it 'should make sure VM and instance belong to the same deployment' do
          other_deployment = Models::Deployment.make
          Models::Instance.make(
            :deployment => other_deployment, :vm => @vm, :job => 'bar',
            :index => 11)
          lambda {
            assembler.verify_state(@vm, {
              'deployment' => 'foo',
              'job' => { 'name' => 'bar' },
              'index' => 11
            })
          }.should raise_error(VmInstanceOutOfSync,
                               "VM `foo' and instance `bar/11' " +
                                 "don't belong to the same deployment")
        end

        it 'should make sure the state is a Hash' do
          lambda {
            assembler.verify_state(@vm, 'state')
          }.should raise_error(AgentInvalidStateFormat, /expected Hash/)
        end

        it 'should make sure the deployment name is correct' do
          lambda {
            assembler.verify_state(@vm, { 'deployment' => 'foz' })
          }.should raise_error(AgentWrongDeployment,
                               "VM `foo' is out of sync: expected to be a part " +
                                 "of deployment `foo' but is actually a part " +
                                 "of deployment `foz'")
        end

        it 'should make sure the job and index exist' do
          lambda {
            assembler.verify_state(@vm, {
              'deployment' => 'foo',
              'job' => { 'name' => 'bar' },
              'index' => 11
            })
          }.should raise_error(AgentUnexpectedJob,
                               "VM `foo' is out of sync: it reports itself as " +
                                 "`bar/11' but there is no instance reference in DB")
        end

        it 'should make sure the job and index are correct' do
          lambda {
            deployment_plan.stub(:job_rename).and_return({})
            deployment_plan.stub(:rename_in_progress?).and_return(false)
            Models::Instance.make(
              :deployment => @deployment, :vm => @vm, :job => 'bar', :index => 11)
            assembler.verify_state(@vm, {
              'deployment' => 'foo',
              'job' => { 'name' => 'bar' },
              'index' => 22
            })
          }.should raise_error(AgentJobMismatch,
                               "VM `foo' is out of sync: it reports itself as " +
                                 "`bar/22' but according to DB it is `bar/11'")
        end
      end

      describe '#migrate_legacy_state'

      describe '#bind_resource_pools'

      describe '#bind_instance_networks' do
        it 'binds unallocated VMs for each job' do
          j1 = instance_double('Bosh::Director::DeploymentPlan::Job')
          j2 = instance_double('Bosh::Director::DeploymentPlan::Job')
          deployment_plan.should_receive(:jobs_starting_on_deploy).and_return([j1, j2])

          [j1, j2].each do |job|
            expect(job).to receive(:bind_instance_networks).with(no_args).ordered
          end

          assembler.bind_instance_networks
        end
      end

      describe '#bind_configuration' do
        before { allow(deployment_plan).to receive(:jobs_starting_on_deploy).and_return([job]) }
        let(:job) { instance_double('Bosh::Director::DeploymentPlan::Job') }

        it 'renders job templates for all instances' do
          job_renderer = instance_double('Bosh::Director::JobRenderer')
          allow(JobRenderer).to receive(:new).with(job, blobstore).and_return(job_renderer)
          expect(job_renderer).to receive(:render_job_instances).with(no_args)
          assembler.bind_configuration
        end
      end

      describe '#bind_dns' do
        it 'uses DnsBinder to create dns records for deployment' do
          binder = instance_double('Bosh::Director::DeploymentPlan::DnsBinder')
          allow(DnsBinder).to receive(:new).with(deployment_plan).and_return(binder)
          expect(binder).to receive(:bind_deployment).with(no_args)
          assembler.bind_dns
        end
      end

      describe '#bind_instance_vms' do
        before { allow(deployment_plan).to receive(:jobs_starting_on_deploy).with(no_args).and_return([job1, job2]) }
        let(:job1) { instance_double('Bosh::Director::DeploymentPlan::Job') }
        let(:job2) { instance_double('Bosh::Director::DeploymentPlan::Job') }

        before { allow(job1).to receive(:instances).with(no_args).and_return([instance1, instance2]) }
        let(:instance1) { instance_double('Bosh::Director::DeploymentPlan::Instance') }
        let(:instance2) { instance_double('Bosh::Director::DeploymentPlan::Instance') }

        before { allow(job2).to receive(:instances).with(no_args).and_return([instance3]) }
        let(:instance3) { instance_double('Bosh::Director::DeploymentPlan::Instance') }

        before { allow(Config).to receive(:event_log).with(no_args).and_return(event_log) }
        let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

        before { allow(event_log).to receive(:track).and_yield }

        it 'uses InstanceVmBinder to bind instances from all jobs' do
          binder = instance_double('Bosh::Director::DeploymentPlan::InstanceVmBinder')
          allow(InstanceVmBinder).to receive(:new).with(event_log).and_return(binder)
          expect(binder).to receive(:bind_instance_vms).with([instance1, instance2, instance3])
          assembler.bind_instance_vms
        end
      end

      describe '#delete_unneeded_vms' do
        it 'should delete unneeded VMs' do
          vm = Models::Vm.make(:cid => 'vm-cid')
          deployment_plan.stub(:unneeded_vms).and_return([vm])

          cloud.should_receive(:delete_vm).with('vm-cid')
          assembler.delete_unneeded_vms

          Models::Vm[vm.id].should be_nil
          check_event_log do |events|
            events.size.should == 2
            events.map { |e| e['stage'] }.uniq.should == ['Deleting unneeded VMs']
            events.map { |e| e['total'] }.uniq.should == [1]
            events.map { |e| e['task'] }.uniq.should == %w(vm-cid)
          end
        end
      end

      describe '#delete_unneeded_instances' do
        before { allow(Config).to receive(:event_log).and_return(event_log) }
        let(:event_log) { instance_double('Bosh::Director::EventLog::Log') }

        it 'deletes unneeded instances and records stage progress' do
          instance = Models::Instance.make
          allow(deployment_plan).to receive(:unneeded_instances).and_return([instance])

          instance_deleter = instance_double('Bosh::Director::InstanceDeleter')
          expect(InstanceDeleter).to receive(:new)
            .with(deployment_plan)
            .and_return(instance_deleter)

          event_log_stage = instance_double('Bosh::Director::EventLog::Stage')
          expect(event_log).to receive(:begin_stage)
            .with('Deleting unneeded instances', 1)
            .and_return(event_log_stage)

          expect(instance_deleter).to receive(:delete_instances)
            .with([instance], event_log_stage)

          assembler.delete_unneeded_instances
        end
      end
    end
  end
end
