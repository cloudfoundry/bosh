module Bosh::Cli

  class VersionsIndex
    def initialize(storage_dir)
      @storage_dir = File.expand_path(storage_dir)
      @index_file  = File.join(@storage_dir, "index.yml")

      unless File.directory?(@storage_dir)
        begin
          FileUtils.mkdir_p(@storage_dir)
        rescue
          raise InvalidIndex, "Cannot create index storage directory: #{@storage_dir}"
        end
      end

      unless File.file?(@index_file) && File.readable?(@index_file)
        begin
          FileUtils.touch(@index_file)
        rescue
          raise InvalidIndex, "Cannot create index file: #{@index_file}"
        end
      end

      @data = YAML.load_file(@index_file)
      @data = { } unless @data.is_a?(Hash)
      @data["builds"] ||= {}
    end

    def [](fingerprint)
      @data["builds"][fingerprint]
    end

    def latest_version
      @data["latest_version"]
    end

    def version_exists?(version)
      File.exists?(filename(version))
    end

    def add_version(fingerprint, item, payload)
      version = item["version"]

      if version.blank?
        raise InvalidIndex, "Cannot save index entry without knowing its version"
      end

      File.open(filename(version), "w") do |f|
        f.write(payload)
      end

      @data["builds"][fingerprint] = item
      @data["builds"][fingerprint]["sha1"] = Digest::SHA1.hexdigest(payload)
      @data["latest_version"] = version

      File.open(@index_file, "w") do |f|
        f.write(YAML.dump(@data))
      end

      File.expand_path(filename(version))
    end

    def filename(version)
      File.join(@storage_dir, "#{version}.tgz")
    end

  end
end
