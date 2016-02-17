module Bosh
  module Template
    class EvaluationLink
      attr_reader :instances
      def initialize(instances)
        @instances = instances
      end
    end
  end
end