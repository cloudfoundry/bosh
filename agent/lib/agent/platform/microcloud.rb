# Copyright (c) 2009-2012 VMware, Inc.

require 'agent/platform/ubuntu'

module Bosh::Agent

  class Platform::Microcloud < Platform::Ubuntu

    def setup_networking
      # Micro Cloud Foundry handles its own networking configuration.
    end

  end

end
