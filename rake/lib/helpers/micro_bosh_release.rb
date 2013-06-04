require 'rake'

module Bosh
  module Helpers
    class MicroBoshRelease
      include Rake::FileUtilsExt

      def build
        Dir.chdir('release') do
          sh('cp config/bosh-dev-template.yml config/dev.yml')
          sh('bosh create release --force --with-tarball')
        end

        release_tarball = `ls -1t release/dev_releases/bosh*.tgz | head -1`.chomp
        File.join(File.expand_path(File.dirname(__FILE__)), "..", "..", "..", release_tarball)
      end
    end
  end
end
