module Bosh::Director
  module DeploymentPlan
    class Link
      attr_reader :name

      def initialize(name, source)
        @name = name
        @source = source
      end

      def spec
        {
          'nodes' => @source.instances.map do |instance|
            {
              'name' => @source.name,
              'index' => instance.index
            }
          end
        }
      end
    end
  end
end
