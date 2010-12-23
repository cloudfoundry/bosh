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
    class MissingTask          < DirectorError; error_code(203); end
    class TaskTrackError       < DirectorError; error_code(204); end    

    class CliExit              < CliError; error_code(400); end
    class GracefulExit         < CliExit;  error_code(401); end

    class CacheDirectoryError  < CliError; error_code(301); end

    class InvalidPackage       < CliError; error_code(500); end
    class InvalidJob           < CliError; error_code(501); end
    class InvalidRelease       < CliError; error_code(503); end

    class MissingDependency    < CliError; error_code(504); end
    class CircularDependency   < CliError; error_code(505); end

  end
end
