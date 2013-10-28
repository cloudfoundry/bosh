require 'tempfile'

module Bosh::Director
  class CompiledPackagesExporter
    def initialize(_)
      @tgz = Tempfile.new('fake.tgz')
    end

    def tgz_path
      @tgz.path
    end
  end
end
