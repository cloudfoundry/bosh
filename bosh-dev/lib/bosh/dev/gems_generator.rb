require 'bosh/dev'
require 'bosh/dev/gem_components'

module Bosh::Dev
  class GemsGenerator
    def initialize(build)
      @build = build
      @components = GemComponents.new(build.number)
    end

    def generate_and_upload
      @components.build_release_gems

      Dir.chdir('pkg') do
        Bundler.with_clean_env do
          # We need to run this without Bundler as we generate an index
          # for all dependant gems when run with bundler
          Rake::FileUtilsExt.sh('gem', 'generate_index', '.')
        end
        @build.upload_gems('.', 'gems')
      end
    end
  end
end
