module Bosh::Cli
  class ArchiveRepository
    def initialize(archive_dir, blobstore, resource)
      @archive_dir = archive_dir
      @blobstore = blobstore
      @resource = resource

      dev_builds_dir = build_directory('dev')
      FileUtils.mkdir_p(dev_builds_dir)
      @dev_index = Versions::VersionsIndex.new(dev_builds_dir)
      @dev_storage = Versions::LocalVersionStorage.new(dev_builds_dir)

      final_builds_dir = build_directory('final')
      FileUtils.mkdir_p(final_builds_dir)
      @final_index = Versions::VersionsIndex.new(final_builds_dir)
      @final_storage = Versions::LocalVersionStorage.new(final_builds_dir)

      @final_resolver = Versions::VersionFileResolver.new(@final_storage, @blobstore)
    end

    attr_reader :resource

    def lookup(resource)
      fingerprint = BuildArtifact.make_fingerprint(resource)

      metadata = @final_index[fingerprint]
      if metadata && metadata['blobstore_id']
        blobstore_id = metadata['blobstore_id']
        version = metadata['version'] || fingerprint
        sha1 = metadata['sha1']

        tarball_path = @final_resolver.find_file(blobstore_id, sha1, version, "#{artifact_type(resource)} #{resource.name} (#{version})") # todo: 'package' vs 'job'
        BuildArtifact.new(resource.name, metadata, fingerprint, tarball_path, false)
      else
        metadata = @dev_index[fingerprint]
        if metadata
          version = metadata['version'] || fingerprint
          if @dev_storage.has_file?(version)
            tarball_path = @dev_storage.get_file(version)
            if file_checksum(tarball_path) != metadata['sha1']
              raise CorruptedArchive, "#{artifact_type(resource)} #{resource.name} (#{version}) archive at #{tarball_path} corrupted"
            end

            BuildArtifact.new(resource.name, metadata, fingerprint, tarball_path, true)
          end
        end
      end

    rescue Bosh::Blobstore::NotFound
      raise BlobstoreError, "Final version of '#{name}' not found in blobstore"
    rescue Bosh::Blobstore::BlobstoreError => e
      raise BlobstoreError, "Blobstore error: #{e}"
    end

    def upload_to_blobstore(f)
      @blobstore.create(f)
    end

    def update_final_version(fingerprint, metadata)
      @final_index.update_version(fingerprint, metadata)
    end

    def put(fingerprint, tmp_file, final)
      origin_file = tmp_file.path
      metadata = {'version' => fingerprint}

      install(fingerprint, metadata, origin_file,
        final ? @final_index : @dev_index,
        final ? @final_storage : @dev_storage)
    end

    def copy_from_dev_to_final(artifact)
      final_tarball_path = install(artifact, artifact.metadata, artifact.tarball_path, @final_index, @final_storage)
      BuildArtifact.new(artifact.name, artifact.metadata, artifact.fingerprint, final_tarball_path, false)
    end

    def install(fingerprint, metadata, origin_file, index, storage)
      # add version (with its validation) before adding sha1
      index.add_version(fingerprint, metadata)
      tarball_path = storage.put_file(fingerprint, origin_file)
      metadata['sha1'] = file_checksum(tarball_path)
      index.update_version(fingerprint, metadata)
      tarball_path
    end

    def file_checksum(path)
      Digest::SHA1.file(path).hexdigest
    end

    def artifact_type(resource, plural = false)
      result = resource.class.name.split('::').last.downcase
      result += 's' if plural
      result
    end

    private

    def build_directory(mode)
      Pathname(@archive_dir).join(".#{mode}_builds", "#{artifact_type(resource, true)}", resource.name).to_s
    end
  end

  class CorruptedArchive < StandardError
  end
end
