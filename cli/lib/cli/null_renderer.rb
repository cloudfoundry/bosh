# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class NullRenderer < TaskLogRenderer

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
