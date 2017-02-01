module Bosh::Director
  module Api
    class VariablesManager

       def get_variables_for_deployment(deployment)
          Models::VariableMapping.where(deployment_id: deployment.id)
       end
    end
  end
end
