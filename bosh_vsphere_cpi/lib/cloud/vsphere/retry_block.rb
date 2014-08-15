module VSphereCloud
  module RetryBlock
    class TimeoutError < RuntimeError; end

    def retry_block(num = 2)
      result = nil
      num.times do |i|
        begin
          result = yield
          break
        rescue
          raise if i + 1 >= num
        end
      end
      result
    end

    def retry_with_timeout(timeout)
      deadline = Time.now.to_i + timeout
      begin
        yield
      rescue
        if deadline - Time.now.to_i > 0
          sleep 0.5
          retry
        end
        raise TimeoutError
      end
    end
  end
end
