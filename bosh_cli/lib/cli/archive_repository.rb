module Bosh::Cli
  class ArchiveRepository
    def initialize(archive_dir, blobstore, resource)
      @archive_dir = archive_dir
      @blobstore = blobstore

      dev_builds_dir = Pathname(@archive_dir).join(".dev_builds", resource.plural_type, resource.name).to_s
      FileUtils.mkdir_p(dev_builds_dir)
      @dev_index = Versions::VersionsIndex.new(dev_builds_dir)
      @dev_storage = Versions::LocalVersionStorage.new(dev_builds_dir)

      final_builds_dir = Pathname(@archive_dir).join(".final_builds", resource.plural_type, resource.name).to_s
      FileUtils.mkdir_p(final_builds_dir)
      @final_index = Versions::VersionsIndex.new(final_builds_dir)
      @final_storage = Versions::LocalVersionStorage.new(final_builds_dir)

      @final_resolver = Versions::VersionFileResolver.new(@final_storage, @blobstore)
    end

    def lookup(resource)
      fingerprint = BuildArtifact.make_fingerprint(resource)

      artifact_info = @final_index[fingerprint]
      if artifact_info && artifact_info['blobstore_id']
        blobstore_id = artifact_info['blobstore_id']
        version = artifact_info['version'] || fingerprint
        sha1 = artifact_info['sha1']

        tarball_path = @final_resolver.find_file(blobstore_id, sha1, version, "#{resource.singular_type} #{resource.name} (#{version})") # todo: 'package' vs 'job'
        BuildArtifact.new(resource.name, {}, fingerprint, tarball_path, sha1, artifact_info['dependencies'], false)
      else
        artifact_info = @dev_index[fingerprint]
        if artifact_info
          version = artifact_info['version'] || fingerprint
          if @dev_storage.has_file?(version)
            tarball_path = @dev_storage.get_file(version)
            if file_checksum(tarball_path) != artifact_info['sha1']
              raise CorruptedArchive, "#{resource.singular_type} #{resource.name} (#{version}) archive at #{tarball_path} corrupted"
            end

            BuildArtifact.new(resource.name, {}, fingerprint, tarball_path, artifact_info['sha1'], artifact_info['dependencies'], true)
          end
        end
      end

    rescue Bosh::Blobstore::NotFound
      raise BlobstoreError, "Final version of '#{name}' not found in blobstore"
    rescue Bosh::Blobstore::BlobstoreError => e
      raise BlobstoreError, "Blobstore error: #{e}"
    end

    def upload_to_blobstore(artifact)
      # todo raise if artifact.dev_artifact?
      return artifact if artifact.metadata['blobstore_id']

      blobstore_id = nil
      File.open(artifact.tarball_path, 'r') do |f|
        blobstore_id = @blobstore.create(f)
      end

      puts "uploaded #{artifact.name} (#{artifact.fingerprint}) to the blobstore. artifact in dev index? #{!@dev_index[artifact.fingerprint].nil?}. artifact in final index? #{!@final_index[artifact.fingerprint].nil?}"
      @final_index.dump

      @final_index.update_version(artifact.fingerprint, {
          'version' => artifact.version,
          'sha1' => artifact.sha1,
          'blobstore_id' => blobstore_id
        })
      BuildArtifact.new(artifact.name, artifact.metadata, artifact.fingerprint, artifact.tarball_path, artifact.sha1, artifact.dependencies, false)
    end

    def install(artifact)
      fingerprint = artifact.fingerprint
      origin_file = artifact.tarball_path
      new_tarball_path = place_file_and_update_index(fingerprint, origin_file,
        artifact.dev_artifact? ? @dev_index : @final_index,
        artifact.dev_artifact? ? @dev_storage : @final_storage)

      BuildArtifact.new(artifact.name, artifact.metadata, artifact.fingerprint, new_tarball_path, artifact.sha1, artifact.dependencies, artifact.dev_artifact?)
    end

    def copy_from_dev_to_final(artifact)
      final_tarball_path = place_file_and_update_index(artifact.fingerprint, artifact.tarball_path, @final_index, @final_storage)
      BuildArtifact.new(artifact.name, artifact.metadata, artifact.fingerprint, final_tarball_path, artifact.sha1, artifact.dependencies, false)
    end

    private

    def place_file_and_update_index(fingerprint, origin_file, index, storage)
      # add version (with its validation) before adding sha1
      index.add_version(fingerprint, {'version' => fingerprint} )
      tarball_path = storage.put_file(fingerprint, origin_file)
      sha1 = file_checksum(tarball_path)
      index.update_version(fingerprint, {'version' => fingerprint, 'sha1' => sha1})
      tarball_path
    end

    def file_checksum(path)
      Digest::SHA1.file(path).hexdigest
    end
  end

  class CorruptedArchive < StandardError
  end
end
