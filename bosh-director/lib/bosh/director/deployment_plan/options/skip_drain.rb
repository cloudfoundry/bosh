module Bosh::Director
  module DeploymentPlan
    class SkipDrain
      def initialize(param)
        @jobs = []
        @all = false

        if param == '*'
          @all = true
        elsif param.is_a?(String) && !param.empty?
          @jobs = param.split(',')
        end
      end

      def for_job(job_name)
        @all || @jobs.include?(job_name)
      end
    end
  end
end
