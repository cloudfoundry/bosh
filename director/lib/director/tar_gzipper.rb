require 'tmpdir'

module Bosh::Director
  class TarGzipper
    include Bosh::RunsCommands

    SourceNotFound = Class.new(RuntimeError)
    SourceNotAbsolute = Class.new(RuntimeError)

    def compress(sources, dest)
      source_paths = [*sources].map { |s| Pathname.new(s) }

      source_paths.each do |source|
        unless source.exist?
          raise SourceNotFound.new("The source directory #{source} could not be found.")
        end

        unless source.absolute?
          raise SourceNotAbsolute.new("The source directory #{source} is not an absolute path.")
        end
      end

      Dir.mktmpdir('bosh_tgz') do |filename|
        source_paths.each do |source_path|
          FileUtils.cp_r(source_path, filename)
        end
        sh "tar -z -c -f #{dest} #{filename}"
      end
    end
  end
end
