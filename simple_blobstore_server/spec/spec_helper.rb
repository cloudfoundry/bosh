# Copyright (c) 2009-2012 VMware, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
Bundler.setup(:default, :test)

require "rspec"
require "rack/test"

$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

ENV["RACK_ENV"] = "test"

require "simple_blobstore_server"
