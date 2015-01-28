module Bosh::Cli::Resources
  class Package
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

    BUILD_HOOK_FILES = ['packaging', 'pre_packaging']


    # TEMP: backwards compatibility while refactoring archive building, etc.
    attr_accessor :fingerprint, :version, :checksum, :notes, :new_version, :tarball_path

    attr_reader :name, :globs, :dependencies
    # We have two ways of getting/storing a package:
    # development versions of packages, kept in release directory
    # final versions of packages, kept in blobstore
    # development packages and their metadata should always be gitignored
    # final build tarballs should be ignored as well
    # final builds metadata should be checked in

    # @param [String] directory Release directory
    # @param [Hash] options Package build options
    def self.discover(directory, options = {})
      packages = []

      Dir[File.join(directory, "packages", "*")].each do |package_source|
        next unless File.directory?(package_source)
        package_dirname = File.basename(package_source)
        package_spec = load_yaml_file(File.join(package_source, "spec"))

        if package_spec["name"] != package_dirname
          raise Bosh::Cli::InvalidPackage,
                "Found '#{package_spec["name"]}' package in " +
                  "'#{package_dirname}' directory, please fix it"
        end

        is_final = options[:final]
        dry_run = options[:dry_run]

        package = new(package_spec, directory, is_final)
        package.dry_run = true if dry_run

        packages << package
      end

      packages
    end


    def initialize(spec, release_source, final, sources_dir = nil, blobs_dir = nil, alt_src_dir = nil)
      spec = load_yaml_file(spec) if spec.is_a?(String) && File.file?(spec)

      @name = spec["name"]
      @globs = spec["files"]
      @excluded_globs = spec["excluded_files"] || []
      @dependencies = Array(spec["dependencies"])

      @release_source = release_source
      @sources_dir = sources_dir || File.join(@release_source, "src")
      @alt_sources_dir = alt_src_dir || File.join(@release_source, "src_alt")
      @blobs_dir = blobs_dir || File.join(@release_source, "blobs")

      @final = final

      if @final && File.exists?(@alt_sources_dir)
        err("Please remove '#{File.basename(@alt_sources_dir)}' first")
      end

      if @name.blank?
        raise Bosh::Cli::InvalidPackage, "Package name is missing"
      end

      unless @name.bosh_valid_id?
        raise Bosh::Cli::InvalidPackage, "Package name, '#{@name}', should be a valid BOSH identifier"
      end

      unless @globs.is_a?(Array) && @globs.size > 0
        raise Bosh::Cli::InvalidPackage, "Package '#{@name}' doesn't include any files"
      end
    end

    def final?
      @final
    end

    def new_version?
      @new_version
    end

    def artifact_type
      "package"
    end

    def format_fingerprint(digest, filename, name, file_mode)
      is_hook = BUILD_HOOK_FILES.include?(name)
      "%s%s%s" % [name, digest, is_hook ? '' : file_mode]
    end


    def files
      known_files = {}

      files = []
      files += glob_matches.map do |match|
        known_files[match.path] = true
        [match.full_path, match.path]
      end

      BUILD_HOOK_FILES.each do |build_hook_file|
        source_file = Pathname(package_source).join(build_hook_file)
        if source_file.exist?
          if known_files.has_key?(build_hook_file)
            raise Bosh::Cli::InvalidPackage, "Package '#{name}' has '#{build_hook_file}' file " +
                "which conflicts with BOSH packaging"
          end

          files << [source_file.to_s, build_hook_file]
        end
      end

      files
    end

    def dependencies
      @dependencies.sort
    end

    def pre_package(staging_dir)
      pre_packaging_script = File.join(package_source, "pre_packaging")

      if File.exists?(pre_packaging_script)
        say("Pre-packaging...")
        FileUtils.cp(pre_packaging_script, staging_dir, :preserve => true)

        old_env = ENV

        begin
          ENV.delete_if { |key, _| key[0, 7] == "BUNDLE_" }
          if ENV["RUBYOPT"]
            ENV["RUBYOPT"] = ENV["RUBYOPT"].sub("-rbundler/setup", "")
          end
          # todo: test these
          ENV["BUILD_DIR"] = staging_dir
          ENV["RELEASE_DIR"] = @release_source
          Dir.chdir(staging_dir) do
            pre_packaging_out = `bash -x pre_packaging 2>&1`
            unless $?.exitstatus == 0
              pre_packaging_out.split("\n").each do |line|
                say("> #{line}")
              end
              raise Bosh::Cli::InvalidPackage, "'#{name}' pre-packaging failed"
            end
          end

        ensure
          ENV.delete("BUILD_DIR")
          old_env.each { |k, v| ENV[k] = old_env[k] }
        end

        FileUtils.rm(File.join(staging_dir, "pre_packaging"))
      end
    end

    private


    def glob_matches
      @resolved_globs ||= resolve_globs
    end

    # @return Array<GlobMatch>
    def resolve_globs
      all_matches = Set.new

      @globs.each do |glob|
        matches = Set.new

        src_matches = resolve_glob_in_dir(glob, @sources_dir)
        src_alt_matches = []
        if File.directory?(@alt_sources_dir)
          src_alt_matches = resolve_glob_in_dir(glob, @alt_sources_dir)
        end

        # Glob like core/dea/**/* might not yield anything in alt source even
        # when 'src_alt/core' exists. That's error prone, so we don't lookup
        # in 'src' if 'src_alt' contains any part of the glob hierarchy.
        top_dir = glob.split(File::SEPARATOR)[0]
        top_dir_in_src_alt_exists = top_dir && File.exists?(File.join(@alt_sources_dir, top_dir))

        if top_dir_in_src_alt_exists && src_alt_matches.empty? && src_matches.any?
          raise Bosh::Cli::InvalidPackage, "Package '#{name}' has a glob that " +
            "doesn't match in '#{File.basename(@alt_sources_dir)}' " +
            "but matches in '#{File.basename(@sources_dir)}'. " +
            "However '#{File.basename(@alt_sources_dir)}/#{top_dir}' " +
            "exists, so this might be an error."
        end

        # First add src_alt matches since src_alt takes priority over src matches
        matches += src_alt_matches.map { |path| GlobMatch.new(@alt_sources_dir, path) }

        # Only add if top-level-dir does not exist in src_alt. No partial matches.
        if !top_dir_in_src_alt_exists
          matches += src_matches.map { |path| GlobMatch.new(@sources_dir, path) }
        end

        # Blobs directory is a little bit different: whatever matches a blob
        # will complement already found matches, unless this particular path
        # has already been matched.
        if File.directory?(File.join(@blobs_dir))
          resolve_glob_in_dir(glob, @blobs_dir).each { |path| matches << GlobMatch.new(@blobs_dir, path) }
        end

        if matches.empty?
          raise Bosh::Cli::InvalidPackage, "Package '#{name}' has a glob that resolves to an empty file list: #{glob}"
        end

        all_matches += matches
      end

      all_matches.reject! do |match|
        @excluded_globs.detect { |excluded_glob| File.fnmatch(excluded_glob, match.path) }
      end
      all_matches.sort
    end

    def resolve_glob_in_dir(glob, dir)
      Dir.chdir(dir) do
        Dir.glob(glob, File::FNM_DOTMATCH).reject do |fn|
          %w(. ..).include?(File.basename(fn))
        end
      end
    end

    def package_source
      File.join(@release_source, 'packages', name)
    end
  end
end
