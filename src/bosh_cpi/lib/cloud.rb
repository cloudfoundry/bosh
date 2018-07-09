# Copyright (c) 2009-2012 VMware, Inc.

module Bosh; module Clouds; end; end

require "forwardable"

require "cloud/config"
require "cloud/errors"
require "cloud_v1"

module Bosh
  # Base class definition for backwards compatibility
  class Cloud
    include Bosh::CloudV1
  end
end
