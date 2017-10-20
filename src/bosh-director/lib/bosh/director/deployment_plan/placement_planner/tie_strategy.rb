module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        module TieStrategy
          class MinWins
            def initialize(preferred_az_names)
              @preferred_az_names = preferred_az_names
            end

            def call(azs)
              azs.find { |az|
                @preferred_az_names.any? {|i| i == az.name }
              } || azs.min
            end
          end

          class RandomWins
            def initialize(preferred_az_names, random: Random)
              @preferred_az_names = preferred_az_names
              @random = random
            end

            def call(azs)
              azs.find { |az|
                @preferred_az_names.any? {|i| i == az.name }
              } || azs.sample(random: @random)
            end
          end
        end
      end
    end
  end
end

