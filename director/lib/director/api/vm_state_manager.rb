# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class VmStateManager
      include TaskHelper

      def fetch_vm_state(user, deployment_name)
        if deployment_name.nil?
          raise InvalidRequest.new("deployment parameter is required")
        end

        deployment = Models::Deployment.find(:name => deployment_name)
        raise DeploymentNotFound.new(deployment_name) if deployment.nil?

        task = create_task(user, :vms, "retrieve vm-stats")
        Resque.enqueue(Jobs::VmState, task.id, deployment.id)
        task
      end
    end
  end
end
