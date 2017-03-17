module Bosh
  module Registry
    autoload :Models, "bosh/registry/models"
  end
end

require "aws-sdk"
require "fog/openstack"
require "logger"
require "sequel"
require "sinatra/base"
require "thin"
require "yajl"

require "bosh/registry/yaml_helper"

require "bosh/registry/api_controller"
require "bosh/registry/config"
require "bosh/registry/errors"
require "bosh/registry/instance_manager"
require "bosh/registry/instance_manager/aws_credentials_provider"
require "bosh/registry/runner"
require "bosh/registry/version"

Sequel::Model.plugin :validation_helpers