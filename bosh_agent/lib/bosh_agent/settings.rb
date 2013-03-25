require 'forwardable'

module Bosh::Agent
  class Settings
    extend Forwardable

    def_delegators :@settings, :fetch, :[]

    # Loads settings specific to the current infrastructure, and then caches
    # the result to disk. If it can't fetch settings, it will fall back to
    # previously cached settings
    def self.load(cache_path=nil)
      settings = new(cache_path || Config.settings_file)
      settings.load
      settings.cache
      settings
    end

    def initialize(file)
      @settings = {}
      @cache_file = file
    end

    def load
      load_from_infrastructure
      cache
    rescue LoadSettingsError => e
      logger.info("failed to load infrastructure settings: #{e.message}")
      load_from_cache
    end

    def cache
      json = Yajl::Encoder.encode(@settings)
      File.open(@cache_file, 'w') do |file|
        file.write(json)
      end
    end

    private

    def load_from_infrastructure
      @settings = Bosh::Agent::Config.infrastructure.load_settings
      logger.info("loaded new infrastructure settings: #{@settings.inspect}")
    end

    def load_from_cache
      json = File.read(@cache_file)
      # perhaps catch json parser errors too and raise as LoadSettingsSerror?
      @settings = Yajl::Parser.new.parse(json)
      logger.info("loaded cached settings: #{@settings.inspect}")
    rescue Errno::ENOENT
      raise LoadSettingsError, "could neither load infrastructure settings " \
        "nor cached settings from: #@cache_file"
    end

    def logger
      Bosh::Agent::Config.logger
    end

  end
end
