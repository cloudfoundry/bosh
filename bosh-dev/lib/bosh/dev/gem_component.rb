module Bosh
  module Dev
    class GemComponent
      ROOT = File.expand_path('../../../../../', __FILE__)

      def initialize(component, version)
        @component = component
        @version = version
      end

      def dot_gem
        "#{component}-#{version}.gem"
      end

      def build_release_gem
        FileUtils.mkdir_p "#{ROOT}/pkg/gems/"

        update_version

        gemspec = "#{component}.gemspec"
        Rake::FileUtilsExt.sh "cd #{component} && gem build #{gemspec} && mv #{dot_gem} #{ROOT}/pkg/gems/"
      end

      def update_version
        glob = File.join(ROOT, component, 'lib', '**', 'version.rb')

        version_file_path = Dir.glob(glob).first
        file_contents = File.read(version_file_path)
        file_contents.gsub!(/^(\s*)VERSION = (.*?)$/, "\\1VERSION = '#{version}'")

        File.open(version_file_path, 'w') { |f| f.write(file_contents) }
      end

      private

      attr_reader :component, :version
    end
  end
end
