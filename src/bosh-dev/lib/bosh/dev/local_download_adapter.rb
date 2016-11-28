require 'fileutils'

module Bosh::Dev
  class LocalDownloadAdapter
    def initialize(logger)
      @logger = logger
    end

    def download(file_path, write_path)
      @logger.info("Copying #{file_path} to #{write_path}")
      FileUtils.cp(file_path, write_path)
      File.expand_path(write_path)
    end
  end
end
