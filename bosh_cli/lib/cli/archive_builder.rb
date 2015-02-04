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

      artifact = BuildArtifact.new(resource)
      with_indent('  ') do
        artifact.tarball_path = locate_tarball(resource, artifact) || generate_tarball(resource, artifact)
      end

      artifact.notes = notes
      artifact.new_version = new_version?

      upload_tarball(artifact) if final? && !dry_run?
      @will_be_promoted = true if final? && dry_run? && @used_dev_version

      artifact
    end

    def dry_run?
      @dry_run || !!options[:dry_run]
    end

    def final?
      @final ||= !!options[:final]
    end

    private

    def artifact_type(resource, plural = false)
      result = resource.class.name.split('::').last.downcase
      result += 's' if plural
      result
    end

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

    def locate_tarball(resource, artifact)
      use_final_version(resource, artifact) || use_dev_version(artifact)
    end

    def new_version?
      @tarball_generated || @promoted || @will_be_promoted
    end

    def notes
      if @will_be_promoted
        ["new final version #{@version}"]
      elsif new_version?
        ['new version']
      else
        []
      end
    end

    def use_final_version(resource, artifact)
      say('Final version:', ' ')

      item = @archive_repository.lookup_final(artifact)

      if item.nil?
        say('NOT FOUND'.make_red)
        return nil
      end

      blobstore_id = item['blobstore_id']
      version      = item['version'] || artifact.fingerprint
      sha1         = item['sha1']

      if blobstore_id.nil?
        say('No blobstore id'.make_red)
        return nil
      end

      desc = "#{resource.name} (#{version})"

      tarball_path = @archive_repository.find_file(blobstore_id, sha1, version, "package #{desc}")

      @version = version
      @used_final_version = true
      tarball_path
    rescue Bosh::Blobstore::NotFound
      raise BlobstoreError, "Final version of '#{name}' not found in blobstore"
    rescue Bosh::Blobstore::BlobstoreError => e
      raise BlobstoreError, "Blobstore error: #{e}"
    end

    def use_dev_version(artifact)
      say('Dev version:', '   ')
      metadata = @archive_repository.lookup_dev(artifact)

      if metadata.nil?
        say('NOT FOUND'.make_red)
        return nil
      end

      version = metadata['version'] || artifact.fingerprint

      unless @archive_repository.has_dev?(version)
        say('TARBALL MISSING'.make_red)
        return nil
      end

      say('FOUND LOCAL'.make_green)
      tarball_path = @archive_repository.get_dev(version)

      # TODO: move everything below here, as it's not actually about finding and using.
      if file_checksum(tarball_path) != metadata['sha1']
        say("'#{name} (#{version})' tarball corrupted".make_red)
        return nil
      end

      if final? && !dry_run?
        @archive_repository.install_into_final(artifact, metadata, tarball_path)
      end

      @version = version
      @used_dev_version = true
      tarball_path
    end

    def generate_tarball(resource, artifact)
      version = artifact.fingerprint
      tmp_file = Tempfile.new(artifact.name)

      say('Generating...')

      copy_files(resource)
      resource.run_script(:pre_packaging, staging_dir)

      in_staging_dir do
        tar_out = `tar -chzf #{tmp_file.path} . 2>&1`
        unless $?.exitstatus == 0
          raise PackagingError, "Cannot create tarball: #{tar_out}"
        end
      end

      # TODO: move everything below here, as it's not actually about generating a tarball.
      tarball_path = nil
      unless dry_run?
        tarball_path = @archive_repository.put(artifact, tmp_file, final?)
      end

      @version = version
      @tarball_generated = true
      say("Generated version #{version}".make_green)

      tarball_path
    end

    # TODO: move out of builder
    def upload_tarball(artifact)
      item = @archive_repository.lookup_final(artifact)

      unless item
        say("Failed to find entry '#{artifact.fingerprint}' in index, check local storage")
        return
      end

      if item['blobstore_id']
        return
      end

      say("Uploading final version '#{artifact.version}'...")

      blobstore_id = nil
      File.open(artifact.tarball_path, 'r') do |f|
        blobstore_id = @archive_repository.upload_to_blobstore(f)
      end

      say("Uploaded, blobstore id '#{blobstore_id}'")
      item['blobstore_id'] = blobstore_id
      @archive_repository.update_final_version(artifact, item)
      @promoted = true
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
