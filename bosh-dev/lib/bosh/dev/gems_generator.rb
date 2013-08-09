require 'bosh/dev/build'
require 'bosh/dev/version_file'

module Bosh
  module Dev
    class GemsGenerator
      def generate_and_upload
        VersionFile.new(Build.candidate.number).write

        Rake::Task['all:finalize_release_directory'].invoke

        Dir.chdir('pkg') do
          Bundler.with_clean_env do
            # We need to run this without Bundler as we generate an index for all dependant gems when run with bundler
            Rake::FileUtilsExt.sh('gem', 'generate_index', '.')
          end
          Build.candidate.upload_gems('.', 'gems')
        end
      end
    end
  end
end
