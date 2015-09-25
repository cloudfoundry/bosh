module Bosh
  module Director
    module DeploymentPlan
      class DesiredInstance < Struct.new(:job, :virtual_state, :deployment, :az, :is_existing, :index, :bootstrap)

        def inspect
          "<az=#{self.az} index=#{self.index}>"
        end

        def bootstrap?
          self.bootstrap
        end

        def state
          # Expanding virtual states
          case virtual_state
            when 'recreate'
              'started'
            when 'restart'
              'started'
            else
              virtual_state
          end
        end

        def mark_as_bootstrap
          self.bootstrap = true
        end

        def availability_zone
          self.az.name unless self.az.nil?
        end
      end
    end
  end
end
