module VCloudSdk

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
      ovf_files = Dir[File.join(@directory, "*.ovf")]
      if ovf_files.length > 1
        @logger.error "More than one OVF file found in dir #{@directory}"
        raise "More than one OVF file found in directory #{@directory}"
      end
      if ovf_files.length < 1
        @logger.error "No OVF file found in directory #{@directory}"
        raise "No OVF file found in directory #{@directory}"
      end
      ovf_files.pop
    end

    def ovf_file
      File.new(ovf_file_path)
    end

    def vmdk_file_path(filename)
      file_path = File.join(@directory, filename)
      unless File.exist? file_path
        @logger.error "#{filename} not found in #{@directory}"
        raise "#{filename} not found in #{@directory}"
      end
      file_path
    end

    def vmdk_file(filename)
      File.new(self.vmdk_file_path(filename), "rb")
    end
  end

end
