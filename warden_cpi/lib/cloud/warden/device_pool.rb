module Bosh::WardenCloud

  class DevicePool
    def initialize(count)
      @mutex = Mutex.new
      @pool = []

      if block_given?
        @pool = count.times.map { |i| yield(i) }
      else
        @pool = count.times.map { |i| i }
      end
    end

    def size
      @mutex.synchronize do
        @pool.size
      end
    end

    def acquire
      @mutex.synchronize do
        @pool.shift
      end
    end

    def release(entry)
      @mutex.synchronize do
        @pool << entry
      end
    end

    def delete_if(&blk)
      @mutex.synchronize do
        @pool.delete_if &blk
      end
    end
  end

end
