require 'spec_helper'

module Bosh::Director
  describe JobRenderer do
    subject(:renderer) { described_class.new(logger) }
    let(:job) { DeploymentPlan::InstanceGroup.new(logger) }

    before do
      job.vm_type = DeploymentPlan::VmType.new({'name' => 'fake-vm-type'})
      job.stemcell = DeploymentPlan::Stemcell.parse({'name' => 'fake-stemcell-name', 'version' => '1.0'})
      job.env = DeploymentPlan::Env.new({})
    end

    let(:template_1) { DeploymentPlan::Job.new(release_version, 'fake-template-1') }
    let(:template_2) { DeploymentPlan::Job.new(release_version, 'fake-template-2') }
    let(:release_version) { DeploymentPlan::ReleaseVersion.new(deployment_model, {'name' => 'fake-release', 'version' => '123'}) }
    let(:deployment_model) { Models::Deployment.make(name: 'fake-deployment') }

    before { allow(Core::Templates::JobInstanceRenderer).to receive(:new).and_return(job_instance_renderer) }
    let(:job_instance_renderer) { instance_double('Bosh::Director::Core::Templates::JobInstanceRenderer') }

    before { allow(Core::Templates::JobTemplateLoader).to receive(:new).and_return(job_template_loader) }
    let(:job_template_loader) { instance_double('Bosh::Director::Core::Templates::JobTemplateLoader') }

    describe '#render_job_instances' do
      let(:instance_plan1) { instance_double('Bosh::Director::DeploymentPlan::InstancePlan') }
      let(:instance_plan2) { instance_double('Bosh::Director::DeploymentPlan::InstancePlan') }

      it 'renders each jobs instance' do
        expect(renderer).to receive(:render_job_instance).with(instance_plan1)
        expect(renderer).to receive(:render_job_instance).with(instance_plan2)
        renderer.render_job_instances([instance_plan1, instance_plan2])
      end
    end

    describe '#render_job_instance' do
      def perform
        renderer.render_job_instance(instance_plan)
      end

      let(:instance_plan) do
        DeploymentPlan::InstancePlan.new(existing_instance: instance_model, desired_instance: DeploymentPlan::DesiredInstance.new(job), instance: instance)
      end

      let(:instance) do
        deployment = instance_double(DeploymentPlan::Planner, model: deployment_model)
        availability_zone = DeploymentPlan::AvailabilityZone.new('z1', {})
        DeploymentPlan::Instance.create_from_job(job, 5, 'started', deployment, {}, availability_zone, logger)
      end

      before do
        allow(instance_plan).to receive_message_chain(:spec, :as_template_spec).and_return({'template' => 'spec'})
        allow(instance_plan).to receive(:templates).and_return([template_1, template_2])
      end

      let(:instance_model) do
        Models::Instance.make(deployment: deployment_model)
      end

      before { allow(job_instance_renderer).to receive(:render).and_return(rendered_job_instance) }
      let(:rendered_job_instance) do
        instance_double('Bosh::Director::Core::Templates::RenderedJobInstance', {
          configuration_hash: configuration_hash,
          template_hashes: { 'job-template-name' => 'rendered-job-template-hash' },
        })
      end

      let(:configuration_hash) { 'fake-content-sha1' }

      it 'correctly initializes JobInstanceRenderer' do
        expect(Core::Templates::JobInstanceRenderer).to receive(:new) do |templates, template_loader|
          expect(templates).to eq([template_1, template_2])
          expect(template_loader).to eq(job_template_loader)
        end.and_return(job_instance_renderer)
        perform
      end

      context 'when instance plan does not have templates' do
        before do
          allow(instance_plan).to receive(:templates).and_return([])
        end

        it 'does not render' do
          expect(job_instance_renderer).to_not receive(:render)
          perform
        end
      end

      it 'renders all templates for all instances of a job' do
        expect(job_instance_renderer).to receive(:render).with({'template' => 'spec'})
        perform
      end

      it 'sets the rendered_job_instance on the instance_plan' do
        expect(job_instance_renderer).to receive(:render).and_return(rendered_job_instance)

        perform

        expect(instance_plan.rendered_templates).to eq(rendered_job_instance)

      end

      it 'updates each instance with configuration and templates hashses' do
        expect(instance).to receive(:configuration_hash=).with(configuration_hash)
        expect(instance).to receive(:template_hashes=).with(rendered_job_instance.template_hashes)
        perform
      end



    end
  end
end
