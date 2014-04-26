module VSphereCloud
  module RetryBlock
    def retry_block(num = 2)
      result = nil
      num.times do |i|
        begin
          result = yield
          break
        rescue RuntimeError
          raise if i + 1 >= num
        end
      end
      result
    end
  end
end
