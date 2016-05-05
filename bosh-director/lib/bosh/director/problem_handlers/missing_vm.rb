module Bosh::Director
  module ProblemHandlers
    class MissingVM < Base

      register_as :missing_vm
      auto_resolution :recreate_vm_skip_post_start

      def initialize(instance_id, data)
        super
        @instance = Models::Instance.find(id: instance_id)
      end

      resolution :ignore do
        plan { 'Skip for now' }
        action { }
      end

      resolution :recreate_vm_skip_post_start do
        plan { "Recreate VM for '#{@instance}' without waiting for processes to start" }
        action { recreate_vm_skip_post_start(@instance) }
      end

      resolution :recreate_vm do
        plan { "Recreate VM for '#{@instance}' and wait for processes to start" }
        action { recreate_vm(@instance) }
      end

      resolution :delete_vm_reference do
        plan { 'Delete VM reference' }
        action { delete_vm_reference(@instance) }
      end

      def description
        "VM with cloud ID '#{@instance.vm_cid}' missing."
      end
    end
  end
end
