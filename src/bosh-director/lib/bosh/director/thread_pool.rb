module Bosh::Director
  class ThreadPool < Bosh::Common::ThreadPool
    def initialize(**options)
      options[:logger] ||= Config.logger
      super(**options)
    end
  end
end
