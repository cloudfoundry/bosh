module Bosh
  module Director
    module DeploymentPlan
      class DesiredInstance < Struct.new(:instance_group, :deployment, :az, :index)
        def inspect
          "<DesiredInstance az=#{self.az ? self.az.name : nil} index=#{self.index}>"
        end

        def availability_zone
          self.az.name unless self.az.nil?
        end
      end
    end
  end
end
