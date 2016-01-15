module Bosh::Cli
  class SortedReleaseArchiver
    def initialize(dir)
      @dir = dir
    end

    def archive(destination_file)
      Dir.chdir(@dir) do
        success = Kernel.system('tar', '-C', @dir, '-pczf', destination_file, *ordered_release_files, out: '/dev/null', err: '/dev/null')
        if !success
          raise InvalidRelease, 'Cannot create release tarball'
        end
      end
    end

    private

    def ordered_release_files
      ordered_release_files = ['./release.MF']
      license_files = (Dir.entries('.') & ['LICENSE', 'NOTICE']).sort
      unless license_files.empty?
        ordered_release_files += license_files.map { |filename| "./#{filename}" }
      end
      ordered_release_files += ['./jobs', './packages']
      ordered_release_files
    end
  end
end
