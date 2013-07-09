require 'tmpdir'

module Bosh::Director
  class TarGzipper
    include Bosh::RunsCommands

    # base_dir - [String] the directory from which the tar command is run
    # sources - [String] or [Array] the relative paths to include
    # dest - [String] the destination filename for the tgz output
    def compress(base_dir, sources, dest)
      base_dir_path = Pathname.new(base_dir)
      sources = [*sources]

      unless base_dir_path.exist?
        raise "The base directory #{base_dir} could not be found."
      end

      unless base_dir_path.absolute?
        raise "The base directory #{base_dir} is not an absolute path."
      end

      Dir.chdir(base_dir) do
        sh "tar -z -c -f #{dest} #{sources.join(' ')}"
      end
    end
  end
end
