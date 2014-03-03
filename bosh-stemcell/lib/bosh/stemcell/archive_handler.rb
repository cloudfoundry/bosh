module Bosh::Stemcell
  class ArchiveHandler
    def initialize
      @shell = Bosh::Core::Shell.new
    end

    def compress(directory, archive_filename)
      @shell.run("sudo tar -cz -f #{archive_filename} #{directory}")
    end

    def extract(archive_filename, directory)
      @shell.run("sudo mkdir -p #{directory}")
      @shell.run("sudo tar -xz -f #{archive_filename} -C #{directory}")
    end
  end
end
