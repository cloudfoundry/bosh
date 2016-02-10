module Bosh
  module Template
    class EvaluationLink
      attr_reader :nodes
      def initialize(nodes)
        @nodes = nodes
      end
    end
  end
end