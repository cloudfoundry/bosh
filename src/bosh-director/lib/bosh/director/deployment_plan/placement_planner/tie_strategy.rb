module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        module TieStrategy
          class MinWins
            def call(azs)
              azs.min
            end
          end

          class RandomWins
            def initialize(random: Random)
              @random = random
            end

            def call(azs)
              azs.sample(random: @random)
            end
          end
        end
      end
    end
  end
end

