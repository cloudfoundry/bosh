module Bosh::Director
  module Api
    class VariablesManager

       def get_variables_for_deployment(deployment)
        result_set = []

        Models::VariableMapping.where(deployment_id: deployment.id).each do |variable_mapping|
          variable_set = {'id' => variable_mapping[:variable_id], 'name' => variable_mapping[:variable_name]}
          unless result_set.include? variable_set
            result_set << variable_set
          end
        end

        result_set
       end

    end
  end
end