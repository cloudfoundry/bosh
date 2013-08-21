require 'bosh/dev/build'
require 'bosh/dev/version_file'

module Bosh
  module Dev
    class GemsGenerator
      def generate_and_upload
        VersionFile.new(Build.candidate.number).write

        build_gems_into_release_dir

        Dir.chdir('pkg') do
          Bundler.with_clean_env do
            # We need to run this without Bundler as we generate an index for all dependant gems when run with bundler
            Rake::FileUtilsExt.sh('gem', 'generate_index', '.')
          end
          Build.candidate.upload_gems('.', 'gems')
        end
      end

      def build_gems_into_release_dir
        Rake::Task['all:finalize_release_directory'].invoke
      end
    end
  end
end
