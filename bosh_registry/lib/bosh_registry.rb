# Copyright (c) 2009-2013 VMware, Inc.

module Bosh
  module Registry
    autoload :Models, "bosh_registry/models"
  end
end

require "aws-sdk"
require "fog"
require "logger"
require "sequel"
require "sinatra/base"
require "thin"
require "yajl"

require "bosh_registry/yaml_helper"

require "bosh_registry/api_controller"
require "bosh_registry/config"
require "bosh_registry/errors"
require "bosh_registry/instance_manager"
require "bosh_registry/runner"
require "bosh_registry/version"

Sequel::Model.plugin :validation_helpers