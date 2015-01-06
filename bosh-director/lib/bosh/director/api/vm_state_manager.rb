module Bosh::Director
  module Api
    class VmStateManager
      def fetch_vm_state(username, deployment, format)
        JobQueue.new.enqueue(username, Jobs::VmState, 'retrieve vm-stats', [deployment.id, format])
      end
    end
  end
end
