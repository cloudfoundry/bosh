# Copyright (c) 2009-2012 VMware, Inc.

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

if ENV["SIMPLECOV"]
  require "simplecov"
  require "simplecov-rcov"

  SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
  SimpleCov.root(ENV["SIMPLECOV_ROOT"])
  if ENV["SIMPLECOV_EXCLUDE"]
    ENV["SIMPLECOV_EXCLUDE"].split(",").each do |filter|
      SimpleCov.add_filter(filter.strip)
    end
  end
  SimpleCov.coverage_dir(ENV["SIMPLECOV_DIR"]) if ENV["SIMPLECOV_DIR"]
  SimpleCov.start
end
