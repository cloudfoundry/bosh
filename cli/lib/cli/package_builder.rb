# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class PackageBuilder
    include PackagingHelper

    class GlobMatch
      # Helper class encapsulating the data we know about the glob. We need
      # both directory and file path, as we match the same path in several
      # directories (src, src_alt, blobs)
      attr_reader :dir
      attr_reader :path

      def initialize(dir, path)
        @dir = dir
        @path = path
      end

      def full_path
        File.join(dir, path)
      end

      def <=>(other)
        @path <=> other.path
      end

      # GlobMatch will be used as Hash key (as implied by using Set),
      # hence we need to define both eql? and hash
      def eql?(other)
        @path == other.path
      end

      def hash
        @path.hash
      end
    end

    attr_reader :name, :globs, :version, :dependencies, :tarball_path
    # We have two ways of getting/storing a package:
    # development versions of packages, kept in release directory
    # final versions of packages, kept in blobstore
    # development packages and their metadata should always be gitignored
    # final build tarballs should be ignored as well
    # final builds metadata should be checked in

    def initialize(spec, release_dir, final, blobstore,
        sources_dir = nil, blobs_dir = nil, alt_src_dir = nil)
      spec = load_yaml_file(spec) if spec.is_a?(String) && File.file?(spec)

      @name = spec["name"]
      @globs = spec["files"]
      @dependencies = Array(spec["dependencies"])

      @release_dir = release_dir
      @sources_dir = sources_dir || File.join(@release_dir, "src")
      @alt_sources_dir = alt_src_dir || File.join(@release_dir, "src_alt")
      @blobs_dir = blobs_dir || File.join(@release_dir, "blobs")

      @final = final
      @blobstore = blobstore
      @artefact_type = "package"

      @metadata_files = %w(packaging pre_packaging)

      if @final && File.exists?(@alt_sources_dir)
        err("Please remove `#{File.basename(@alt_sources_dir)}' first")
      end

      if @name.blank?
        raise InvalidPackage, "Package name is missing"
      end

      unless @name.bosh_valid_id?
        raise InvalidPackage, "Package name should be a valid BOSH identifier"
      end

      unless @globs.is_a?(Array) && @globs.size > 0
        raise InvalidPackage, "Package '#{@name}' doesn't include any files"
      end

      @dev_builds_dir = File.join(@release_dir, ".dev_builds",
                                  "packages", @name)
      @final_builds_dir = File.join(@release_dir, ".final_builds",
                                    "packages", @name)

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

    def glob_matches
      @resolved_globs ||= resolve_globs
    end

    def build_dir
      @build_dir ||= Dir.mktmpdir
    end

    def package_dir
      File.join(@release_dir, "packages", name)
    end

    def copy_files
      copied = 0

      glob_matches.each do |match|
        destination = File.join(build_dir, match.path)

        if File.directory?(match.full_path)
          FileUtils.mkdir_p(destination)
        else
          FileUtils.mkdir_p(File.dirname(destination))
          FileUtils.cp(match.full_path, destination, :preserve => true)
          copied += 1
        end
      end

      in_package_dir do
        @metadata_files.each do |filename|
          destination = File.join(build_dir, filename)
          next unless File.exists?(filename)
          if File.exists?(destination)
            raise InvalidPackage, "Package '#{name}' has '#{filename}' file " +
              "which conflicts with BOSH packaging"
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
          ENV.delete_if { |key, _| key[0, 7] == "BUNDLE_" }
          if ENV["RUBYOPT"]
            ENV["RUBYOPT"] = ENV["RUBYOPT"].sub("-rbundler/setup", "")
          end
          ENV["BUILD_DIR"] = build_dir
          ENV["RELEASE_DIR"] = @release_dir
          in_build_dir do
            pre_packaging_out = `bash -x pre_packaging 2>&1`
            pre_packaging_out.split("\n").each do |line|
              say("> #{line}")
            end
            unless $?.exitstatus == 0
              raise InvalidPackage, "`#{name}' pre-packaging failed"
            end
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

      signatures = glob_matches.map do |match|
        file_digest = nil

        unless File.directory?(match.full_path)
          file_digest = Digest::SHA1.file(match.full_path).hexdigest
        end

        "%s%s%s" % [match.path, file_digest,
                    tracked_permissions(match.full_path)]
      end
      contents << signatures.join("")

      in_package_dir do
        @metadata_files.each do |file|
          if File.file?(file)
            file_digest = Digest::SHA1.file(file).hexdigest
            contents << "%s%s" % [file, file_digest]
          end
        end
      end

      contents << @dependencies.sort.join(",")

      Digest::SHA1.hexdigest(contents)
    end

    # @return Array<GlobMatch>
    def resolve_globs
      matches = Set.new

      @globs.each do |glob|
        # Alternative source dir completely shadows the source dir, there can be
        # no partial match of a particular glob in both.
        found = false

        [@alt_sources_dir, @sources_dir].each do |dir|
          next unless File.directory?(dir)

          Dir.chdir(dir) do
            dir_matches = resolve_glob_in_cwd(glob)

            unless dir_matches.empty?
              matches += dir_matches.map do |path|
                GlobMatch.new(dir, path)
              end
              found = true
            end
          end

          break if found
        end

        # Blobs directory is a little bit different: whatever matches a blob
        # will complement already found matches, unless this particular path
        # has already been matched.
        if File.directory?(File.join(@blobs_dir))
          Dir.chdir(@blobs_dir) do
            blob_matches = resolve_glob_in_cwd(glob)

            unless blob_matches.empty?
              blob_matches.each do |path|
                matches << GlobMatch.new(@blobs_dir, path)
              end

              found = true
            end
          end
        end

        unless found
          raise InvalidPackage, "`#{name}' has a glob that " +
            "resolves to an empty file list: #{glob}"
        end
      end

      matches.sort
    end

    def resolve_glob_in_cwd(glob)
      Dir.glob(glob, File::FNM_DOTMATCH).reject do |fn|
        %w(. ..).include?(File.basename(fn))
      end
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end

    def in_package_dir(&block)
      Dir.chdir(package_dir) { yield }
    end

  end
end
