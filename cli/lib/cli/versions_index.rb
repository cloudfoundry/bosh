# Copyright (c) 2009-2012 VMware, Inc.

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

    def latest_version(major = nil)
      builds = @data["builds"].values

      if major
        builds = builds.select do |build|
          major_version(build["version"]) == major
        end
      end

      return nil if builds.empty?

      sorted = builds.sort do |build1, build2|
        cmp = version_cmp(build2["version"], build1["version"])
        if cmp == 0
          raise "There is a duplicate version `#{build1["version"]}' " +
                  "in index `#{@index_file}'"
        end
        cmp
      end

      sorted[0]["version"]
    end

    def version_exists?(version)
      File.exists?(filename(version))
    end

    def add_version(fingerprint, item, payload = nil)
      version = item["version"]

      if version.blank?
        raise InvalidIndex,
              "Cannot save index entry without knowing its version"
      end

      create_directories

      if payload
        File.open(filename(version), "w") do |f|
          f.write(payload)
        end
      end

      @data["builds"].each_pair do |fp, build|
        if version_cmp(build["version"], version) == 0 && fp != fingerprint
          raise "Trying to add duplicate version `#{version}' " +
                    "into index `#{@index_file}'"
        end
      end

      @data["builds"][fingerprint] = item
      if payload
        @data["builds"][fingerprint]["sha1"] = Digest::SHA1.hexdigest(payload)
      end

      File.open(@index_file, "w") do |f|
        f.write(YAML.dump(@data))
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
