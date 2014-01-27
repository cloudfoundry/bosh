require 'tmpdir'
require 'open3'

module Bosh::Director::Core
  class TarGzipper
    # @param [String] base_dir the directory from which the tar command is run
    # @param [String, Array] sources the relative paths to include
    # @param [String] dest the destination filename for the tgz output
    # @param [Hash] options the options for compress
    # @option options [Boolean] :copy_first copy the source to a temp dir before archiving
    def compress(base_dir, sources, dest, options = {})
      sources = [*sources]
      sources.each do |source|
        if source.include?(File::SEPARATOR)
          raise "Sources must have a path depth of 1 and contain no '#{File::SEPARATOR}'"
        end
      end

      base_dir_path = Pathname.new(base_dir)
      raise "The base directory #{base_dir} could not be found." unless base_dir_path.exist?
      raise "The base directory #{base_dir} is not an absolute path." unless base_dir_path.absolute?

      if options[:copy_first]
        Dir.mktmpdir do |tmpdir|
          FileUtils.cp_r(sources.map { |s| File.join(base_dir, s) }, "#{tmpdir}/")
          tar(tmpdir, dest, sources)
        end
      else
        tar(base_dir, dest, sources)
      end
    end

    private

    def tar(base_dir, dest, sources)
      out, err, status = Open3.capture3('tar', '-C', base_dir, '-czf', dest, *sources)
      raise("tar exited #{status.exitstatus}, output: '#{out}', error: '#{err}'") unless status.success?
      out
    end
  end
end
