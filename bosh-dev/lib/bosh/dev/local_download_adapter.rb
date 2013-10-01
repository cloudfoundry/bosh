require 'fileutils'

module Bosh::Dev
  class LocalDownloadAdapter
    def download(uri, write_path)
      FileUtils.cp(uri, write_path)
      File.expand_path(write_path)
    end
  end
end
