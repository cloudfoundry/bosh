require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require "rack/test"

ENV["RACK_ENV"] = "test"

require "simple_blobstore_server"
