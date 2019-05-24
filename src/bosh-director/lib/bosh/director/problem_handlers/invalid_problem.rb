module Bosh::Director
  module ProblemHandlers
    class InvalidProblem < Base

      register_as :invalid_problem
      auto_resolution :close

      def initialize(resource_id, data)
        super
        @resource_id = resource_id
        @error = data["error"] || "unknown error"
        @original_type = data["original_type"] || "unknown_type"
      end

      def description
        "Problem (#{@original_type} #{@resource_id}) is no longer valid: #{@error}"
      end

      def instance_problem?
        false
      end

      resolution :close do
        plan { "Close problem" }
        action { }
      end

    end
  end
end
