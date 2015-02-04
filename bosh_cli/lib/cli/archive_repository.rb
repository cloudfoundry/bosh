module Bosh::Cli
  class ArchiveRepository
    def initialize(archive_dir, blobstore, resource)
      @archive_dir = archive_dir
      @blobstore = blobstore
      @resource = resource

      dev_builds_dir = build_directory('dev')
      FileUtils.mkdir_p(dev_builds_dir)
      @dev_index   = Versions::VersionsIndex.new(dev_builds_dir)
      @dev_storage = Versions::LocalVersionStorage.new(dev_builds_dir)

      final_builds_dir = build_directory('final')
      FileUtils.mkdir_p(final_builds_dir)
      @final_index = Versions::VersionsIndex.new(final_builds_dir)
      @final_storage = Versions::LocalVersionStorage.new(final_builds_dir)

      @final_resolver = Versions::VersionFileResolver.new(@final_storage, @blobstore)
    end

    attr_reader :resource

    def build_directory(mode)
      Pathname(@archive_dir).join(".#{mode}_builds", "#{artifact_type(resource, true)}", resource.name).to_s
    end

    def find_file(blobstore_id, sha1, version, desc)
      @final_resolver.find_file(blobstore_id, sha1, version, desc)
    end

    def lookup_final(artifact)
      @final_index[artifact.fingerprint]
    end

    def lookup_dev(artifact)
      @dev_index[artifact.fingerprint]
    end

    def has_dev?(version)
      @dev_storage.has_file?(version)
    end

    def get_dev(version)
      @dev_storage.get_file(version)
    end

    def upload_to_blobstore(f)
      @blobstore.create(f)
    end

    def update_final_version(artifact, item)
      @final_index.update_version(artifact.fingerprint, item)
    end

    def put(artifact, tmp_file, final)
      origin_file = tmp_file.path
      metadata = {'version' => artifact.fingerprint}

      if final
        tarball_path = install_into_final(artifact, metadata, origin_file)
      else
        tarball_path = install_into_dev(artifact, metadata, origin_file)
      end
      tarball_path
    end

    def install_into_dev(artifact, metadata, origin_file)
      # add version (with its validation) before adding sha1
      @dev_index.add_version(artifact.fingerprint, metadata)
      tarball_path = @dev_storage.put_file(artifact.fingerprint, origin_file)
      metadata['sha1'] = file_checksum(tarball_path)
      @dev_index.update_version(artifact.fingerprint, metadata)
      tarball_path
    end

    def install_into_final(artifact, metadata, origin_file)
      # add version (with its validation) before adding sha1
      @final_index.add_version(artifact.fingerprint, metadata)
      tarball_path = @final_storage.put_file(artifact.fingerprint, origin_file)
      metadata['sha1'] = file_checksum(tarball_path)
      @final_index.update_version(artifact.fingerprint, metadata)
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
  end
end
