module Bosh::Director
  module Jobs
    class CloudScan < BaseJob
      include CloudCheckHelper
      @queue = :normal

      VALID_OP = ['scan', 'reset']

      def initialize(component, operation)
        super
        @operation = VALID_OP.find { |op| op == operation }
        @component = CloudCheckHelper::COMPONENTS[component]
     end

      def perform
        raise "Invalid operation #{operation}" if @operation.nil?
        raise "Invalid component #{component}" if @component.nil?
        comp_obj = @component.send(:new, @logger, self)
        comp_obj.send(@operation)
      end
    end
  end
end
