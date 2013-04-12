# Copyright (c) 2009-2012 VMware, Inc.

require "rspec"
require "cloud"
require "logger"

# add the spec/lib to load path so we can find the dummy provider
$:.unshift(File.expand_path('../lib', __FILE__))

class CloudSpecConfig

  attr_accessor :db, :uuid

  def logger
    if @logger.nil?
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::ERROR
    end
    @logger
  end

  def uuid
    @uuid ||= self.class.name
  end
end

Bosh::Clouds::Config.configure(CloudSpecConfig.new)
