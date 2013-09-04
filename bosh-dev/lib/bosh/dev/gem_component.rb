module Bosh
  module Dev
    class GemComponent
      def initialize(component, root = nil, version = nil)
        @component = component
        @root = root
        @version = version
      end

      def build_release_gem
        FileUtils.mkdir_p "#{root}/pkg/gems/"

        update_version

        gemspec = "#{component}.gemspec"
        Rake::FileUtilsExt.sh "cd #{component} && gem build #{gemspec} && mv #{component}-#{version}.gem #{root}/pkg/gems/"
      end

      def update_version
        glob = File.join(root, component, 'lib', '**', 'version.rb')

        version_file_path = Dir.glob(glob).first
        file_contents = File.read(version_file_path)
        file_contents.gsub!(/^(\s*)VERSION = (.*?)$/, "\\1VERSION = '#{version}'")

        File.open(version_file_path, 'w') { |f| f.write(file_contents) }
      end

      private

      attr_reader :component

      def root
        @root ||= File.expand_path('../../../../../', __FILE__)
      end

      def version
        @version ||= File.read("#{root}/BOSH_VERSION").strip
      end
    end
  end
end
