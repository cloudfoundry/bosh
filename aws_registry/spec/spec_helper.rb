# Copyright (c) 2009-2012 VMware, Inc.

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "fileutils"
require "logger"
require "tmpdir"

require "rspec"

module SpecHelper
  class << self
    attr_accessor :logger
    attr_accessor :temp_dir

    def init
      ENV["RACK_ENV"] = "test"
      configure_logging
      configure_temp_dir

      require "aws_registry"
      init_database
    end

    def configure_logging
      if ENV["DEBUG"]
        @logger = Logger.new(STDOUT)
      else
        path = File.expand_path("../spec.log", __FILE__)
        log_file = File.open(path, "w")
        log_file.sync = true
        @logger = Logger.new(log_file)
      end
    end

    def configure_temp_dir
      @temp_dir = Dir.mktmpdir
      ENV["TMPDIR"] = @temp_dir
      FileUtils.mkdir_p(@temp_dir)
      at_exit { FileUtils.rm_rf(@temp_dir) }
    end

    def init_database
      @migrations_dir = File.expand_path("../../db/migrations", __FILE__)

      Sequel.extension :migration

      @db = Sequel.sqlite(:database => nil, :max_connections => 32, :pool_timeout => 10)
      @db.loggers << @logger
      Bosh::AwsRegistry.db = @db

      run_migrations
    end

    def run_migrations
      Sequel::Migrator.apply(@db, @migrations_dir, nil)
    end

    def reset_database
      @db.execute("PRAGMA foreign_keys = OFF")
      @db.tables.each do |table|
        @db.drop_table(table)
      end
      @db.execute("PRAGMA foreign_keys = ON")
    end

    def reset
      reset_database
      run_migrations

      Bosh::AwsRegistry.db = @db
      Bosh::AwsRegistry.logger = @logger
    end
  end
end

SpecHelper.init

RSpec.configure do |rspec|
  rspec.before(:each) do
    SpecHelper.reset
  end
end
