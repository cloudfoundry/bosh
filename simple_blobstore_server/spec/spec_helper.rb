# Copyright (c) 2009-2012 VMware, Inc.

require "rspec"
require "rack/test"

require 'coveralls'
Coveralls.wear!

ENV["RACK_ENV"] = "test"

require "simple_blobstore_server"
