# Copyright (c) 2009-2013 VMware, Inc.
# Copyright (c) 2012 Piston Cloud Computing, Inc.

module Bosh
  module OpenStackCloud; end
end

require "fog"
require "httpclient"
require "json"
require "pp"
require "set"
require "tmpdir"
require "securerandom"
require "yajl"

require "common/thread_pool"
require "common/thread_formatter"

require "cloud"
require "cloud/openstack/helpers"
require "cloud/openstack/cloud"
require "cloud/openstack/connection"
require "cloud/openstack/registry_client"
require "cloud/openstack/tag_manager"
require "cloud/openstack/version"

require "cloud/openstack/network_configurator"
require "cloud/openstack/network"
require "cloud/openstack/dynamic_network"
require "cloud/openstack/manual_network"
require "cloud/openstack/vip_network"

module Bosh
  module Clouds
    OpenStack = Bosh::OpenStackCloud::Cloud
    Openstack = OpenStack # Alias needed for Bosh::Clouds::Provider.create method
  end
end
