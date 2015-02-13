module Bosh::Cli::Versions
  class LocalArtifactStorage

    class Sha1MismatchError < StandardError; end

    attr_reader :storage_dir

    def initialize(storage_dir)
      @storage_dir = storage_dir
    end

    def put_file(sha, origin_file_path)
      destination = file_path(sha)
      unless File.exist?(origin_file_path)
        raise "Trying to store non-existant file `#{origin_file_path}' with sha `#{sha}'"
      end
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(origin_file_path, destination, :preserve => true)

      File.expand_path(destination)
    end

    def get_file(sha)
      destination = file_path(sha)
      unless File.exist?(destination)
        raise "Trying to retrieve non-existant file `#{destination}' with sha `#{sha}'"
      end

      File.expand_path(destination)
    end

    def has_file?(sha)
      File.exists?(file_path(sha))
    end

    def file_path(name)
      File.join(@storage_dir, name)
    end
  end
end
