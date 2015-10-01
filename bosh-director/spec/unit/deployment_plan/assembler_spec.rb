require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::Assembler do
    subject(:assembler) { DeploymentPlan::Assembler.new(deployment_plan, stemcell_manager, cloud, logger, event_log) }
    let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner', name: 'simple') }
    let(:stemcell_manager) { nil }
    let(:event_log) { Config.event_log }

    let(:cloud) { instance_double('Bosh::Cloud') }

    describe '#bind_models' do
      let(:instance_model) { Models::Instance.make(job: 'old-name') }
      let(:job) { instance_double(DeploymentPlan::Job) }

      before do
        allow(deployment_plan).to receive(:instance_models).and_return([instance_model])
        allow(deployment_plan).to receive(:rename_in_progress?).and_return(false)
        allow(deployment_plan).to receive(:jobs).and_return([])
        allow(deployment_plan).to receive(:existing_instances).and_return([])
        allow(deployment_plan).to receive(:candidate_existing_instances).and_return([])
        allow(deployment_plan).to receive(:vm_models).and_return([])
        allow(deployment_plan).to receive(:resource_pools).and_return(nil)
        allow(deployment_plan).to receive(:stemcells).and_return({})
        allow(deployment_plan).to receive(:jobs_starting_on_deploy).and_return([])
        allow(deployment_plan).to receive(:releases).and_return([])

        binder = instance_double('Bosh::Director::DeploymentPlan::DnsBinder')
        allow(DeploymentPlan::DnsBinder).to receive(:new).with(deployment_plan).and_return(binder)
        allow(binder).to receive(:bind_deployment)
      end

      it 'should bind releases and their templates' do
        r1 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'r1')
        r2 = instance_double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'r2')

        allow(deployment_plan).to receive(:releases).and_return([r1, r2])

        expect(r1).to receive(:bind_model)
        expect(r2).to receive(:bind_model)

        expect(r1).to receive(:bind_templates)
        expect(r2).to receive(:bind_templates)

        expect(assembler).to receive(:with_release_locks).with(['r1', 'r2']).and_yield
        assembler.bind_models
      end

      describe 'bind_job_renames' do
        context 'when rename is in progress' do
          before { allow(deployment_plan).to receive(:rename_in_progress?).and_return(true) }

          it 'updates instance' do
            allow(deployment_plan).to receive(:job_rename).and_return({
                  'old_name' => instance_model.job,
                  'new_name' => 'new-name'
                })

            expect {
              assembler.bind_models
            }.to change {
                instance_model.job
              }.from('old-name').to('new-name')
          end
        end

        context 'when rename is not in progress' do
          before { allow(deployment_plan).to receive(:rename_in_progress?).and_return(false) }

          it 'does not update instances' do
            expect {
              assembler.bind_models
            }.to_not change {
                instance_model.job
              }
          end
        end
      end

      it 'should bind stemcells' do
        sc1 = instance_double('Bosh::Director::DeploymentPlan::Stemcell')
        sc2 = instance_double('Bosh::Director::DeploymentPlan::Stemcell')

        expect(deployment_plan).to receive(:stemcells).and_return({ 'sc1' => sc1, 'sc2' => sc2})

        expect(sc1).to receive(:bind_model)
        expect(sc2).to receive(:bind_model)

        assembler.bind_models
      end

      context 'when there are desired jobs' do
        def make_job(template_name)
          job = DeploymentPlan::Job.new(deployment_plan, Config.logger)
          template_model = Models::Template.make(name: template_name)
          release_version = instance_double(DeploymentPlan::ReleaseVersion)
          allow(release_version).to receive(:get_template_model_by_name).and_return(template_model)
          template = DeploymentPlan::Template.new(release_version, template_name)
          template.bind_models
          job.templates = [template]
          allow(job).to receive(:validate_package_names_do_not_collide!)
          allow(job).to receive(:reserve_ips)
          job
        end

        let(:j1) { make_job('fake-template-1') }
        let(:j2) { make_job('fake-template-2') }

        before { allow(deployment_plan).to receive(:jobs).and_return([j1, j2]) }

        it 'validates the jobs' do
          expect(j1).to receive(:validate_package_names_do_not_collide!).once
          expect(j2).to receive(:validate_package_names_do_not_collide!).once

          assembler.bind_models
        end

        it 'reserves ips' do
          expect(j1).to receive(:reserve_ips).once
          expect(j2).to receive(:reserve_ips).once

          assembler.bind_models
        end

        context 'when the job validation fails' do
          it 'propagates the exception' do
            expect(j1).to receive(:validate_package_names_do_not_collide!).once
            expect(j2).to receive(:validate_package_names_do_not_collide!).once.and_raise('Unable to deploy manifest')

            expect { assembler.bind_models }.to raise_error('Unable to deploy manifest')
          end
        end
      end

      it 'binds unallocated VMs for each job' do
        j1 = instance_double('Bosh::Director::DeploymentPlan::Job')
        j2 = instance_double('Bosh::Director::DeploymentPlan::Job')
        expect(deployment_plan).to receive(:jobs_starting_on_deploy).and_return([j1, j2])

        [j1, j2].each do |job|
          expect(job).to receive(:bind_unallocated_vms).with(no_args).ordered
        end

        assembler.bind_models
      end

      it 'uses DnsBinder to create dns records for deployment' do
        binder = instance_double('Bosh::Director::DeploymentPlan::DnsBinder')
        allow(DeploymentPlan::DnsBinder).to receive(:new).with(deployment_plan).and_return(binder)
        expect(binder).to receive(:bind_deployment).with(no_args)
        assembler.bind_models
      end
    end
  end
end
