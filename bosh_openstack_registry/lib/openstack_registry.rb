# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module OpenstackRegistry
    autoload :Models, "openstack_registry/models"
  end
end

require "fog"
require "logger"
require "sequel"
require "sinatra/base"
require "thin"
require "yajl"

require "openstack_registry/yaml_helper"

require "openstack_registry/api_controller"
require "openstack_registry/config"
require "openstack_registry/errors"
require "openstack_registry/server_manager"
require "openstack_registry/runner"
require "openstack_registry/version"

Sequel::Model.plugin :validation_helpers