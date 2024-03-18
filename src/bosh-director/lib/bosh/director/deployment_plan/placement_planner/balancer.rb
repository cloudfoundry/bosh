module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class Balancer
          def initialize(initial_weight: {}, tie_strategy:, preferred:)
            @weight = initial_weight
            @tie_strategy = tie_strategy
            @preferred = preferred
          end

          def pop
            return nil if @weight.size == 0
            peek_value = peek

            if peek_value.length != 1
              choose(peek_value.find {|k| @preferred.include?(k.name) } || @tie_strategy.call(peek_value))
            else
              choose(peek_value.first)
            end
          end

          private
          def peek
            @weight.group_by {|_,v| v}
              .min_by {|k,_| k}
              .last.map(&:first)
          end

          def choose(chosen_value)
            @weight[chosen_value]+=1
            if (preferred_chosen_index = @preferred.find_index { |v| v == chosen_value.name })
              @preferred.delete_at(preferred_chosen_index)
            end
            chosen_value
          end
        end
      end
    end
  end
end

