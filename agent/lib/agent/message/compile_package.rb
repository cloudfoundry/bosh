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

      def initialize(args)
        bsc_options = Bosh::Agent::Config.blobstore_options
        @blobstore_client = Bosh::Blobstore::SimpleBlobstoreClient.new(bsc_options)
        @blobstore_id, @sha1, @package_name, @package_version = args

        @compile_base = "/var/b29/data/compile"
        @install_base = "/var/b29/data/packages"
      end

      def start
        # TODO make long running
        # TODO implement sha1 verification
        # TODO propagate erros
        begin
          get_source_package
          unpack_source_package
          compile
        rescue RuntimeError => e
          # TODO: propagate errors
          # TODO: logging
        end
      end

      def get_source_package
        compile_tmp = File.join(@compile_base, 'tmp')
        FileUtils.mkdir_p compile_tmp
        @source_file = File.join(compile_tmp, @blobstore_id)
        FileUtils.rm @source_file if File.exist?(@source_file)

        File.open(@source_file, 'w') do |f|
          f.write(@blobstore_client.get(@blobstore_id))
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
          `tar -zxf #{@source_file}`
        end
      end

      def compile
        FileUtils.rm_rf install_dir if File.directory?(install_dir)
        FileUtils.mkdir_p install_dir

        Dir.chdir(compile_dir) do
          # TODO: error handling
          ENV['BOSH_COMPILE_TARGET'] = compile_dir
          ENV['BOSH_INSTALL_TARGET'] = install_dir
          if File.exist?('packaging')
            puts `bash packaging`
          end
        end
      end

      def compiled_package
        File.join(@source_file + ".compiled")
      end

      def pack
        Dir.chdir(install_dir) do
          `tar -zcf #{compiled_package} .`
        end
      end

      def compiled_package
        File.open(compiled_package, 'r') do |f|
          @blobstore_client.create(f)
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
          `tar -zxf #{@source_file}`
        end
      end

      def compile
        FileUtils.rm_rf install_dir if File.directory?(install_dir)
        FileUtils.mkdir_p install_dir

        Dir.chdir(compile_dir) do
          # TODO: error handling
          ENV['BOSH_COMPILE_TARGET'] = compile_dir
          ENV['BOSH_INSTALL_TARGET'] = install_dir
          if File.exist?('packaging')
            `bash packaging`
          end
        end
      end

      def compiled_package
        File.join(@source_file + ".compiled")
      end

      def pack
        Dir.chdir(install_dir) do
          `tar -zcf #{compiled_package} .`
        end
      end

      def upload
        File.open(compiled_package, 'r') do |f|
          @blobstore_client.create(f)
        end
      end

    end
  end
end
