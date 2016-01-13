$: << File.expand_path('..', __FILE__)

require 'rspec'
require 'rspec/its'
require 'tempfile'
require 'fileutils'
require 'tmpdir'
require 'digest/sha1'
require 'machinist/sequel'
require 'psych'
require_relative '../../bosh-director/lib/bosh/director/config'

module DBSpecHelper
  class << self
    attr_reader :db

    def init
      Bosh::Director::Config.patch_sqlite

      @temp_dir = Bosh::Director::Config.generate_temp_dir
      @director_migrations = File.expand_path('../../migrations/director', __FILE__)

      connect_database(@temp_dir)
    end

    def connect_database(path)
      db = ENV['DB_CONNECTION'] || "sqlite://#{File.join(path, "director.db")}"

      db_opts = {:max_connections => 32, :pool_timeout => 10}

      @db = Sequel.connect(db, db_opts)
    end

    def reset_database
      if @db
        @db.disconnect
        @db = nil
      end

      if @db_dir && File.directory?(@db_dir)
        FileUtils.rm_rf(@db_dir)
      end

      @db_dir = Dir.mktmpdir(nil, @temp_dir)
      FileUtils.cp(Dir.glob(File.join(@temp_dir, "*.db")), @db_dir)

      connect_database(@db_dir)
    end
  end
end

DBSpecHelper.init
