require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::Assembler do
    subject(:assembler) { DeploymentPlan::Assembler.new(deployment_plan, stemcell_manager, cloud, blobstore, logger, event_log) }
    let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner', name: 'simple') }
    let(:stemcell_manager) { nil }
    let(:event_log) { Config.event_log }

    let(:blobstore) { instance_double('Bosh::Blobstore::Client') }

    let(:cloud) { instance_double('Bosh::Cloud') }

    it 'should bind releases' do
      r1 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'r1')
      r2 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'r2')

      expect(deployment_plan).to receive(:releases).and_return([r1, r2])

      expect(r1).to receive(:bind_model)
      expect(r2).to receive(:bind_model)

      expect(assembler).to receive(:with_release_locks).with(['r1', 'r2']).and_yield
      assembler.bind_releases
    end

    describe 'bind_job_renames' do
      let(:instance_model) { Models::Instance.make(job: 'old-name') }
      let(:job) { instance_double(DeploymentPlan::Job) }

      before do
        allow(deployment_plan).to receive(:instance_models).and_return([instance_model])
      end

      context 'when rename is in progress' do
        before { allow(deployment_plan).to receive(:rename_in_progress?).and_return(true) }

        it 'updates instance' do
          allow(deployment_plan).to receive(:job_rename).and_return({
                'old_name' => instance_model.job,
                'new_name' => 'new-name'
              })

          expect {
            assembler.bind_job_renames
          }.to change {
              instance_model.job
            }.from('old-name').to('new-name')
        end
      end

      context 'when rename is not in progress' do
        before { allow(deployment_plan).to receive(:rename_in_progress?).and_return(false) }

        it 'does not update instances' do
          expect {
            assembler.bind_job_renames
          }.to_not change {
              instance_model.job
            }
        end
      end
    end

    describe 'bind_instance_plans' do
      let(:new_instance) { instance_double(Bosh::Director::DeploymentPlan::Instance) }
      let(:existing_instance) { instance_double(Bosh::Director::DeploymentPlan::Instance, model: existing_instance_model) }
      let(:obsolete_instance) { instance_double(Bosh::Director::DeploymentPlan::ExistingInstance, model: obsolete_instance_model) }

      let(:existing_instance_model) { Bosh::Director::Models::Instance.make }
      let(:obsolete_instance_model) { Bosh::Director::Models::Instance.make }

      let(:existing_instance_state) do
        {
          'deployment' => 'simple',
          'job' => { 'name' => existing_instance_model.job },
          'index' => existing_instance_model.index
        }
      end

      let(:obsolete_instance_state) do
        {
          'deployment' => 'simple',
          'job' => { 'name' => obsolete_instance_model.job },
          'index' => obsolete_instance_model.index
        }
      end


      let(:new_plan) { Bosh::Director::DeploymentPlan::InstancePlan.new(instance: new_instance, existing_instance: nil) }
      let(:existing_plan) { Bosh::Director::DeploymentPlan::InstancePlan.new(instance: existing_instance, existing_instance: existing_instance_model) }
      let(:obsolete_plan) { Bosh::Director::DeploymentPlan::InstancePlan.new(instance: obsolete_instance, existing_instance: obsolete_instance_model, obsolete: true) }

      before do
        allow(new_instance).to receive(:bind_new_instance_model)
        allow(existing_instance).to receive(:bind_existing_instance_model)
        allow(existing_instance).to receive(:bind_current_state)
        allow(deployment_plan).to receive(:mark_instance_for_deletion)

        existing_agent_client = instance_double(AgentClient)
        obsolete_agent_client = instance_double(AgentClient)
        allow(AgentClient).to receive(:with_vm).with(existing_instance_model.vm).and_return(existing_agent_client)
        allow(AgentClient).to receive(:with_vm).with(obsolete_instance_model.vm).and_return(obsolete_agent_client)
        allow(existing_agent_client).to receive(:get_state).and_return(existing_instance_state)
        allow(obsolete_agent_client).to receive(:get_state).and_return(obsolete_instance_state)


        allow(deployment_plan).to receive(:instance_plans) { [new_plan, existing_plan, obsolete_plan] }
      end

      it 'binds new models for new plans' do
        assembler.bind_instance_plans

        expect(new_instance).to have_received(:bind_new_instance_model)
      end

      it 'binds existing models for existing plans and obsolete plans' do
        assembler.bind_instance_plans

        expect(existing_instance).to have_received(:bind_existing_instance_model).with(existing_instance_model)
      end

      describe 'binding the current vm state' do
        it 'binds current state for existing plans and obsolete plans' do
          assembler.bind_instance_plans

          expect(existing_instance).to have_received(:bind_current_state).with(existing_instance_state)
        end
      end

      it 'marks obsolete plans for deletion' do
        assembler.bind_instance_plans

        expect(deployment_plan).to have_received(:mark_instance_for_deletion).with(obsolete_instance)
      end
    end

    it 'should bind stemcells' do
      sc1 = instance_double('Bosh::Director::DeploymentPlan::Stemcell')
      sc2 = instance_double('Bosh::Director::DeploymentPlan::Stemcell')

      rp1 = instance_double('Bosh::Director::DeploymentPlan::ResourcePool', :stemcell => sc1)
      rp2 = instance_double('Bosh::Director::DeploymentPlan::ResourcePool', :stemcell => sc2)

      expect(deployment_plan).to receive(:resource_pools).and_return([rp1, rp2])

      expect(sc1).to receive(:bind_model)
      expect(sc2).to receive(:bind_model)

      assembler.bind_stemcells
    end

    describe '#bind_templates' do
      it 'should bind templates' do
        r1 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion')
        r2 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion')

        expect(deployment_plan).to receive(:releases).and_return([r1, r2])
        allow(deployment_plan).to receive(:jobs).and_return([])

        expect(r1).to receive(:bind_templates)
        expect(r2).to receive(:bind_templates)

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
        expect(deployment_plan).to receive(:jobs_starting_on_deploy).and_return([j1, j2])

        [j1, j2].each do |job|
          expect(job).to receive(:bind_unallocated_vms).with(no_args).ordered
        end

        assembler.bind_unallocated_vms
      end
    end

    describe '#get_state' do
      it 'should return the processed agent state' do
        state = { 'state' => 'baz' }

        vm_model = Models::Vm.make(:agent_id => 'agent-1')
        client = double('AgentClient')
        expect(AgentClient).to receive(:with_vm).with(vm_model).and_return(client)

        expect(client).to receive(:get_state).and_return(state)
        expect(assembler).to receive(:verify_state).with(vm_model, state)
        expect(assembler).to receive(:migrate_legacy_state).
          with(vm_model, state)

        expect(assembler.get_state(vm_model)).to eq(state)
      end

      context 'when the returned state contains top level "release" key' do
        let(:agent_client) { double('AgentClient') }
        let(:vm_model) { Models::Vm.make(:agent_id => 'agent-1') }
        before { allow(AgentClient).to receive(:with_vm).with(vm_model).and_return(agent_client) }

        it 'prunes the legacy "release" data to avoid unnecessary update' do
          legacy_state = { 'release' => 'cf', 'other' => 'data', 'job' => {} }
          final_state = { 'other' => 'data', 'job' => {} }
          allow(agent_client).to receive(:get_state).and_return(legacy_state)

          allow(assembler).to receive(:verify_state).with(vm_model, legacy_state)
          allow(assembler).to receive(:migrate_legacy_state).with(vm_model, legacy_state)

          expect(assembler.get_state(vm_model)).to eq(final_state)
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
            allow(agent_client).to receive(:get_state).and_return(legacy_state)

            allow(assembler).to receive(:verify_state).with(vm_model, legacy_state)
            allow(assembler).to receive(:migrate_legacy_state).with(vm_model, legacy_state)

            expect(assembler.get_state(vm_model)).to eq(final_state)
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
            allow(agent_client).to receive(:get_state).and_return(legacy_state)

            allow(assembler).to receive(:verify_state).with(vm_model, legacy_state)
            allow(assembler).to receive(:migrate_legacy_state).with(vm_model, legacy_state)

            expect(assembler.get_state(vm_model)).to eq(final_state)
          end
        end
      end

      context 'when the returned state does not contain top level "release" key' do
        let(:agent_client) { double('AgentClient') }
        let(:vm_model) { Models::Vm.make(:agent_id => 'agent-1') }
        before do
          allow(AgentClient).to receive(:with_vm).with(vm_model).and_return(agent_client)
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
            allow(agent_client).to receive(:get_state).and_return(legacy_state)

            allow(assembler).to receive(:verify_state).with(vm_model, legacy_state)
            allow(assembler).to receive(:migrate_legacy_state).with(vm_model, legacy_state)

            expect(assembler.get_state(vm_model)).to eq(final_state)
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
            allow(agent_client).to receive(:get_state).and_return(legacy_state)

            allow(assembler).to receive(:verify_state).with(vm_model, legacy_state)
            allow(assembler).to receive(:migrate_legacy_state).with(vm_model, legacy_state)

            expect(assembler.get_state(vm_model)).to eq(final_state)
          end
        end
      end
    end

    describe '#verify_state' do
      before do
        @deployment = Models::Deployment.make(:name => 'foo')
        @vm_model = Models::Vm.make(:deployment => @deployment, :cid => 'foo')
        allow(deployment_plan).to receive(:name).and_return('foo')
        allow(deployment_plan).to receive(:model).and_return(@deployment)
      end

      it 'should do nothing when VM is ok' do
        assembler.verify_state(@vm_model, { 'deployment' => 'foo' })
      end

      it 'should do nothing when instance is ok' do
        Models::Instance.make(
          :deployment => @deployment, :vm => @vm_model, :job => 'bar', :index => 11)
        assembler.verify_state(@vm_model, {
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
          :deployment => other_deployment, :vm => @vm_model, :job => 'bar',
          :index => 11)
        expect {
          assembler.verify_state(@vm_model, {
            'deployment' => 'foo',
            'job' => { 'name' => 'bar' },
            'index' => 11
          })
        }.to raise_error(VmInstanceOutOfSync,
                             "VM `foo' and instance `bar/11' " +
                               "don't belong to the same deployment")
      end

      it 'should make sure the state is a Hash' do
        expect {
          assembler.verify_state(@vm_model, 'state')
        }.to raise_error(AgentInvalidStateFormat, /expected Hash/)
      end

      it 'should make sure the deployment name is correct' do
        expect {
          assembler.verify_state(@vm_model, { 'deployment' => 'foz' })
        }.to raise_error(AgentWrongDeployment,
                             "VM `foo' is out of sync: expected to be a part " +
                               "of deployment `foo' but is actually a part " +
                               "of deployment `foz'")
      end

      it 'should make sure the job and index exist' do
        expect {
          assembler.verify_state(@vm_model, {
            'deployment' => 'foo',
            'job' => { 'name' => 'bar' },
            'index' => 11
          })
        }.to raise_error(AgentUnexpectedJob,
                             "VM `foo' is out of sync: it reports itself as " +
                               "`bar/11' but there is no instance reference in DB")
      end

      it 'should make sure the job and index are correct' do
        expect {
          allow(deployment_plan).to receive(:job_rename).and_return({})
          allow(deployment_plan).to receive(:rename_in_progress?).and_return(false)
          Models::Instance.make(
            :deployment => @deployment, :vm => @vm_model, :job => 'bar', :index => 11)
          assembler.verify_state(@vm_model, {
            'deployment' => 'foo',
            'job' => { 'name' => 'bar' },
            'index' => 22
          })
        }.to raise_error(AgentJobMismatch,
                             "VM `foo' is out of sync: it reports itself as " +
                               "`bar/22' but according to DB it is `bar/11'")
      end
    end

    describe '#migrate_legacy_state'

    describe '#bind_instance_networks' do
      it 'binds unallocated VMs for each job' do
        j1 = instance_double('Bosh::Director::DeploymentPlan::Job')
        j2 = instance_double('Bosh::Director::DeploymentPlan::Job')
        expect(deployment_plan).to receive(:jobs_starting_on_deploy).and_return([j1, j2])

        [j1, j2].each do |job|
          expect(job).to receive(:bind_instance_networks).with(no_args).ordered
        end

        assembler.bind_instance_networks
      end
    end

    describe '#bind_dns' do
      it 'uses DnsBinder to create dns records for deployment' do
        binder = instance_double('Bosh::Director::DeploymentPlan::DnsBinder')
        allow(DeploymentPlan::DnsBinder).to receive(:new).with(deployment_plan).and_return(binder)
        expect(binder).to receive(:bind_deployment).with(no_args)
        assembler.bind_dns
      end
    end
  end
end
