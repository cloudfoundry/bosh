module Bosh::Director
  module Api
    class VariablesManager
      def get_variables_for_deployment(deployment)
        result_set = []
        variable_set_ids = []

        variable_set_ids << deployment[:variables_set_id]
        variable_set_ids << deployment[:successful_variables_set_id]

        Models::VariableMapping.where(set_id: variable_set_ids).each do |variable_mapping|
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