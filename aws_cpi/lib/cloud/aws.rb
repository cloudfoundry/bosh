# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module AWSCloud; end
end

require "aws-sdk"
require "httpclient"
require "pp"
require "set"
require "uuidtools"
require "yajl"

require "common/thread_pool"
require "common/thread_formatter"

require "cloud"
require "cloud/aws/helpers"
require "cloud/aws/cloud"
require "cloud/aws/registry_client"
require "cloud/aws/version"

require "cloud/aws/network_configurator"
require "cloud/aws/network"
require "cloud/aws/dynamic_network"
require "cloud/aws/vip_network"

module Bosh
  module Clouds
    Aws = Bosh::AWSCloud::Cloud
  end
end
