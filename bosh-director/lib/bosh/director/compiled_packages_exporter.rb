require 'tempfile'

module Bosh::Director
  class CompiledPackagesExporter
    def initialize
      @tgz = Tempfile.new('fake.tgz')
    end

    def tgz_path
      @tgz.path
    end
  end
end
