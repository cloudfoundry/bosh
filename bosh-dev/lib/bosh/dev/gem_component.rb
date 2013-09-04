module Bosh
  module Dev
    class GemComponent
      def initialize(component)
        @component = component
      end

      def update_version
        glob = File.join(root, component, 'lib', '**', 'version.rb')

        version_file_path = Dir[glob].first
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
        File.read("#{root}/BOSH_VERSION").strip
      end
    end
  end
end
