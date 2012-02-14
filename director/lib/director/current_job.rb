module Bosh::Director
  class CurrentJob

    class << self
      attr_accessor :job

      def init(job = nil)
        @job = job
      end

      def clear
        @job = nil
      end

      def job_cancelled?
        @job.task_checkpoint if @job
      end
    end
  end
end
