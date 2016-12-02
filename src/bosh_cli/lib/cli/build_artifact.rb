module Bosh::Cli
  class BuildArtifact
    attr_reader :name, :fingerprint, :tarball_path, :sha1, :dependencies

    def initialize(name, fingerprint, tarball_path, sha1, dependencies, is_new_version, is_dev_artifact)
      @name = name
      @fingerprint = fingerprint
      @tarball_path = tarball_path
      @sha1 = sha1
      @dependencies = dependencies
      @is_dev_artifact = is_dev_artifact
      @notes = []
      @is_new_version = is_new_version
    end

    def promote_to_final
      @is_dev_artifact = false
    end

    def version
      fingerprint
    end

    def dev_artifact?
      @is_dev_artifact
    end

    def new_version?
      @is_new_version
    end

    private

    def self.checksum(tarball_path)
      if tarball_path && File.exists?(tarball_path)
        digest_file(tarball_path)
      else
        nil
      end
    end

    def self.digest_file(filename)
      File.file?(filename) ? Digest::SHA1.file(filename).hexdigest : ''
    end

    # Git doesn't really track file permissions, it just looks at executable
    # bit and uses 0755 if it's set or 0644 if not. We have to mimic that
    # behavior in the fingerprint calculation to avoid the situation where
    # seemingly clean working copy would trigger new fingerprints for
    # artifacts with changed permissions. Also we don't want current
    # fingerprints to change, hence the exact values below.
    def self.file_mode(path)
      if File.directory?(path)
        '40755'
      elsif File.executable?(path)
        '100755'
      else
        '100644'
      end
    end

    # TODO: be sure we are handling the case in which there was an index, with a pre-defined fingerprint
    def self.make_fingerprint(resource)
      scheme = 2
      contents = "v#{scheme}"

      resource.files.each do |filename, name|
        contents << resource.format_fingerprint(digest_file(filename), filename, name, file_mode(filename))
      end

      contents << resource.additional_fingerprints.join(",")
      Digest::SHA1.hexdigest(contents)
    end

    def resource
      raise
    end
  end
end
