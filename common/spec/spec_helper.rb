# Copyright (c) 2009-2012 VMware, Inc.

require "rspec"

def asset(file)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", file))
end
