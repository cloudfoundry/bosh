require 'psych'
require 'bosh/dev/bat'
require 'bosh/dev/bat/shell'

module Bosh::Dev::Bat
  class StemcellArchive
    def initialize(tgz)
      @tgz = tgz
      @shell = Shell.new
    end

    def version
      manifest['version']
    end

    private

    attr_reader :tgz, :shell

    def manifest
      Dir.mktmpdir do |dir|
        shell.run("tar xzf #{tgz} --directory #{dir} stemcell.MF")
        Psych.load_file(File.join(dir, 'stemcell.MF'))
      end
    end
  end
end
