# Copyright (c) 2009-2012 VMware, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"

require "sequel"
require "sequel/adapters/sqlite"

Sequel.extension :migration
db = Sequel.sqlite(':memory:')
migration = File.expand_path("../../db/migrations/vsphere_cpi", __FILE__)
Sequel::TimestampMigrator.new(db, migration, :table => "vsphere_cpi_schema").run

require 'cloud'
require 'cloud/vsphere'

class VSphereSpecConfig
  attr_accessor :db, :logger, :uuid
end

config = VSphereSpecConfig.new
config.db = db
config.logger = Logger.new(STDOUT)
config.logger.level = Logger::ERROR

Bosh::Clouds::Config.configure(config)
