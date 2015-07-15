module Bosh::Director
  module DeploymentPlan
    ##
    # Represents a resource pool VM.
    #
    # It represents a VM until it's officially bound to an instance. It can be
    # reserved for an instance to minimize the number of CPI operations
    # (network & storage) required for the VM to match the instance
    # requirements.
    class Vm
      # @return [Models::Vm] Associated DB model
      attr_accessor :model

      # @return [DeploymentPlan::Instance, nil] Instance that reserved this VM
      attr_accessor :bound_instance

      def clean
        self.model = nil
      end
    end
  end
end
