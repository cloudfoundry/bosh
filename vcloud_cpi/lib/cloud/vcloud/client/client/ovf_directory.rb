module VCloudCloud
  module Client
    class OVFDirectory
      def initialize(directory)
        raise CloudError, "Requires string-like object for directory" unless
          directory.respond_to?(:to_s)
        @directory = directory
        @logger = Config.logger

        # Quick sanity check.  Raise an exception if OVF file not there
        self.ovf_file
      end

      def ovf_file_path
         ovf_files = Dir[File.join(@directory, '*.ovf')]
        @logger.error "More than one OVF file found in dir #{@directory}" if
          ovf_files.length > 1
        raise "More than one OVF file found in directory #{@directory}" if
          ovf_files.length > 1
        @logger.error "No OVF file found in directory #{@directory}" if
          ovf_files.length < 1
        raise "No OVF file found in directory #{@directory}" if
          ovf_files.length < 1
        ovf_files.pop
      end

      def ovf_file
        File.new(ovf_file_path)
      end

      def vmdk_file_path(filename)
        file_path = File.join(@directory, filename)
        @logger.error "#{filename} not found in #{@directory}" unless
          File.exist? file_path
        raise "#{filename} not found in #{@directory}" unless
          File.exist? file_path
        file_path
      end

      def vmdk_file(filename)
        File.new(self.vmdk_file_path(filename), 'rb')
      end
    end
  end
end
