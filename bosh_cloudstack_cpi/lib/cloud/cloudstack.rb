# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh
  module CloudStackCloud; end
end

require "fog"
require "httpclient"
require "json"
require "pp"
require "set"
require "tmpdir"
require "securerandom"
require "yajl"

require "common/exec"
require "common/thread_pool"
require "common/thread_formatter"

require 'bosh/registry/client'
require "cloud"
require "cloud/cloudstack/fog_patch"
require "cloud/cloudstack/helpers"
require "cloud/cloudstack/cloud"
require "cloud/cloudstack/stemcell_creator"
require "cloud/cloudstack/tag_manager"
require "cloud/cloudstack/version"

require "cloud/cloudstack/network_configurator"
require "cloud/cloudstack/network"
require "cloud/cloudstack/dynamic_network"
require "cloud/cloudstack/vip_network"

module Bosh
  module Clouds
    CloudStack = Bosh::CloudStackCloud::Cloud
    Cloudstack = CloudStack # Alias needed for Bosh::Clouds::Provider.create method
  end
end
