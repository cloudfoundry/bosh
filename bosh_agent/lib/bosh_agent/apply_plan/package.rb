# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  module ApplyPlan
    class Package

      class InstallationError < StandardError; end

      include ApplyPlan::Helpers

      attr_reader :install_path
      attr_reader :link_path

      def initialize(spec)
        validate_spec(spec)

        @base_dir = Bosh::Agent::Config.base_dir
        @name = spec['name']
        @version = spec['version']
        @checksum = spec['sha1']
        @blobstore_id = spec['blobstore_id']

        @install_path = File.join(@base_dir, 'data', 'packages',
                                  @name, @version)
        @link_path = File.join(@base_dir, 'packages', @name)
      end

      def prepare_for_install
        fetch_bits
      end

      def install_for_job(job)
        fetch_bits_and_symlink
        create_symlink_in_job(job) if job
      rescue SystemCallError => e
        install_failed("System call error: #{e.message}")
      end

      private

      def create_symlink_in_job(job)
        symlink_path = symlink_path_in_job(job)
        FileUtils.mkdir_p(File.dirname(symlink_path))

        Bosh::Agent::Util.create_symlink(@install_path, symlink_path)
      end

      def symlink_path_in_job(job)
        File.join(job.install_path, 'packages', @name)
      end

      def install_failed(message)
        raise InstallationError, 'Failed to install package ' +
                                 "'#{@name}': #{message}"
      end

    end
  end
end
