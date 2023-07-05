module Bosh::Director
  module ProblemHandlers
    class MissingVM < Base

      register_as :missing_vm
      auto_resolution :recreate_vm_without_wait

      def initialize(instance_id, data)
        super
        @instance = Models::Instance.find(id: instance_id)
      end

      resolution :ignore do
        plan { 'Skip for now' }
        action { }
      end

      resolution :recreate_vm_without_wait do
        plan { 'Recreate VM without waiting for processes to start' }
        action { recreate_vm_without_wait(@instance) }
      end

      resolution :recreate_vm do
        plan { 'Recreate VM and wait for processes to start' }
        action { recreate_vm(@instance) }
      end

      resolution :delete_vm_reference do
        plan { 'Delete VM reference' }
        action { delete_vm_reference(@instance) }
      end

      def description
        with_vm_cid = if @instance.vm_cid
          " with cloud ID '#{@instance.vm_cid}'"
        else
          ''
        end
        "VM for '#{@instance}'#{with_vm_cid} missing."
      end

      def instance_problem?
        true
      end

      def instance_group
        @instance.job || 'unknown job'
      end
    end
  end
end
