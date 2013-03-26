# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class VmStateManager
      include TaskHelper

      def fetch_vm_state(user, deployment, format)
        task = create_task(user, :vms, "retrieve vm-stats")
        Resque.enqueue(Jobs::VmState, task.id, deployment.id, format)
        task
      end
    end
  end
end
