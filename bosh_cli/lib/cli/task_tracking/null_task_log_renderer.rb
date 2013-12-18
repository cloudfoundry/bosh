module Bosh::Cli::TaskTracking
  class NullTaskLogRenderer < TaskLogRenderer
    def initialize
    end

    def add_output(output)
    end

    def refresh
    end

    def finish(state)
    end
  end
end
