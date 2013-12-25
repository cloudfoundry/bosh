module Bosh::Director
  module Api
    class VmStateManager
      def fetch_vm_state(user, deployment, format)
        JobQueue.new.enqueue(user, Jobs::VmState, 'retrieve vm-stats', [deployment.id, format])
      end
    end
  end
end
