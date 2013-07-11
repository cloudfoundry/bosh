require 'tmpdir'
require 'open3'

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

      out, err, status = Open3.capture3('tar', '-C', base_dir, '-czf', dest, *sources)
      raise("tar exited #{status.exitstatus}, output: '#{out}', error: '#{err}'") unless status.success?
      out
    end
  end
end
