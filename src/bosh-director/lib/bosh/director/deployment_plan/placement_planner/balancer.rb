module Bosh
  module Director
    module DeploymentPlan
      module PlacementPlanner
        class Balancer
          def initialize(initial_weight: {}, tie_strategy: lambda {|n| n.min})
            @weight = initial_weight
            @tie_strategy = tie_strategy
          end

          def pop
            return nil if @weight.size == 0
            peek_value = peek
            if peek_value.length != 1
              chosen_value = @tie_strategy.call(peek_value)
            else
              chosen_value = peek_value.first
            end
            @weight[chosen_value]+=1
            chosen_value
          end

          private
          def peek
            @weight.group_by {|_,v| v}
              .min_by {|k,_| k}
              .last.map(&:first)
          end
        end
      end
    end
  end
end

