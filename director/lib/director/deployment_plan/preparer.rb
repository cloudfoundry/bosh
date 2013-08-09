module Bosh::Director
  module DeploymentPlan
    class Preparer
      def initialize(job, compiler)
        @job = job
        @deployment_plan_compiler = compiler
      end

      def prepare
        job.track_and_log('Binding deployment') do
          @deployment_plan_compiler.bind_deployment
        end

        job.track_and_log('Binding releases') do
          @deployment_plan_compiler.bind_releases
        end

        job.track_and_log('Binding existing deployment') do
          @deployment_plan_compiler.bind_existing_deployment
        end

        job.track_and_log('Binding resource pools') do
          @deployment_plan_compiler.bind_resource_pools
        end

        job.track_and_log('Binding stemcells') do
          @deployment_plan_compiler.bind_stemcells
        end

        job.track_and_log('Binding templates') do
          @deployment_plan_compiler.bind_templates
        end

        job.track_and_log('Binding properties') do
          @deployment_plan_compiler.bind_properties
        end

        job.track_and_log('Binding unallocated VMs') do
          @deployment_plan_compiler.bind_unallocated_vms
        end

        job.track_and_log('Binding instance networks') do
          @deployment_plan_compiler.bind_instance_networks
        end
      end

      private

      attr_reader :job
    end
  end
end
