module Bosh::Director
  module DeploymentPlan
    module Steps
      class ElectActiveVmStep
        def perform(report)
          vm = report.vm
          vm.instance.active_vm = vm
        end
      end
    end
  end
end
