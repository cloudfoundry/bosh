require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    module Steps
      describe RenderInstanceJobTemplatesStep do
        subject(:step) { RenderInstanceJobTemplatesStep.new(instance_plan, blob_cache: blob_cache, dns_encoder: dns_encoder) }

        let(:blob_cache) { instance_double(Core::Templates::TemplateBlobCache) }
        let(:dns_encoder) { instance_double(DnsEncoder) }
        let(:deployment_instance) { instance_double(Instance, compilation?: false) }
        let(:instance_plan) { instance_double(InstancePlan, instance: deployment_instance, spec: spec) }
        let(:spec) { instance_double(InstanceSpec, as_template_spec: {'networks' => 'template-spec'}) }

        describe '#perform' do
          context 'with a non-compilation instance' do
            it 'logs to debug log and uses JobRenderer to render job templates' do
              expect(logger).to receive(:debug).with('Re-rendering templates with updated dynamic networks: template-spec')
              expect(JobRenderer).to receive(:render_job_instances_with_cache).with([instance_plan], blob_cache, dns_encoder, logger)

              step.perform
            end
          end

          context 'with a compilation vm' do
            before { allow(deployment_instance).to receive(:compilation?).and_return(true) }

            it 'logs that it is skipping due to being a compilation vm' do
              expect(logger).to receive(:debug).with('Skipping job template rendering, as instance is a compilation instance')
              expect(JobRenderer).to_not receive(:render_job_instances_with_cache)

              step.perform
            end
          end
        end
      end
    end
  end
end
