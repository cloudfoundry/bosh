# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class VmStateManager
      def fetch_vm_state(user, deployment, format)
        JobQueue.new.enqueue(user, Jobs::VmState, 'retrieve vm-stats', [deployment.id, format])
      end
    end
  end
end
