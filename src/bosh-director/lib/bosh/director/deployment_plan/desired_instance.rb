module Bosh
  module Director
    module DeploymentPlan
      class DesiredInstance < Struct.new(:instance_group, :deployment, :az, :index)
        def inspect
          "<DesiredInstance az=#{az ? az.name : nil} index=#{index}>"
        end

        def availability_zone
          az&.name
        end
      end
    end
  end
end
