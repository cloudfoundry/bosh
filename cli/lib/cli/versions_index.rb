module Bosh::Cli

  class VersionsIndex
    def initialize(index_file, storage_dir)
      @index_file  = File.expand_path(index_file)
      @storage_dir = File.expand_path(storage_dir)

      unless File.file?(index_file) && File.readable?(index_file)
        raise InvalidIndex, "Cannot read index file: #{index_file}"
      end

      unless File.directory?(storage_dir)
        raise InvalidIndex, "Cannot read index storage directory: #{storage_dir}"
      end

      @data = YAML.load_file(@index_file)
      @data = { } unless @data.is_a?(Hash)
    end

    def [](fingerprint)
      @data[fingerprint]
    end

    def all_versions
      @data.values.map{ |v| v["version"].to_i }.sort
    end

    def current_version
      all_versions.max.to_i
    end

    def next_version
      current_version + 1      
    end

    def version_exists?(version)
      File.exists?(filename(version))
    end

    def add_version(fingerprint, attrs, payload)
      version = attrs["version"]
      
      if version.blank?
        raise InvalidIndex, "Cannot save index entry without knowing its version"
      end

      File.open(filename(version), "w") do |f|
        f.write(payload)
      end

      @data[fingerprint] = attrs

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
