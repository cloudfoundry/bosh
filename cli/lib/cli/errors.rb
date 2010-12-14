module Bosh
  module Cli

    class CliError < StandardError
      def self.error_code(code = nil)
        define_method(:error_code) { code }
      end
    end

    class UnknownCommand       < CliError; error_code(100); end
    class ConfigError          < CliError; error_code(101); end
    class DirectorMissing      < CliError; error_code(102); end
    class DirectorInaccessible < CliError; error_code(103); end

    class DirectorError        < CliError; error_code(201); end
    class AuthError            < DirectorError; error_code(202); end

    class CacheDirectoryError  < CliError; error_code(301); end
    
  end
end
