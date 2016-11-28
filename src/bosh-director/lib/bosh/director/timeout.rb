module Bosh::Director
  class Timeout
    def initialize(seconds_till_timeout)
      @end_time = Time.now + seconds_till_timeout
    end

    def timed_out?
      Time.now > @end_time
    end
  end
end
