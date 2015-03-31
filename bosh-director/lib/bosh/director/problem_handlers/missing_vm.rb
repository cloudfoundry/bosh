# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module ProblemHandlers
    class MissingVM < Base

      register_as :missing_vm
      auto_resolution :recreate_vm

      def initialize(vm_id, data)
        super
        @vm = Models::Vm[vm_id]
      end

      resolution :ignore do
        plan { "Ignore problem" }
        action { }
      end

      resolution :recreate_vm do
        plan { "Recreate VM using last known apply spec" }
        action { recreate_vm(@vm) }
      end

      resolution :delete_vm_reference do
        plan { "Delete VM reference (DANGEROUS!)" }
        action { delete_vm_reference(@vm, skip_cid_check: true) }
      end

      def description
        "VM with cloud ID `#{@vm.cid}' missing."
      end
    end
  end
end