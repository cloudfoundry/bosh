# Copyright (c) 2009-2012 VMware, Inc.

require "rspec"
require "rack/test"

ENV["RACK_ENV"] = "test"

require 'coveralls'
Coveralls.wear!

require "simple_blobstore_server"
