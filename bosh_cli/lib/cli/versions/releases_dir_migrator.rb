# This class migrates the releases directory and its index.yml files from format v1 -> v2
module Bosh::Cli::Versions
  class ReleasesDirMigrator

    def initialize(releases_path, default_release_name, ui, release_type_name)
      @releases_path = releases_path
      @default_release_name = default_release_name
      @ui = ui
      @release_type_name = release_type_name
    end

    def needs_migration?
      index_path = File.join(@releases_path, 'index.yml')
      return false unless File.exists?(index_path)

      index = VersionsIndex.load_index_yaml(index_path)
      format_version_string = index['format-version']
      return true if format_version_string.nil?

      begin
        SemiSemantic::Version.parse(format_version_string) < VersionsIndex::CURRENT_INDEX_VERSION
      rescue ArgumentError, SemiSemantic::ParseError
        raise InvalidIndex, "Invalid versions index version in `#{index_path}', " +
          "`#{format_version_string}' given, SemiSemantic version expected"
      end
    end

    def migrate
      return false unless needs_migration?

      unless Dir.exist?(@releases_path)
        raise "Releases path `#{@releases_path}' does not exist"
      end

      @ui.header("Migrating #{@release_type_name} releases".make_green)

      old_index = VersionsIndex.new(@releases_path)

      migrated_releases = Set.new

      release_versions_to_migrate.each do |data|
        release_name = data[:name]
        if migrated_releases.add?(release_name)
          @ui.say("Migrating release: #{release_name}")
        end

        release_path = File.join(@releases_path, release_name)

        FileUtils.mkdir_p(release_path) unless Dir.exist?(release_path)

        # move version record to new index file in release_path
        index_key = old_index.find_key_by_version(data[:version])
        index_value = old_index[index_key]
        old_index.remove_version(index_key)
        new_index = VersionsIndex.new(release_path)
        new_index.add_version(index_key, index_value)

        # move tarball and manifest to release_path
        FileUtils.mv(data[:manifest_path], release_path)
        FileUtils.mv(data[:tarball_path], release_path) if File.exist?(data[:tarball_path])
      end

      @ui.say("Migrating default release: #{@default_release_name}")
      create_release_symlink

      # initialize release name & format-version in index.yml
      old_index.save

      true
    end

    private

    def release_versions_to_migrate
      release_versions_data.select { |v| v[:name] != @default_release_name }
    end

    def release_versions_data
      release_manifest_paths.map do |file_path|
        manifest_hash = load_yaml_file(file_path, nil)
        return {} unless manifest_hash.kind_of?(Hash)
        {
          name: manifest_hash['name'],
          version: manifest_hash['version'],
          manifest_path: file_path,
          tarball_path: file_path[0...-4] + '.tgz',
        }
      end.select do |version_record|
        # ignore invalid manifests
        version_record != {}
      end
    end

    def release_manifest_paths
      index_path = File.join(@releases_path, 'index.yml')
      Dir.glob(File.join(@releases_path, '*.yml')).select do |file_path|
        file_path != index_path
      end
    end

    def create_release_symlink
      # symlink must be relative in order to be portable (ex: git clone)
      Dir.chdir(@releases_path) do
         File.symlink('.', @default_release_name)
      end
    end
  end
end
