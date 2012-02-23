# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module Cli

    class CliError < StandardError
      attr_reader :exit_code

      def initialize(*args)
        @exit_code = 1
        super(*args)
      end

      def self.error_code(code = nil)
        define_method(:error_code) { code }
      end

      def self.exit_code(code = nil)
        define_method(:exit_code) { code }
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
    class DeploymentNotFound   < DirectorError; error_code(205); end

    class CliExit              < CliError; error_code(400); end
    class GracefulExit         < CliExit;  error_code(401); end

    class CacheDirectoryError  < CliError; error_code(301); end

    class InvalidPackage       < CliError; error_code(500); end
    class InvalidJob           < CliError; error_code(501); end
    class InvalidRelease       < CliError; error_code(503); end
    class MissingDependency    < CliError; error_code(504); end
    class CircularDependency   < CliError; error_code(505); end
    class InvalidIndex         < CliError; error_code(506); end
    class BlobstoreError       < CliError; error_code(507); end
    class PackagingError       < CliError; error_code(508); end
    class UndefinedProperty    < CliError; error_code(509); end
    class MalformedManifest    < CliError; error_code(511); end
    class MissingTarget        < CliError; error_code(512); end
  end
end
