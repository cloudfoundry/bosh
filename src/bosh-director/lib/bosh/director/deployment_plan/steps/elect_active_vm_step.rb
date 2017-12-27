module Bosh::Director
  module DeploymentPlan
    module Steps
      class ElectActiveVmStep
        def initialize(vm)
          @vm = vm
        end

        def perform
          @vm.instance.active_vm = @vm
        end
      end
    end
  end
end
