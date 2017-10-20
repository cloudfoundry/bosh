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
                i = @preferred_az_names.find_index {|az_name| az_name == az.name }
                @preferred_az_names.delete_at(i) if i
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
                i = @preferred_az_names.find_index {|az_name| az_name == az.name }
                @preferred_az_names.delete_at(i) if i
              } || azs.sample(random: @random)
            end
          end
        end
      end
    end
  end
end

