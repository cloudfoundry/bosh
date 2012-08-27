# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  module ApplyPlan
    class Package

      class InstallationError < StandardError; end

      attr_reader :install_path
      attr_reader :link_path

      def initialize(spec)
        unless spec.is_a?(Hash)
          raise ArgumentError, "Invalid package spec, " +
                               "Hash expected, #{spec.class} given"
        end

        %w(name version sha1 blobstore_id).each do |key|
          if spec[key].nil?
            raise ArgumentError, "Invalid spec, #{key} is missing"
          end
        end

        @base_dir = Bosh::Agent::Config.base_dir
        @name = spec["name"]
        @version = spec["version"]
        @checksum = spec["sha1"]
        @blobstore_id = spec["blobstore_id"]

        @install_path = File.join(@base_dir, "data", "packages",
                                  @name, @version)
        @link_path = File.join(@base_dir, "packages", @name)
      end

      def install_for_job(job)
        unless @installed_for_sys
          fetch_package
          @installed_for_sys = true
        end
        create_symlink_in_job(job) if job
      rescue SystemCallError => e
        install_failed("System call error: #{e.message}")
      end

      private

      def fetch_package
        FileUtils.mkdir_p(File.dirname(@install_path))
        FileUtils.mkdir_p(File.dirname(@link_path))

        Bosh::Agent::Util.unpack_blob(@blobstore_id, @checksum, @install_path)
        Bosh::Agent::Util.create_symlink(@install_path, @link_path)
      end

      def create_symlink_in_job(job)
        symlink_path = symlink_path_in_job(job)
        FileUtils.mkdir_p(File.dirname(symlink_path))

        Bosh::Agent::Util.create_symlink(@install_path, symlink_path)
      end

      def symlink_path_in_job(job)
        File.join(job.install_path, "packages", @name)
      end

      def install_failed(message)
        raise InstallationError, "Failed to install package " +
                                 "'#{@name}': #{message}"
      end

    end
  end
end
