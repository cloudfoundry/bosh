require "blobstore_client"

module Bosh::Cli

  class PackageBuilder

    attr_reader :name, :globs, :version, :dependencies, :tarball_path

    # We have two ways of getting/storing a package:
    # development versions of packages, kept in release directory
    # final versions of packages, kept in blobstore
    # development packages and their metadata should always be gitignored
    # final build tarballs should be ignored as well
    # final builds metadata should be checked in

    def initialize(spec, release_dir, final, blobstore, sources_dir = nil)
      spec = YAML.load_file(spec) if spec.is_a?(String) && File.file?(spec)

      @name         = spec["name"]
      @globs        = spec["files"]
      @dependencies = spec["dependencies"].is_a?(Array) ? spec["dependencies"] : []
      @release_dir  = release_dir
      @sources_dir  = sources_dir || File.join(@release_dir, "src")
      @final        = final
      @blobstore    = blobstore

      if @name.blank?
        raise InvalidPackage, "Package name is missing"
      end

      unless @name.bosh_valid_id?
        raise InvalidPackage, "Package name should be a valid Bosh identifier"
      end

      unless @globs.is_a?(Array) && @globs.size > 0
        raise InvalidPackage, "Package '#{@name}' doesn't include any files"
      end

      FileUtils.mkdir_p(metadata_dir)

      FileUtils.mkdir_p(dev_builds_dir)
      FileUtils.mkdir_p(final_builds_dir)

      @dev_packages   = VersionsIndex.new(dev_builds_dir)
      @final_packages = VersionsIndex.new(final_builds_dir)
    end

    def build
      use_final_version || use_dev_version || generate_tarball
      upload_tarball(@tarball_path) if final_build?
    end

    def final_build?
      @final
    end

    def checksum
      if @tarball_path && File.exists?(@tarball_path)
        Digest::SHA1.hexdigest(File.read(@tarball_path))
      else
        raise RuntimeError, "cannot read checksum for not yet generated package"
      end
    end

    def use_final_version
      say "Looking for final version of `#{name}'"
      package_attrs = @final_packages[fingerprint]

      if package_attrs.nil?
        say "Final version of `#{name}' not found"
        return nil
      end

      blobstore_id = package_attrs["blobstore_id"]
      version      = package_attrs["version"]

      if @final_packages.version_exists?(version)
        say "Found final version `#{name}' (#{version}) in local cache"
        @tarball_path = @final_packages.filename(version)
      else
        say "Fetching `#{name}' (final version #{version}) from blobstore (#{blobstore_id})"
        payload = @blobstore.get(blobstore_id)
        @tarball_path = @final_packages.add_version(fingerprint, package_attrs, payload)
      end

      @version = version
      true

    rescue Bosh::Blobstore::NotFound => e
      raise InvalidPackage, "Final version of `#{name}' not found in blobstore"
    rescue Bosh::Blobstore::BlobstoreError => e
      raise InvalidPackage, "Blobstore error: #{e}"
    end

    def use_dev_version
      say "Looking for dev version of `#{name}'"
      package_attrs = @dev_packages[fingerprint]

      if package_attrs.nil?
        say "Dev version of `#{name}' not found"
        return nil
      end

      version = package_attrs["version"]

      if @dev_packages.version_exists?(version)
        say "Found dev version `#{name}' (#{version})"
        @tarball_path   = @dev_packages.filename(version)
        @version        = version
        true
      else
        say "Tarball for `#{name}' (dev version `#{version}') not found"
        nil
      end
    end

    def generate_tarball
      major   = @final_packages.last_build
      minor   = @dev_packages.last_build + 1
      version = "#{major}.#{minor}-dev"

      tmp_file = Tempfile.new(name)

      say "Generating `#{name}' (dev version #{version})"

      copy_files
      pre_package

      in_build_dir do
        tar_out = `tar -czf #{tmp_file.path} . 2>&1`
        raise InvalidPackage, "Cannot create package tarball: #{tar_out}" unless $?.exitstatus == 0
      end

      payload = tmp_file.read

      package_attrs = {
        "version" => version,
        "sha1"    => Digest::SHA1.hexdigest(payload)
      }

      @dev_packages.add_version(fingerprint, package_attrs, payload)

      @tarball_path   = @dev_packages.filename(version)
      @version        = version

      say "Generated `#{name}' (dev version #{version}): `#{@tarball_path}'"
      true
    end

    def upload_tarball(path)
      package_attrs = @final_packages[fingerprint]

      if !package_attrs.nil?
        version = package_attrs["version"]
        say "`#{name}' (final version #{version}) already uploaded"
        return
      end

      version = @final_packages.last_build + 1
      payload = File.read(path)

      say "Uploading `#{path}' as `#{name}' (final version #{version})"

      blobstore_id = @blobstore.create(payload)

      package_attrs = {
        "blobstore_id" => blobstore_id,
        "sha1"         => Digest::SHA1.hexdigest(payload),
        "version"      => version
      }

      say "`#{name}' (final version #{version}) uploaded, blobstore id #{blobstore_id}"
      @final_packages.add_version(fingerprint, package_attrs, payload)
      @tarball_path = @final_packages.filename(version)
      @version      = version
      true
    rescue Bosh::Blobstore::BlobstoreError => e
      raise InvalidPackage, "Blobstore error: #{e}"
    end

    def reload # Mostly for tests
      @fingerprint    = nil
      @resolved_globs = nil
      self
    end

    def fingerprint
      @fingerprint ||= make_fingerprint
    end

    # lib/sphinx-0.9.tar.gz => lib/sphinx-0.9.tar.gz
    # but "cloudcontroller/lib/cloud.rb => lib/cloud.rb"
    def strip_package_name(filename)
      pos = filename.index(File::SEPARATOR)
      if pos && filename[0..pos-1] == @name
        filename[pos+1..-1]
      else
        filename
      end
    end

    def resolved_globs
      @resolved_globs ||= resolve_globs
    end
    alias_method :files, :resolved_globs

    def build_dir
      @build_dir ||= Dir.mktmpdir
    end

    def package_dir
      File.join(@release_dir, "packages", @name)
    end

    def metadata_dir
      File.join(package_dir, "data")
    end

    def dev_builds_dir
      File.join(@release_dir, ".dev_builds", "packages", name)
    end

    def final_builds_dir
      File.join(@release_dir, ".final_builds", "packages", name)
    end

    def copy_files
      copied = 0
      in_sources_dir do

        resolved_globs.each do |filename|
          destination = File.join(build_dir, strip_package_name(filename))

          if File.directory?(filename)
            FileUtils.mkdir_p(destination)
          else
            FileUtils.mkdir_p(File.dirname(destination))
            FileUtils.cp(filename, destination)
            copied += 1
          end
        end
      end

      in_metadata_dir do
        Dir["*"].each do |filename|
          destination = File.join(build_dir, filename)
          if File.exists?(destination)
            raise InvalidPackage, "Package '#{name}' has '#{filename}' file that conflicts with one of its metadata files"
          end
          FileUtils.cp(filename, destination)
          copied += 1
        end
      end

      copied
    end

    def pre_package
      pre_packaging_script = File.join(package_dir, "pre_packaging")

      if File.exists?(pre_packaging_script)

        say("Found pre-packaging script for `#{name}'")
        FileUtils.cp(pre_packaging_script, build_dir)

        old_env = ENV

        begin
          %w{ BUNDLE_GEMFILE RUBYOPT }.each { |key| ENV.delete(key) }
          ENV["BUILD_DIR"] = build_dir

          in_build_dir do
            system("bash -x pre_packaging 2>&1")
            raise InvalidPackage, "`#{name}' pre-packaging failed" unless $?.exitstatus == 0
          end

        ensure
          ENV.delete("BUILD_DIR")
          old_env.each { |k, v| ENV[k] = old_env[k] }
        end

        FileUtils.rm(File.join(build_dir, "pre_packaging"))
      end
    end

    private

    def make_fingerprint
      contents = ""
      # First, source files (+ permissions)
      in_sources_dir do
        contents << resolved_globs.sort.map { |file|
          "%s%s%s" % [ file, File.directory?(file) ? nil : File.read(file), File.stat(file).mode.to_s(8) ]
        }.join("")
      end
      # Second, metadata files (packaging, migrations, whatsoever)
      in_metadata_dir do
        contents << Dir["*"].sort.map { |file|
          "%s%s" % [ file, File.directory?(file) ? nil : File.read(file) ]
        }.join("")
      end

      # Third, data that won't be included to package but still affects it's behavior
      # (pre_packaging)
      in_package_dir do
        ["pre_packaging"].each do |file|
          contents << "%s%s" % [ file, File.read(file) ] if File.file?(file)
        end
      end

      Digest::SHA1.hexdigest(contents)
    end

    def resolve_globs
      in_sources_dir do
        @globs.map { |glob| Dir[glob] }.flatten.sort
      end
    end

    def in_sources_dir(&block)
      Dir.chdir(@sources_dir) { yield }
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end

    def in_metadata_dir(&block)
      Dir.chdir(metadata_dir) { yield }
    end

    def in_package_dir(&block)
      Dir.chdir(package_dir) { yield }
    end

  end
end
