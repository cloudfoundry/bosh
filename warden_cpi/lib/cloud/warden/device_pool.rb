module Bosh::WardenCloud

  class DevicePool
    def initialize(count)
      @mutex = Mutex.new
      @pool = []

      @pool = count.times.map { |i| block_given? ? yield(i) : i }
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
