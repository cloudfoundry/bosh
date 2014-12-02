module Bosh::Cli
  class LicenseBuilder
    include PackagingHelper

    attr_reader :name, :version, :release_dir, :tarball_path

    # @param [String] directory Release directory
    # @param [Hash] options Build options
    def self.discover(directory, options = {})
      builders = []

      unless File.exists?(File.join(directory, "LICENSE"))
        if File.exist?(File.join(directory, "..", "LICENSE"))
          say("copy LICENSE from root repo".make_green)
          FileUtils.copy(File.join(directory, "..", "LICENSE"), directory)
        else
          warn("Cannot find LICENSE in root of release.")
        end
      end

      unless File.exists?(File.join(directory, "NOTICE"))
        if File.exist?(File.join(directory, "..", "NOTICE"))
          say("copy NOTICE from root repo".make_green)
          FileUtils.copy(File.join(directory, "..", "NOTICE"), directory)
        else
          warn("Cannot find NOTICE in root of release.")
        end
      end

      final = options[:final]
      dry_run = options[:dry_run]
      blobstore = options[:blobstore]
      builder = new(directory, final, blobstore)

      builders << builder
      builders
    end

    def initialize(release_dir, final = false, blobstore)

      @name = "license"
      @version = nil
      @tarball_path = nil
      @final = final
      @release_dir = release_dir
      @blobstore = blobstore

      @license_dir = @release_dir
      @dev_builds_dir = File.join(@release_dir, ".dev_builds", @name)
      @final_builds_dir = File.join(@release_dir, ".final_builds", @name)

      FileUtils.mkdir_p(@dev_builds_dir)
      FileUtils.mkdir_p(@final_builds_dir)

#      FileUtils.copy(File.join(@license_dir, "LICENSE"), @dev_builds_dir)
#      FileUtils.copy(File.join(@license_dir, "LICENSE"), @final_builds_dir)

      init_indices
    end

    def fingerprint
      @fingerprint ||= make_fingerprint
    end

    def reload
      @fingerprint = nil
      @build_dir   = nil
      self
    end


    def copy_files
      copied = 0
      Dir.glob("#{@release_dir}/[a-zA-Z0-9]*").each do |license_file|
        next unless File.file?(license_file)
        license_src = File.join(license_file)
        basename = File.basename(license_src)
        license_dst = File.join(build_dir, basename)

        if File.exists?(license_dst)
          say("Already contains LICENSE/NOTICE. It will be overwritten.")
        end

        FileUtils.cp(license_src, license_dst, :preserve => true)
        copied += 1
      end

      warn("Does not contain LICENSE/NOTICE under #{@release_dir}")  unless copied != 0

      copied
    end

    private

    def make_fingerprint
      versioning_scheme = 2
      contents = "v#{versioning_scheme}"

      files = []
      Dir[File.join(@license_dir, "*")].each do |package_dir|
        next unless File.file?(package_dir)
        files << File.absolute_path(package_dir)
      end

      files.each do |filename|
        path = File.basename(filename)
        digest = Digest::SHA1.file(filename).hexdigest
        contents << "%s%s" % [path, digest]
      end

      Digest::SHA1.hexdigest(contents)
    end

    def build_dir
      @build_dir ||= Dir.mktmpdir
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end

  end
end

