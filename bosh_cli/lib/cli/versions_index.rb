module Bosh::Cli
  class VersionsIndex
    include VersionCalc

    def initialize(storage_dir, name_prefix = nil)
      @storage_dir = File.expand_path(storage_dir)
      @index_file  = File.join(@storage_dir, "index.yml")
      @name_prefix = name_prefix

      if File.file?(@index_file)
        init_index(load_yaml_file(@index_file, nil))
      else
        init_index({})
      end
    end

    def find_by_checksum(checksum)
      @data["builds"].each_pair do |fingerprint, build_data|
        return build_data if build_data["sha1"] == checksum
      end
      nil
    end

    def [](fingerprint)
      @data["builds"][fingerprint]
    end

    ##
    # Return the last version from the version index file
    # as jobs and packages have a non-numeric versioning
    # scheme based on their fingerprint. This function relies
    # on hash insertion order being preserved. While this
    # is the behavior for Ruby 1.9.X and 2.X we should
    # remember that this implementation is
    # a little brittle.
    def latest_version(major = nil)
      builds = @data["builds"].values

      if major
        builds = builds.select do |build|
          major_version(build["version"]) == major
        end
      end

      return nil if builds.empty?

      builds.last["version"]
    end

    def version_exists?(version)
      File.exists?(filename(version))
    end

    def add_version(fingerprint, item, tmp_file_path = nil)
      version = item["version"]

      if version.blank?
        raise InvalidIndex,
              "Cannot save index entry without knowing its version"
      end

      create_directories

      if tmp_file_path
        FileUtils.cp(tmp_file_path, filename(version), :preserve => true)
      end

      @data["builds"].each_pair do |fp, build|
        if build["version"] == version && fp != fingerprint
          raise "Trying to add duplicate version `#{version}' " +
                    "into index `#{@index_file}'"
        end
      end

      @data["builds"][fingerprint] = item
      if tmp_file_path
        file_sha1 = Digest::SHA1.file(tmp_file_path).hexdigest
        @data["builds"][fingerprint]["sha1"] = file_sha1
      end

      File.open(@index_file, "w") do |f|
        f.write(Psych.dump(@data))
      end

      File.expand_path(filename(version))
    end

    def filename(version)
      name = @name_prefix.blank? ?
          "#{version}.tgz" : "#{@name_prefix}-#{version}.tgz"
      File.join(@storage_dir, name)
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
        raise InvalidIndex, "Invalid versions index data type, " +
            "#{data.class} given, Hash expected"
      end
      @data = data
      @data.delete("latest_version") # Indices used to track latest versions
      @data["builds"] ||= {}
    end
  end
end
