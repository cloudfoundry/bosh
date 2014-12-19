require 'monitor'

module Bosh::Cli
  class Semaphore
    def initialize(maxval = nil)
      maxval = nil if maxval and maxval <= 0
      @max   = maxval || -1
      @count = 0
      @mon   = Monitor.new
      @dwait = @mon.new_cond
      @uwait = @mon.new_cond
    end

    def count; @mon.synchronize { @count } end

    def wait(number = 1)
      if (number > 1)
        number.times { up!(1) }
        count
      else
        @mon.synchronize do
          @uwait.wait while @max > 0 and @count == @max
          @dwait.signal if @count == 0
          @count += 1
        end
      end
    end

    def signal(number = 1)
      if (number > 1)
        number.times { down!(1) }
        count
      else
        @mon.synchronize do
          @dwait.wait while @count == 0
          @uwait.signal if @count == @max
          @count -= 1
        end
      end
    end
  end
end
