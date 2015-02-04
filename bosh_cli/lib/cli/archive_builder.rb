module Bosh::Cli
  class ArchiveBuilder
    attr_reader :options

    def initialize(archive_repository_provider, options = {})
      @archive_repository_provider = archive_repository_provider
      @options = options
    end

    def build(resource)
      @archive_repository = @archive_repository_provider.provide(resource)
      resource.run_script(:prepare)

      artifact = with_indent('  ') do
        locate_artifact(resource) || generate_tarball(resource)
      end

      upload_tarball(artifact) if final? && !dry_run?

      artifact
    end

    def dry_run?
      !!options[:dry_run]
    end

    def final?
      !!options[:final]
    end

    private

    def copy_files(resource)
      resource.files.each do |src, dest|
        dest_path = Pathname(staging_dir).join(dest)
        if File.directory?(src)
          FileUtils.mkdir_p(dest_path)
        else
          FileUtils.mkdir_p(dest_path.parent)
          FileUtils.cp(src, dest_path, :preserve => true)
        end
      end
    end

    def locate_artifact(resource)
      artifact = @archive_repository.lookup(resource)

      if artifact.nil?
        say("No artifact found for #{resource.name}".make_red)
        return nil
      end

      say("Found #{artifact.dev_artifact? ? 'dev' : 'final'} artifact for #{artifact.name}")

      if artifact.dev_artifact? && final? && !dry_run?
        artifact = @archive_repository.copy_from_dev_to_final(artifact)
      end

      artifact
    rescue Bosh::Cli::CorruptedArchive => e
      say "#{"Warning".make_red}: #{e.message}"
      nil
    end

    def generate_tarball(resource)
      tmp_file = Tempfile.new(resource.name)

      say('Generating...')

      copy_files(resource)
      resource.run_script(:pre_packaging, staging_dir)

      in_staging_dir do
        tar_out = `tar -chzf #{tmp_file.path} . 2>&1`
        unless $?.exitstatus == 0
          raise PackagingError, "Cannot create tarball: #{tar_out}"
        end
      end

      fingerprint = BuildArtifact.make_fingerprint(resource)

      # TODO: move everything below here, as it's not actually about generating a tarball.
      tarball_path = nil
      unless dry_run?
        tarball_path = @archive_repository.put(fingerprint, tmp_file, final?)
      end

      metadata = resource.metadata.merge({
          'fingerprint' => fingerprint,
          'version' => fingerprint,
          'tarball_path' => tarball_path,
          'sha1' => BuildArtifact.checksum(tarball_path),
          'notes' => ['new version'],
          'new_version' => true,
        })

      say("Generated version #{fingerprint}".make_green)
      BuildArtifact.new(resource.name, metadata, fingerprint, tarball_path, !final?)
    end

    # TODO: move out of builder
    def upload_tarball(artifact)
      metadata = artifact.metadata

      unless metadata
        say("Failed to find entry '#{artifact.fingerprint}' in index, check local storage")
        return
      end

      if metadata['blobstore_id']
        return
      end

      say("Uploading final version '#{artifact.version}'...")

      blobstore_id = nil
      File.open(artifact.tarball_path, 'r') do |f|
        blobstore_id = @archive_repository.upload_to_blobstore(f)
      end

      say("Uploaded, blobstore id '#{blobstore_id}'")
      metadata['blobstore_id'] = blobstore_id
      @archive_repository.update_final_version(artifact.fingerprint, metadata)

      true
    rescue Bosh::Blobstore::BlobstoreError => e
      raise BlobstoreError, "Blobstore error: #{e}"
    end

    def file_checksum(path)
      Digest::SHA1.file(path).hexdigest
    end

    def staging_dir
      @staging_dir ||= Dir.mktmpdir
    end

    def in_staging_dir
      Dir.chdir(staging_dir) { yield }
    end
  end
end
