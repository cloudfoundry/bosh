module Bosh::Cli

  class PackageBuilder
    include PackagingHelper

    attr_reader :name, :globs, :version, :dependencies, :tarball_path
    # We have two ways of getting/storing a package:
    # development versions of packages, kept in release directory
    # final versions of packages, kept in blobstore
    # development packages and their metadata should always be gitignored
    # final build tarballs should be ignored as well
    # final builds metadata should be checked in

    def initialize(spec, release_dir, final, blobstore, sources_dir = nil)
      spec = load_yaml_file(spec) if spec.is_a?(String) && File.file?(spec)

      @name          = spec["name"]
      @globs         = spec["files"]
      @dependencies  = spec["dependencies"].is_a?(Array) ? spec["dependencies"] : []
      @release_dir   = release_dir
      @sources_dir   = sources_dir || File.join(@release_dir, "src")
      @final         = final
      @blobstore     = blobstore
      @artefact_type = "package"

      @metadata_files = %w(packaging pre_packaging)

      if @name.blank?
        raise InvalidPackage, "Package name is missing"
      end

      unless @name.bosh_valid_id?
        raise InvalidPackage, "Package name should be a valid Bosh identifier"
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
      File.join(@release_dir, "packages", name)
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
            FileUtils.cp(filename, destination, :preserve => true)
            copied += 1
          end
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
            pre_packaging_out = `bash -x pre_packaging 2>&1`
            pre_packaging_out.split("\n").each do |line|
              say "> #{line}"
            end
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

      in_package_dir do
        @metadata_files.each do |file|
          contents << "%s%s" % [ file, File.read(file) ] if File.file?(file)
        end
      end

      contents << @dependencies.sort.join(",")

      Digest::SHA1.hexdigest(contents)
    end

    def resolve_globs
      in_sources_dir do
        @globs.map { |glob|
          matched_files = Dir.glob(glob, File::FNM_DOTMATCH).reject { |fn| [".", ".."].include?(File.basename(fn)) }
          if matched_files.size == 0
            raise InvalidPackage, "`#{name}' has a glob that resolves to an empty file list: #{glob}"
          end
          matched_files
        }.flatten.sort
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
