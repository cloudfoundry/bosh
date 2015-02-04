module Bosh::Cli::Versions
  class LocalVersionStorage

    class Sha1MismatchError < StandardError; end

    attr_reader :storage_dir

    def initialize(storage_dir, name_prefix=nil)
      @storage_dir = storage_dir
      @name_prefix = name_prefix
    end

    def put_file(version, origin_file_path)
      destination = file_path(version)
      unless File.exist?(origin_file_path)
        raise "Trying to store non-existant file `#{origin_file_path}' for version `#{version}'"
      end
      FileUtils.cp(origin_file_path, destination, :preserve => true)

      File.expand_path(destination)
    end

    def get_file(version)
      destination = file_path(version)
      unless File.exist?(destination)
        raise "Trying to retrieve non-existant file `#{destination}' for version `#{version}'"
      end

      File.expand_path(destination)
    end

    def has_file?(version)
      File.exists?(file_path(version))
    end

    def file_path(version)
      name = @name_prefix.blank? ? "#{version}.tgz" : "#{@name_prefix}-#{version}.tgz"
      File.join(@storage_dir, name)
    end
  end
end
