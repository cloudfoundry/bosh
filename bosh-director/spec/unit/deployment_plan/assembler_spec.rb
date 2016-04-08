require 'spec_helper'

module Bosh::Director
  describe DeploymentPlan::Assembler do
    subject(:assembler) { DeploymentPlan::Assembler.new(deployment_plan, stemcell_manager, dns_manager, cloud, logger) }
    let(:deployment_plan) { instance_double('Bosh::Director::DeploymentPlan::Planner',
      name: 'simple',
      skip_drain: BD::DeploymentPlan::AlwaysSkipDrain.new,
      recreate: false,
      model: BD::Models::Deployment.make
    ) }
    let(:stemcell_manager) { nil }
    let(:dns_manager) { DnsManagerProvider.create }
    let(:event_log) { Config.event_log }

    let(:cloud) { instance_double('Bosh::Cloud') }

    describe '#bind_models' do
      let(:instance_model) { Models::Instance.make(job: 'old-name') }
      let(:job) { instance_double(DeploymentPlan::Job) }

      before do
        allow(deployment_plan).to receive(:instance_models).and_return([instance_model])
        allow(deployment_plan).to receive(:jobs).and_return([])
        allow(deployment_plan).to receive(:existing_instances).and_return([])
        allow(deployment_plan).to receive(:candidate_existing_instances).and_return([])
        allow(deployment_plan).to receive(:resource_pools).and_return(nil)
        allow(deployment_plan).to receive(:stemcells).and_return({})
        allow(deployment_plan).to receive(:jobs_starting_on_deploy).and_return([])
        allow(deployment_plan).to receive(:releases).and_return([])
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

      describe 'migrate_legacy_dns_records' do
        it 'migrates legacy dns records' do
          expect(dns_manager).to receive(:migrate_legacy_records).with(instance_model)
          assembler.bind_models
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
          job = DeploymentPlan::Job.new(logger)
          template_model = Models::Template.make(name: template_name)
          release_version = instance_double(DeploymentPlan::ReleaseVersion)
          allow(release_version).to receive(:get_template_model_by_name).and_return(template_model)
          template = DeploymentPlan::Template.new(release_version, template_name)
          template.bind_models
          job.templates = [template]
          allow(job).to receive(:validate_package_names_do_not_collide!)
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

        context 'when the job validation fails' do
          it 'propagates the exception' do
            expect(j1).to receive(:validate_package_names_do_not_collide!).once
            expect(j2).to receive(:validate_package_names_do_not_collide!).once.and_raise('Unable to deploy manifest')

            expect { assembler.bind_models }.to raise_error('Unable to deploy manifest')
          end
        end
      end

      it 'configures dns' do
        expect(dns_manager).to receive(:configure_nameserver)
        assembler.bind_models
      end
    end
  end
end
