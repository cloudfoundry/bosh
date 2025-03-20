module Bosh::Director
  class ReleaseDirectory
    def initialize(release_directory)
      @release_directory = release_directory
    end

    def ordered_release_files
      dir_entries = Dir.entries(@release_directory)
      ordered_release_files = ['release.MF']
      ordered_release_files += (dir_entries & ['LICENSE', 'NOTICE']).sort
      ordered_release_files << 'jobs'
      ordered_release_files += (dir_entries & ['compiled_packages', 'packages'])
      ordered_release_files.map { |filename| "./#{filename}" }
    end
  end
end
