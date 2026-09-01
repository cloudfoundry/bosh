module Bosh
  module Director
    module DeploymentPlan
      module SubnetDistribution
        # Default strategy: try candidate subnets in manifest order, so the first
        # subnet fills until its dynamic pool is exhausted before the next is used.
        # This is byte-for-byte the director's historical behavior.
        class FirstFit
          def order(candidates, _reservation)
            candidates
          end

          # first_fit keeps no per-subnet load state, so the allocation/release notifications
          # IpProvider sends every strategy are no-ops here.
          def record_allocation(_network, _subnet); end

          def record_release(_network, _subnet); end
        end
      end
    end
  end
end
