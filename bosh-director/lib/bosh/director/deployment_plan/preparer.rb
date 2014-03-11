module Bosh::Director
  module DeploymentPlan
    class Preparer
      def initialize(job, assembler)
        @job = job
        @assembler = assembler
      end

      def prepare
        job.begin_stage('Preparing deployment', 9)

        job.track_and_log('Binding deployment') do
          @assembler.bind_deployment
        end

        job.track_and_log('Binding releases') do
          @assembler.bind_releases
        end

        job.track_and_log('Binding existing deployment') do
          @assembler.bind_existing_deployment
        end

        job.track_and_log('Binding resource pools') do
          @assembler.bind_resource_pools
        end

        job.track_and_log('Binding stemcells') do
          @assembler.bind_stemcells
        end

        job.track_and_log('Binding templates') do
          @assembler.bind_templates
        end

        job.track_and_log('Binding properties') do
          @assembler.bind_properties
        end

        job.track_and_log('Binding unallocated VMs') do
          @assembler.bind_unallocated_vms
        end

        job.track_and_log('Binding instance networks') do
          @assembler.bind_instance_networks
        end
      end

      private

      attr_reader :job
    end
  end
end
