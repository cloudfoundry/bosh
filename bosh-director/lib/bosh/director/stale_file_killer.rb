require 'fileutils'
require 'bosh/director'

module Bosh::Director
  class StaleFileKiller
    def initialize(dir)
      @dir = dir
    end

    def kill
      Dir[File.join(@dir, '*')].select {|entry|
        (Time.now - File.mtime(entry)) > 3600
      }.each { |entry| FileUtils.rm(entry) }
    end
  end
end
