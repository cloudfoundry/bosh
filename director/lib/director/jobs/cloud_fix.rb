module Bosh::Director
  module Jobs
    class CloudFix < BaseJob
      include CloudCheckHelper
      @queue = :normal

      def initialize(error_id, fix)
        super
        @error_id = error_id
        @fix = fix
      end

      def perform
        error = Models::CloudError[@error_id]
        comp = CloudCheckHelper::COMPONENTS[error.type]

        return if error.nil?
        raise "Invalid error type #{error.type}" if comp.nil?

        comp_obj = comp.send(:new, @logger, self)
        comp_obj.send(@fix, error)
      end
    end
  end
end
