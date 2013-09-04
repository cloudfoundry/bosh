module Bosh
  module Dev
    class GemComponent
      def initialize(component, root = nil, version = nil)
        @component = component
        @root = root
        @version = version
      end

      def update_version
        glob = File.join(root, component, 'lib', '**', 'version.rb')

        version_file_path = Dir[glob].first
        file_contents = File.read(version_file_path)
        file_contents.gsub!(/^(\s*)VERSION = (.*?)$/, "\\1VERSION = '#{version}'")

        File.open(version_file_path, 'w') { |f| f.write(file_contents) }
      end

      def stale?
        gem_path = File.join(root, 'release', 'src', 'bosh', component, "#{component}-#{version}.gem")

        return true unless File.exists?(gem_path)

        gem_src_dir = File.join(root, component)
        gemspec_path = File.join(gem_src_dir, "#{component}.gemspec")

        Dir.chdir(gem_src_dir) do
          gemspec = Gem::Specification.load(gemspec_path)
          files = gemspec.files + [gemspec_path]

          last_code_change_time = files.map { |file| File::Stat.new(file).mtime }.max
          last_code_change_time > File::Stat.new(gem_path).mtime
        end
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
