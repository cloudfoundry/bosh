module Bosh::Cli
  class VersionsIndex

    attr_reader :index_file
    attr_reader :storage_dir

    def initialize(storage_dir)
      @storage_dir = File.expand_path(storage_dir)
      @index_file  = File.join(@storage_dir, 'index.yml')

      if File.file?(@index_file)
        init_index(load_yaml_file(@index_file, nil))
      else
        init_index({})
      end
    end

    def [](key)
      @data['builds'][key]
    end

    def each_pair(&block)
      @data['builds'].each_pair(&block)
    end

    def latest_version
      builds = @data["builds"].values

      return nil if builds.empty?

      version_strings = builds.map { |b| b["version"] }
      Bosh::Common::Version::ReleaseVersionList.parse(version_strings).latest.to_s
    end

    def select(&block)
      @data['builds'].select(&block)
    end

    # both (tmp_file_path=nil only used by release)
    def add_version(new_key, new_build)
      version = new_build['version']

      if version.blank?
        raise InvalidIndex, "Cannot save index entry without a version: `#{new_build}'"
      end

      if @data['builds'][new_key]
        raise "Trying to add duplicate entry `#{new_key}' into index `#{@index_file}'"
      end

      self.each_pair do |key, build|
        if build['version'] == version && key != new_key
          raise "Trying to add duplicate version `#{version}' into index `#{@index_file}'"
        end
      end

      create_directories

      @data['builds'][new_key] = new_build

      File.open(@index_file, 'w') do |f|
        f.write(Psych.dump(@data))
      end

      version
    end

    def update_version(key, new_build)
      old_build = @data['builds'][key]
      unless old_build
        raise "Cannot update non-existent entry with key `#{key}'"
      end

      if new_build['version'] != old_build['version']
        raise "Cannot update entry `#{old_build}' with a different version: `#{new_build}'"
      end

      @data['builds'][key] = new_build

      File.open(@index_file, 'w') do |f|
        f.write(Psych.dump(@data))
      end
    end

    def version_strings
      @data['builds'].map { |_, build| build['version'].to_s }
    end

    def to_s
      @data['builds'].to_s
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
      data ||= {}

      unless data.kind_of?(Hash)
        raise InvalidIndex, "Invalid versions index data type, #{data.class} given, Hash expected"
      end
      @data = data
      @data['builds'] ||= {}
    end
  end
end
