# Copyright (c) 2009-2012 VMware, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"
require 'cloud'

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
