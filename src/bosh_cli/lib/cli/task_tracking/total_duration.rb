module Bosh::Cli::TaskTracking
  class TotalDuration
    attr_reader :started_at, :finished_at

    def started_at=(time)
      if !@started_at
        @started_at = Time.at(time) rescue nil
      end
    end

    def finished_at=(time)
      (@finished_at = Time.at(time)) rescue nil
    end

    def duration
      @finished_at - @started_at if duration_known?
    end

    def duration_known?
      !!(@finished_at && @started_at)
    end
  end
end
