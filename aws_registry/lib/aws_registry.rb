# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module AwsRegistry
    autoload :Models, "aws_registry/models"
  end
end

require "logger"
require "sequel"
require "sinatra/base"
require "thin"
require "yajl"

require "aws_registry/yaml_helper"

require "aws_registry/api_controller"
require "aws_registry/config"
require "aws_registry/errors"
require "aws_registry/runner"
require "aws_registry/version"

Sequel::Model.plugin :validation_helpers

