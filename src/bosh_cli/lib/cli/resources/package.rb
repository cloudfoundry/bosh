module Bosh::Cli::Resources
  class Package
    BUILD_HOOK_FILES = ['packaging', 'pre_packaging']

    # We have two ways of getting/storing a package:
    # development versions of packages, kept in release directory
    # final versions of packages, kept in blobstore
    # development packages and their metadata should always be gitignored
    # final build tarballs should be ignored as well
    # final builds metadata should be checked in

    # @param [String] directory base Release directory
    def self.discover(release_base)
      Dir[File.join(release_base, 'packages', '*')].inject([]) do |packages, package_base|
        if File.directory?(package_base)
          packages << new(package_base, release_base)
        end
        packages
      end
    end

    attr_reader :package_base, :release_base

    def initialize(package_base, release_base)
      @release_base = Pathname.new(release_base)
      @package_base = Pathname.new(package_base)
    end

    def spec
      @spec ||= load_yaml_file(package_base.join('spec'))
    rescue
      raise Bosh::Cli::InvalidPackage, 'Package spec is missing'
    end

    def name
      spec['name']
    end

    def dependencies
      @dependencies ||= Array(spec['dependencies']).sort
    end

    def singular_type
      'package'
    end

    def plural_type
      'packages'
    end

    def files
      resolve_globs
      known_files = {}

      files = []
      files += resolved_globs.map do |match|
        known_files[match.path] = true
        [match.full_path, match.path]
      end

      BUILD_HOOK_FILES.each do |build_hook_file|
        source_file = package_base.join(build_hook_file)
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

    def validate!
      basename = File.basename(package_base.to_s)

      unless name == basename
        raise Bosh::Cli::InvalidPackage, "Found '#{name}' package in '#{basename}' directory, please fix it"
      end

      unless name.bosh_valid_id?
        raise Bosh::Cli::InvalidPackage, "Package name, '#{name}', should be a valid BOSH identifier"
      end

      unless spec['files'].is_a?(Array) && spec['files'].size > 0
        raise Bosh::Cli::InvalidPackage, "Package '#{name}' doesn't include any files"
      end

      resolve_globs
    end

    def additional_fingerprints
      dependencies
    end

    def format_fingerprint(digest, filename, name, file_mode)
      is_hook = BUILD_HOOK_FILES.include?(name)
      "%s%s%s" % [name, digest, is_hook ? '' : file_mode]
    end

    def run_script(script_name, *args)
      if BUILD_HOOK_FILES.include?(script_name.to_s)
        send(:"run_script_#{script_name}", *args)
      end
    end

    # ---

    private

    def excluded_files
      @excluded_files ||= Array(spec['excluded_files']).sort
    end

    # @return Array<Bosh::Cli::GlobMatch>
    def resolve_globs
      @resolved_globs ||= begin
        all_matches = Set.new

        spec['files'].each do |glob|
          glob_matches = Set.new
          src_matches = resolve_glob_in_dir(glob, release_src)
          glob_matches += src_matches.map { |path| Bosh::Cli::GlobMatch.new(release_src, path) }

          # Blobs directory is a little bit different: whatever matches a blob
          # will complement already found matches, unless this particular path
          # has already been matched. The GlobMatch class defines <=> to compare
          # path, thereby rejecting blobs if the file exists in src.
          if File.directory?(File.join(release_blobs))
            blob_matches = resolve_glob_in_dir(glob, release_blobs)
            glob_matches += blob_matches.map { |path| Bosh::Cli::GlobMatch.new(release_blobs, path) }
          end

          if glob_matches.empty?
            raise Bosh::Cli::InvalidPackage, "Package '#{name}' has a glob that resolves to an empty file list: #{glob}"
          end

          all_matches += glob_matches
        end

        all_matches.reject! do |match|
          excluded_files.detect { |excluded_glob| File.fnmatch(excluded_glob, match.path) }
        end

        all_matches.sort
      end
    end

    def resolve_glob_in_dir(glob, dir)
      Dir.chdir(dir) do
        Dir.glob(glob, File::FNM_DOTMATCH).reject do |fn|
          %w(. ..).include?(File.basename(fn))
        end
      end
    end

    def resolved_globs
      @resolved_globs
    end

    def release_src
      release_base.join('src')
    end

    def release_alt
      release_base.join('src_alt')
    end

    def release_blobs
      release_base.join('blobs')
    end

    def run_script_pre_packaging(staging_dir)
      pre_packaging_script = package_base.join('pre_packaging')

      if File.exists?(pre_packaging_script)
        say('Pre-packaging...')
        FileUtils.cp(pre_packaging_script, staging_dir, :preserve => true)

        old_env = ENV

        begin
          ENV.delete_if { |key, _| key[0, 7] == 'BUNDLE_' }
          if ENV['RUBYOPT']
            ENV['RUBYOPT'] = ENV['RUBYOPT'].sub('-rbundler/setup', '')
          end
          # todo: test these
          ENV['BUILD_DIR'] = staging_dir
          ENV['RELEASE_DIR'] = release_base.to_s
          Dir.chdir(staging_dir) do
            output = `bash -x pre_packaging 2>&1`

            unless $?.exitstatus == 0
              output.split("\n").each do |line|
                say("> #{line}")
              end
              raise Bosh::Cli::InvalidPackage, "'#{name}' pre-packaging failed"
            end
          end

        ensure
          ENV.delete('BUILD_DIR')
          old_env.each { |k, v| ENV[k] = old_env[k] }
        end

        FileUtils.rm(File.join(staging_dir, 'pre_packaging'))
      end
    end
  end
end
