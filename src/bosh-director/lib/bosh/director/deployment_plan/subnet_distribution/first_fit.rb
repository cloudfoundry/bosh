module Bosh
  module Director
    module DeploymentPlan
      module SubnetDistribution
        # Default strategy: try candidate subnets in manifest order, so the first
        # subnet fills until its dynamic pool is exhausted before the next is used.
        # This is byte-for-byte the director's historical behavior.
        class FirstFit
          # Returns candidates unchanged, so each subnet fills in manifest order before the next.
          def order(candidates, _reservation)
            candidates
          end

          # first_fit keeps no load state, so these notifications are no-ops.
          def record_allocation(_network, _subnet); end

          # See #record_allocation.
          def record_release(_network, _subnet); end
        end
      end
    end
  end
end
