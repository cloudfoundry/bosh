require 'rake'

module Bosh
  module Dev
    class MicroBoshRelease
      def tarball
        Dir.chdir('release') do
          FileUtils.cp('config/bosh-dev-template.yml', 'config/dev.yml')
          Rake::FileUtilsExt.sh('bosh create release --force --with-tarball')
        end

        release_tarball = Dir.glob('release/dev_releases/bosh*.tgz').max_by { |f| File.mtime(f) }
        File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', '..', '..', release_tarball)
      end
    end
  end
end
