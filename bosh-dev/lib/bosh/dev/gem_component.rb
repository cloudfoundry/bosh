module Bosh
  module Dev
    class GemComponent
      ROOT = File.expand_path('../../../../../', __FILE__)

      attr_reader :name, :version

      def initialize(name, version)
        @name = name
        @version = version
      end

      def dot_gem
        "#{name}-#{version}.gem"
      end

      def update_version
        glob = File.join(ROOT, name, 'lib', '**', 'version.rb')

        version_file_paths = Dir.glob(glob)
        raise if version_file_paths.size > 1
        version_file_path = version_file_paths.first

        file_contents = File.read(version_file_path)
        file_contents.gsub!(/^(\s*)VERSION = (.*?)$/, "\\1VERSION = '#{version}'")

        File.open(version_file_path, 'w') { |f| f.write(file_contents) }
      end

      def build_gem(destination_dir)
        gemspec = "#{name}.gemspec"
        Rake::FileUtilsExt.sh "cd #{name} && gem build #{gemspec} && mv #{dot_gem} #{destination_dir}"
      end

      def dependencies
        gemfile_lock_path = File.join(ROOT, 'Gemfile.lock')
        lockfile = Bundler::LockfileParser.new(File.read(gemfile_lock_path))

        Bundler::Resolver.resolve(
          Bundler.definition.send(:expand_dependencies, Bundler.definition.dependencies.select { |d| d.name == name }),
          Bundler.definition.index,
          {},
          lockfile.specs
        )
      end
    end
  end
end
