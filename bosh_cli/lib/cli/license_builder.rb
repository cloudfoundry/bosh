module Bosh::Cli
  class LicenseBuilder
    include PackagingHelper

    attr_reader :name, :version, :release_dir, :tarball_path

    # @param [String] directory Release directory
    # @param [Hash] options Build options
    def self.discover(directory, options = {})
      final = options[:final]
      blobstore = options[:blobstore]
      builder = new(directory, final, blobstore)

      [builder]
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
      expected_files = ['LICENSE', 'NOTICE']
      expected_paths = expected_files.map { |name| File.join(@release_dir, name) }
      actual = []

      expected_paths.each do |path|
        next unless File.file?(path)
        name = File.split(path).last
        base = File.basename(path)
        destination = File.join(build_dir, base)

        FileUtils.cp(path, destination, :preserve => true)
        actual << name
      end

      expected_files.each do |file|
        warn("Does not contain #{file} within #{@release_dir}") unless actual.include?(file)
      end

      actual.length
    end

    def build_dir
      @build_dir ||= Dir.mktmpdir
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

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end

  end
end

