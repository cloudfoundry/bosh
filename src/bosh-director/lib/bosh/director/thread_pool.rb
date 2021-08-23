module Bosh::Director
  class ThreadPool < Bosh::ThreadPool
    def initialize(**options)
      options[:logger] ||= Config.logger
      super(**options)
    end
  end
end
