module Bosh::Cli
  class ArchiveRepository
    def initialize(archive_dir, artifacts_dir, blobstore, resource)
      @archive_dir = archive_dir
      @blobstore = blobstore

      dev_builds_dir = Pathname(@archive_dir).join('.dev_builds', resource.plural_type, resource.name).to_s
      FileUtils.mkdir_p(dev_builds_dir)
      @dev_index = Versions::VersionsIndex.new(dev_builds_dir)

      final_builds_dir = Pathname(@archive_dir).join('.final_builds', resource.plural_type, resource.name).to_s
      FileUtils.mkdir_p(final_builds_dir)
      @final_index = Versions::VersionsIndex.new(final_builds_dir)

      @storage = Versions::LocalArtifactStorage.new(artifacts_dir)
      FileUtils.mkdir_p(artifacts_dir)

      @final_resolver = Versions::VersionFileResolver.new(@storage, @blobstore)
    end

    def lookup(resource)
      fingerprint = BuildArtifact.make_fingerprint(resource)

      artifact_info = @final_index[fingerprint]
      if artifact_info && artifact_info['blobstore_id']
        blobstore_id = artifact_info['blobstore_id']
        version = artifact_info['version'] || fingerprint
        sha1 = artifact_info['sha1']

        say("Using final version '#{version}'")
        tarball_path = @final_resolver.find_file(blobstore_id, sha1, "#{resource.singular_type} #{resource.name} (#{version})")

        BuildArtifact.new(resource.name, fingerprint, tarball_path, sha1, resource.dependencies, false, false)
      else
        artifact_info = @dev_index[fingerprint]
        if artifact_info
          if @storage.has_file?(artifact_info['sha1'])
            version = artifact_info['version'] || fingerprint
            say("Using dev version '#{version}'")

            tarball_path = @storage.get_file(artifact_info['sha1'])
            if file_checksum(tarball_path) != artifact_info['sha1']
              raise CorruptedArchive, "#{resource.singular_type} #{resource.name} (#{version}) archive at #{tarball_path} corrupted"
            end

            BuildArtifact.new(resource.name, fingerprint, tarball_path, artifact_info['sha1'], resource.dependencies, false, true)
          end
        end
      end

    rescue Bosh::Blobstore::NotFound => e
      raise BlobstoreError, "Final version of '#{resource.name}' not found in blobstore: #{e}"
    rescue Bosh::Blobstore::BlobstoreError => e
      raise BlobstoreError, "Blobstore error: #{e}"
    end

    def upload_to_blobstore(artifact)
      artifact_info = @final_index[artifact.fingerprint]
      # todo raise if artifact.dev_artifact?
      return artifact, artifact_info['blobstore_id'] if artifact_info['blobstore_id']

      blobstore_id = nil
      File.open(artifact.tarball_path, 'r') do |f|
        blobstore_id = @blobstore.create(f)
      end

      @final_index.update_version(artifact.fingerprint, {
          'version' => artifact.version,
          'sha1' => artifact.sha1,
          'blobstore_id' => blobstore_id
        })
      artifact = BuildArtifact.new(artifact.name, artifact.fingerprint, artifact.tarball_path, artifact.sha1, artifact.dependencies, artifact.new_version?, false)
      return artifact, blobstore_id
    end

    def install(artifact)
      fingerprint = artifact.fingerprint
      origin_file = artifact.tarball_path

      tarball_path = @storage.put_file(artifact.sha1, origin_file)

      update_index(
        tarball_path,
        fingerprint,
        artifact.dev_artifact? ? @dev_index : @final_index)

      BuildArtifact.new(artifact.name, artifact.fingerprint, tarball_path, artifact.sha1, artifact.dependencies, artifact.new_version?, artifact.dev_artifact?)
    end

    def promote_from_dev_to_final(artifact)
      update_index(artifact.tarball_path, artifact.fingerprint, @final_index)
      artifact.promote_to_final
    end

    private

    def update_index(tarball_path, fingerprint, index)
      # In case of corrupted file the new file will be downloaded/re-generated
      # so sha1 needs to be updated to fix the index
      unless index[fingerprint]
        index.add_version(fingerprint, {'version' => fingerprint} )
      end

      sha1 = file_checksum(tarball_path)
      index.update_version(fingerprint, {'version' => fingerprint, 'sha1' => sha1})
    end

    def file_checksum(path)
      Digest::SHA1.file(path).hexdigest
    end
  end

  class CorruptedArchive < StandardError
  end
end
