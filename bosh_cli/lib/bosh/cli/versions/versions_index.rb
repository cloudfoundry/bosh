module Bosh::Cli::Versions
  class VersionsIndex
    include Enumerable

    CURRENT_INDEX_VERSION = SemiSemantic::Version.parse('2')

    def self.load_index_yaml(index_path)
      contents = load_yaml_file(index_path, nil)
      # Psych.load returns false if file is empty
      return nil if contents === false
      unless contents.kind_of?(Hash)
        raise Bosh::Cli::InvalidIndex, "Invalid versions index data type, #{contents.class} given, Hash expected"
      end
      contents
    end

    def self.write_index_yaml(index_path, contents)
      unless contents.kind_of?(Hash)
        raise Bosh::Cli::InvalidIndex, "Invalid versions index data type, #{contents.class} given, Hash expected"
      end
      File.open(index_path, 'w') do |f|
        f.write(Psych.dump(contents))
      end
    end

    attr_reader :index_file
    attr_reader :storage_dir

    def initialize(storage_dir)
      @storage_dir = File.expand_path(storage_dir)
      @index_file  = File.join(@storage_dir, 'index.yml')

      if File.file?(@index_file)
        reload
      else
        init_index({})
      end
    end

    def [](key)
      @data['builds'][key]
    end

    def each(&block)
      @data['builds'].each(&block)
    end

    def select(&block)
      @data['builds'].select(&block)
    end

    # both (tmp_file_path=nil only used by release)
    def add_version(new_key, new_build)
      version = new_build['version']

      if version.blank?
        raise Bosh::Cli::InvalidIndex, "Cannot save index entry without a version: '#{new_build}'"
      end

      if @data['builds'][new_key]
        raise "Trying to add duplicate entry '#{new_key}' into index '#{@index_file}'"
      end

      each do |key, build|
        if key != new_key && build['version'] == version
          raise "Trying to add duplicate version '#{version}' into index '#{@index_file}'"
        end
      end

      @data['builds'][new_key] = new_build

      save

      version
    end

    def update_version(key, new_build)
      old_build = @data['builds'][key]
      unless old_build
        raise "Cannot update non-existent entry with key '#{key}'"
      end

      if old_build['blobstore_id']
        raise "Cannot update entry '#{old_build}' with a blobstore id"
      end

      if new_build['version'] != old_build['version']
        raise "Cannot update entry '#{old_build}' with a different version: '#{new_build}'"
      end

      @data['builds'][key] = new_build

      save
    end

    def remove_version(key)
      build = @data['builds'][key]
      unless build
        raise "Cannot remove non-existent entry with key '#{key}'"
      end

      @data['builds'].delete(key)

      save
    end

    def find_key_by_version(version)
      key_and_build = find { |_, build| build['version'] == version }

      key_and_build.first unless key_and_build.nil?
    end

    def version_strings
      @data['builds'].map { |_, build| build['version'].to_s }
    end

    def to_s
      @data['builds'].to_s
    end

    def format_version
      format_version_string = @data['format-version']
      SemiSemantic::Version.parse(format_version_string)
    rescue ArgumentError, SemiSemantic::ParseError
      raise InvalidIndex, "Invalid versions index version in '#{@index_file}', " +
        "'#{format_version_string}' given, SemiSemantic version expected"
    end

    def save
      create_directories
      VersionsIndex.write_index_yaml(@index_file, @data)
    end

    def reload
      init_index(VersionsIndex.load_index_yaml(@index_file))
    end

    private

    def create_directories
      begin
        FileUtils.mkdir_p(@storage_dir)
      rescue SystemCallError => e
        raise InvalidIndex, "Cannot create index storage directory: #{e}"
      end

      begin
        FileUtils.touch(@index_file)
      rescue SystemCallError => e
        raise InvalidIndex, "Cannot create index file: #{e}"
      end
    end

    def init_index(data)
      @data = data || {}
      @data['builds'] ||= {}
      @data['format-version'] ||= CURRENT_INDEX_VERSION.to_s
    end
  end
end
