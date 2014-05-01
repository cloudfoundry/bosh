require 'archive/tar/minitar'

module Bosh::Spec
  class TarFileInspector
    def initialize(path)
      @path = path
    end

    def file_names
      entries.map(&:name)
    end

    def smallest_file_size
      entries.map(&:size).min
    end

    private

    def entries
      return @entries if @entries

      @entries = []
      tar_reader = Zlib::GzipReader.open(@path)
      Archive::Tar::Minitar.open(tar_reader).each do |entry|
        @entries << entry if entry.file?
      end
      @entries
    end
  end
end
