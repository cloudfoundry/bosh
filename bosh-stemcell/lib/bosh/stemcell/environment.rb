require 'fileutils'

module Bosh::Stemcell
  class Environment
    attr_reader :directory, :build_path, :work_path

    def initialize(options)
      mnt = ENV.to_hash.fetch('FAKE_MNT', '/mnt')
      @directory = File.join(mnt, 'stemcells', "#{options.fetch(:infrastructure_name)}")
      @build_path = File.join(directory, 'build')
      @work_path = File.join(directory, 'work')
    end
  end
end
