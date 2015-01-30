module Bosh::Cli
  class BuildArtifact
    def initialize(resource)
      @resource = resource
    end

    def name
      metadata['name']
    end

    def metadata
      resource.metadata.merge({
        'fingerprint' => fingerprint,
        'version' => version,
        'tarball_path' => tarball_path,
        'sha1' => checksum,
        'new_version' => new_version,
        'notes' => notes
      })
    end

    # TODO: be sure we are handling the case in which there was an index, with a pre-defined fingerprint
    def fingerprint
      @fingerprint ||= make_fingerprint
    end

    def version
      fingerprint
    end

    # ---

    def checksum=(value)
      @checksum = value
    end

    def checksum
      @checksum
    end

    def new_version=(value)
      @new_version = value
    end

    def new_version
      @new_version
    end

    def notes=(value)
      @notes = value
    end

    def notes
      @notes
    end

    def tarball_path=(value)
      @tarball_path = value
    end

    def tarball_path
      @tarball_path
    end

    private

    def digest_file(filename)
      File.file?(filename) ? Digest::SHA1.file(filename).hexdigest : ''
    end

    # Git doesn't really track file permissions, it just looks at executable
    # bit and uses 0755 if it's set or 0644 if not. We have to mimic that
    # behavior in the fingerprint calculation to avoid the situation where
    # seemingly clean working copy would trigger new fingerprints for
    # artifacts with changed permissions. Also we don't want current
    # fingerprints to change, hence the exact values below.
    def file_mode(path)
      if File.directory?(path)
        '40755'
      elsif File.executable?(path)
        '100755'
      else
        '100644'
      end
    end

    def make_fingerprint
      scheme = 2
      contents = "v#{scheme}"

      resource.files.each do |filename, name|
        contents << resource.format_fingerprint(digest_file(filename), filename, name, file_mode(filename))
      end

      contents << resource.additional_fingerprints.join(",")
      Digest::SHA1.hexdigest(contents)
    end

    def resource
      @resource
    end
  end
end
