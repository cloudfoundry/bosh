module Bosh::Cli

  class PackageBuilder
    include PackagingHelper
    include Bosh::Exec

    attr_reader :name, :globs, :version, :dependencies, :tarball_path
    # We have two ways of getting/storing a package:
    # development versions of packages, kept in release directory
    # final versions of packages, kept in blobstore
    # development packages and their metadata should always be gitignored
    # final build tarballs should be ignored as well
    # final builds metadata should be checked in

    def initialize(spec, release_dir, final, blobstore, sources_dir = nil, blobs_dir = nil)
      spec = load_yaml_file(spec) if spec.is_a?(String) && File.file?(spec)

      @name          = spec["name"]
      @globs         = spec["files"]
      @dependencies  = spec["dependencies"].is_a?(Array) ? spec["dependencies"] : []
      @release_dir   = release_dir
      @sources_dir   = sources_dir || File.join(@release_dir, "src")
      @blobs_dir     = blobs_dir || File.join(@release_dir, "blobs")
      @final         = final
      @blobstore     = blobstore
      @artefact_type = "package"

      @metadata_files = %w(packaging pre_packaging)

      if @name.blank?
        raise InvalidPackage, "Package name is missing"
      end

      unless @name.bosh_valid_id?
        raise InvalidPackage, "Package name should be a valid BOSH identifier"
      end

      unless @globs.is_a?(Array) && @globs.size > 0
        raise InvalidPackage, "Package '#{@name}' doesn't include any files"
      end

      @dev_builds_dir = File.join(@release_dir, ".dev_builds", "packages", @name)
      @final_builds_dir = File.join(@release_dir, ".final_builds", "packages", @name)

      FileUtils.mkdir_p(package_dir)
      FileUtils.mkdir_p(@dev_builds_dir)
      FileUtils.mkdir_p(@final_builds_dir)

      at_exit { FileUtils.rm_rf(build_dir) }

      init_indices
    end

    def reload # Mostly for tests
      @fingerprint    = nil
      @resolved_globs = nil
      init_indices
      self
    end

    def fingerprint
      @fingerprint ||= make_fingerprint
    end

    def resolved_globs
      @resolved_globs ||= resolve_globs
    end

    def source_files
      resolved_globs[:source]
    end

    def blob_files
      resolved_globs[:blob]
    end

    def files
      (resolved_globs[:blob] + resolved_globs[:source]).sort
    end

    def build_dir
      @build_dir ||= Dir.mktmpdir
    end

    def package_dir
      File.join(@release_dir, "packages", name)
    end

    def copy_files
      copied = 0

      files.each do |filename|
        file_path = get_file_path(filename)
        destination = File.join(build_dir, filename)

        if File.directory?(file_path)
          FileUtils.mkdir_p(destination)
        else
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp(file_path, destination, :preserve => true)
          copied += 1
        end
      end

      in_package_dir do
        @metadata_files.each do |filename|
          destination = File.join(build_dir, filename)
          next unless File.exists?(filename)
          if File.exists?(destination)
            raise InvalidPackage, "Package '#{name}' has '#{filename}' file which conflicts with BOSH packaging"
          end
          FileUtils.cp(filename, destination, :preserve => true)
          copied += 1
        end
      end

      pre_package
      copied
    end

    def pre_package
      pre_packaging_script = File.join(package_dir, "pre_packaging")

      if File.exists?(pre_packaging_script)

        say("Pre-packaging...")
        FileUtils.cp(pre_packaging_script, build_dir, :preserve => true)

        old_env = ENV

        begin
          %w{ BUNDLE_GEMFILE RUBYOPT }.each { |key| ENV.delete(key) }
          ENV["BUILD_DIR"] = build_dir

          in_build_dir do
            result = sh("bash -x pre_packaging 2>&1", true)
            result.stdout.split("\n").each do |line|
              say "> #{line}"
            end
          end

        rescue Bosh::Exec::Error
          raise InvalidPackage, "`#{name}' pre-packaging failed"
        ensure
          ENV.delete("BUILD_DIR")
          old_env.each { |k, v| ENV[k] = old_env[k] }
        end

        FileUtils.rm(File.join(build_dir, "pre_packaging"))
      end
    end

    private

    def get_file_path(file)
      file_path = File.join(@sources_dir, file)
      if !File.exists?(file_path)
        file_path = File.join(@blobs_dir, file)
        raise InvalidPackage, "#{file} cannot be found" if !File.exists?(file_path)
      end
      file_path
    end

    def make_fingerprint
      contents = ""

      signatures = files.map do |file|
        path = get_file_path(file)

        # TODO change fingerprint to use file checksum, not the raw contents
        "%s%s%s" % [ file, File.directory?(path) ? nil : File.read(path), tracked_permissions(path) ]
      end
      contents << signatures.join("")

      in_package_dir do
        @metadata_files.each do |file|
          contents << "%s%s" % [ file, File.read(file) ] if File.file?(file)
        end
      end

      contents << @dependencies.sort.join(",")

      Digest::SHA1.hexdigest(contents)
    end

    def resolve_globs
      glob_map = {:blob => [], :source => []}
      blob_list = []
      source_list = []

      @globs.each do |glob|
        matching_source = []
        matching_blob = []

        in_sources_dir do
          matching_source = Dir.glob(glob, File::FNM_DOTMATCH).reject { |fn| [".", ".."].include?(File.basename(fn)) }
        end

        in_blobs_dir do
          matching_blob = Dir.glob(glob, File::FNM_DOTMATCH).reject { |fn| [".", ".."].include?(File.basename(fn)) }
        end

        if matching_blob.size == 0 && matching_source.size ==0
          raise InvalidPackage, "`#{name}' has a glob that resolves to an empty file list: #{glob}"
        end

        blob_list << matching_blob
        source_list << matching_source
      end
      glob_map[:blob] = blob_list.flatten.sort
      glob_map[:source] = source_list.flatten.sort
      glob_map
    end

    def in_blobs_dir(&block)
      # old release does not have 'blob'
      if File.directory?(@blobs_dir)
        Dir.chdir(@blobs_dir) { yield }
      end
    end

    def in_sources_dir(&block)
      Dir.chdir(@sources_dir) { yield }
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end

    def in_package_dir(&block)
      Dir.chdir(package_dir) { yield }
    end

  end
end
