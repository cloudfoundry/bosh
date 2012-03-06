# Copyright (c) 2009-2012 VMware, Inc.

require 'blobstore_client'

module Bosh::Agent
  module Message
    class CompilePackage
      attr_accessor :blobstore_id, :package_name, :package_version, :package_sha1
      attr_accessor :compile_base, :install_base
      attr_reader :blobstore_client

      def self.process(args)
        self.new(args).start
      end
      def self.long_running?; true; end

      def initialize(args)
        bsc_provider = Bosh::Agent::Config.blobstore_provider
        bsc_options = Bosh::Agent::Config.blobstore_options
        @blobstore_client = Bosh::Blobstore::Client.create(bsc_provider, bsc_options)
        @blobstore_id, @sha1, @package_name, @package_version, @dependencies = args

        @base_dir = Bosh::Agent::Config.base_dir

        # The maximum amount of disk percentage that can be used during
        # compilation before an error will be thrown.  This is to prevent
        # package compilation throwing arbitrary errors when disk space runs
        # out.
        # @attr [Integer] The max percentage of disk that can be used in
        #     compilation.
        @max_disk_usage_pct = 90
        FileUtils.mkdir_p(File.join(@base_dir, 'data', 'tmp'))

        @log_file = "#{@base_dir}/data/tmp/#{Bosh::Agent::Config.agent_id}"
        @logger = Logger.new(@log_file)
        @compile_base = "#{@base_dir}/data/compile"
        @install_base = "#{@base_dir}/data/packages"
      end

      def start
        # TODO implement sha1 verification
        # TODO propagate errors
        install_dependencies
        get_source_package
        unpack_source_package
        compile
        pack
        result = upload
        return { "result" => result }
      rescue RuntimeError => e
        @logger.warn("%s\n%s" % [e.message, e.backtrace.join("\n")])
        raise Bosh::Agent::MessageHandlerError, e
      ensure
        clear_log_file(@log_file)
        delete_tmp_files
      end

      # Delete the leftover compilation files after a compilation is done. This
      # is done so that the reuse_compilation_vms option does not fill up a VM.
      def delete_tmp_files
        [@compile_base, @install_base].each do |dir|
          if Dir.exists?(dir)
            FileUtils.rm_rf(dir)
          end
        end
      end

      def install_dependencies
        @logger.info("Installing Dependencies")
        @dependencies.each do |pkg_name, pkg|
          @logger.info("Installing depdendency: #{pkg_name} #{pkg.inspect}")

          blobstore_id = pkg['blobstore_id']
          sha1 = pkg['sha1']
          install_dir = File.join(@install_base, pkg_name, pkg['version'])

          Util.unpack_blob(blobstore_id, sha1, install_dir)

          pkg_link_dst = File.join(@base_dir, 'packages', pkg_name)
          FileUtils.ln_sf(install_dir, pkg_link_dst)
        end
      end

      def get_source_package
        compile_tmp = File.join(@compile_base, 'tmp')
        FileUtils.mkdir_p compile_tmp
        @source_file = File.join(compile_tmp, @blobstore_id)
        FileUtils.rm @source_file if File.exist?(@source_file)

        File.open(@source_file, 'w') do |f|
          @blobstore_client.get(@blobstore_id, f)
        end
      end

      def compile_dir
        @compile_dir ||= File.join(@compile_base, @package_name)
      end

      def install_dir
        @install_dir ||= File.join(@install_base, @package_name, @package_version.to_s)
      end

      def unpack_source_package
        FileUtils.rm_rf compile_dir if File.directory?(compile_dir)

        FileUtils.mkdir_p compile_dir
        Dir.chdir(compile_dir) do
          # TODO: error handling
          output = `tar -zxf #{@source_file} 2>&1`
          # stick the output in the blobstore
          unless $?.exitstatus == 0
            raise Bosh::Agent::MessageHandlerError.new(
              "Compile Package Unpack Source Failure (exit code: #{$?.exitstatus})",
              output)
          end
        end
      end

      def disk_info_as_array(path)
        # "Filesystem   1024-blocks     Used Available Capacity  Mounted on\n
        # /dev/disk0s2   195312496 92743676 102312820    48%    /\n"
        df_out = `df -Pk #{path} 2>&1`
        unless $?.exitstatus == 0
          raise Bosh::Agent::MessageHandlerError, "Command 'df -Pk #{path}' " +
              "on compilation VM failed with:\n#{df_out}\nexit code: " +
              "#{$?.exitstatus}"
        end

        # "/dev/disk0s2   195312496 92743568 102312928    48%    /\n"
        df_out = df_out.sub(/[^\/]*/, "")
        # ["/dev/disk0s2", "195312496", "92743568", "102312928", "48%", "/\n"]
        df_out.split(/[ ]+/)
      end

      # Get the amount of total disk (in KBytes).
      # @param [String] path Path that the disk size is being requested for.
      # @return [Integer] The total disk size (in KBytes).
      def disk_total(path)
        disk_info_as_array(path)[1].to_i
      end

      # Get the amount of disk being used (in KBytes).
      # @param [String] path Path that the disk usage is being requested for.
      # @return [Integer] The amount being used (in KBytes).
      def disk_used(path)
        disk_info_as_array(path)[2].to_i
      end

      # Get the percentage of disk that is used on the compilation VM.
      # @param [String] path Path that the disk usage is being requested for.
      # @return [Float] The percentage of disk in use.
      def pct_disk_used(path)
        100 * disk_used(path).to_f / disk_total(path).to_f
      end

      def compile
        FileUtils.rm_rf install_dir if File.directory?(install_dir)
        FileUtils.mkdir_p install_dir
        pct_space_used = pct_disk_used(@compile_base)
        if pct_space_used >= @max_disk_usage_pct
          raise Bosh::Agent::MessageHandlerError,
              "Compile Package Failure. Greater than #{@max_disk_usage_pct}% " +
              "is used (#{pct_space_used}%."
        end
        Dir.chdir(compile_dir) do

          # Prevent these from getting inhereted from the agent
          %w{GEM_HOME BUNDLE_GEMFILE RUBYOPT}.each { |key| ENV.delete(key) }

          # TODO: error handling
          ENV['BOSH_COMPILE_TARGET'] = compile_dir
          ENV['BOSH_INSTALL_TARGET'] = install_dir
          if File.exist?('packaging')
            @logger.info("Compiling #{@package_name} #{@package_version}")
            output = `bash -x packaging 2>&1`
            # stick the output in the blobstore
            unless $?.exitstatus == 0
              raise Bosh::Agent::MessageHandlerError.new(
                "Compile Package Failure (exit code: #{$?.exitstatus})", output)
            end
            @logger.info(output)
          end
        end
      end

      def compiled_package
        File.join(@source_file + ".compiled")
      end

      def pack
        @logger.info("Packing #{@package_name} #{@package_version}")
        Dir.chdir(install_dir) do
          `tar -zcf #{compiled_package} .`
        end
      end

      # Clears the log file after a compilation runs.  This is needed because if
      # reuse_compilation_vms is being used then without clearing the log then
      # the log from each subsequent compilation will include the previous
      # compilation's output.
      # @param [String] log_file Path to the log file.
      def clear_log_file(log_file)
        File.delete(log_file) if File.exists?(log_file)
        @logger = Logger.new(log_file)
      end

      def upload
        compiled_blobstore_id = nil
        File.open(compiled_package, 'r') do |f|
          compiled_blobstore_id = @blobstore_client.create(f)
        end
        compiled_sha1 = Digest::SHA1.hexdigest(File.read(compiled_package))
        compile_log_id = @blobstore_client.create(@log_file)
        @logger.info("Uploaded #{@package_name} #{@package_version} " +
                     "(sha1: #{compiled_sha1}, " +
                     "blobstore_id: #{compiled_blobstore_id})")
        @logger = nil
        { "sha1" => compiled_sha1, "blobstore_id" => compiled_blobstore_id,
          "compile_log_id" => compile_log_id }
      end

    end
  end
end
