require "yaml"

module Bosh
  module Cli
    class Config

      class << self
        attr_accessor :colorize
        attr_accessor :output
      end

      def initialize(filename, work_dir = Dir.pwd)
        @filename = File.expand_path(filename)
        @work_dir = work_dir
        
        unless File.exists?(@filename)
          File.open(@filename, "w") { |f| YAML.dump({}, f) }
          File.chmod(0600, @filename)
        end

        @config_file = YAML.load_file(@filename)

        unless @config_file.is_a?(Hash)
          @config_file = { } # Just ignore it if it's malformed
        end
        
      rescue SystemCallError => e
        raise ConfigError, "Cannot read config file: %s" % [ e.message ]        
      end

      def auth
        if @config_file.has_key?("auth") && @config_file["auth"].is_a?(Hash)
          @config_file["auth"][target]
        else
          nil
        end
      end

      def set_credentials(target, username, password)
        @config_file["auth"] ||= { }
        @config_file["auth"][target] = { "username" => username, "password" => password }
      end

      def username
        auth ? auth["username"] : nil
      end

      def password
        auth ? auth["password"] : nil
      end

      [ :target, :deployment ].each do |attr|
        define_method attr do
          read(attr, false)
        end

        define_method "#{attr}=" do |value|
          write_global(attr, value)
        end
      end

      def read(attr, try_local_first = true)
        attr = attr.to_s
        if try_local_first && @config_file[@work_dir].is_a?(Hash) && @config_file[@work_dir].has_key?(attr)
          @config_file[@work_dir][attr]
        else
          @config_file[attr]
        end
      end

      def write(attr, value)
        @config_file[@work_dir] ||= {}
        @config_file[@work_dir][attr.to_s] = value
      end

      def write_global(attr, value)
        @config_file[attr.to_s] = value
      end

      def save
        File.open(@filename, "w") do |f|
          YAML.dump(@config_file, f)
        end
        
      rescue SystemCallError => e
        raise ConfigError, e.message      
      end
      
    end
  end
end
