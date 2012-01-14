module Bosh::Cli

  class ReleaseBuilder
    include Bosh::Cli::DependencyHelper

    DEFAULT_RELEASE_NAME = "bosh_release"

    attr_reader :work_dir, :release, :packages, :jobs, :changed_jobs

    def initialize(work_dir, packages, jobs, options = { })
      @final    = options.has_key?(:final) ? !!options[:final] : false
      @work_dir = work_dir
      @release  = @final ? Release.final(@work_dir) : Release.dev(@work_dir)
      @packages = packages
      @jobs     = jobs

      @index = VersionsIndex.new(releases_dir, release_name)
      create_release_build_dir
    end

    def release_name
      name = @release.name
      name.blank? ? DEFAULT_RELEASE_NAME : name
    end

    def version
      @version ||= assign_version
    end

    def final?
      @final
    end

    def affected_jobs
      result = Set.new(@jobs.select { |job| job.new_version? })
      return result if @packages.empty?

      new_package_names = @packages.inject([]) do |list, package|
        list << package.name if package.new_version?
        list
      end

      @jobs.each do |job|
        result << job if (new_package_names & job.packages).size > 0
      end

      result.to_a
    end

    def build(options = {})
      options = { :generate_tarball => true }.merge(options)

      header("Generating manifest...")
      generate_manifest
      if options[:generate_tarball]
        header("Generating tarball...")
        generate_tarball
      end
      @build_complete = true
    end

    def copy_packages
      packages.each do |package|
        say "%-40s %s" % [ package.name.green, pretty_size(package.tarball_path) ]
        FileUtils.cp(package.tarball_path, File.join(build_dir, "packages", "#{package.name}.tgz"), :preserve => true)
      end
      @packages_copied = true
    end

    def copy_jobs
      jobs.each do |job|
        say "%-40s %s" % [ job.name.green, pretty_size(job.tarball_path) ]
        FileUtils.cp(job.tarball_path, File.join(build_dir, "jobs", "#{job.name}.tgz"), :preserve => true)
      end
      @jobs_copied = true
    end

    def generate_manifest
      manifest = {}
      manifest["packages"] = []

      manifest["packages"] = packages.map do |package|
        {
          "name"         => package.name,
          "version"      => package.version,
          "sha1"         => package.checksum,
          "dependencies" => package.dependencies
        }
      end

      manifest["jobs"] = jobs.map do |job|
        {
          "name"    => job.name,
          "version" => job.version,
          "sha1"    => job.checksum,
        }
      end

      manifest["name"] = release_name

      unless manifest["name"].bosh_valid_id?
        raise InvalidRelease, "Release name '%s' is not a valid Bosh identifier" % [ manifest["name"] ]
      end

      fingerprint = make_fingerprint(manifest)

      if @index[fingerprint]
        old_version = @index[fingerprint]["version"]
        say "This version is no different from version #{old_version}"
        @version = old_version
      else
        @version = assign_version
        @index.add_version(fingerprint, { "version" => @version })
      end

      manifest["version"] = @version
      manifest_yaml = YAML.dump(manifest)

      say "Writing manifest..."
      File.open(File.join(build_dir, "release.MF"), "w") do |f|
        f.write(manifest_yaml)
      end

      File.open(manifest_path, "w") do |f|
        f.write(manifest_yaml)
      end

      @manifest_generated = true
    end

    def generate_tarball
      generate_manifest unless @manifest_generated
      return if @index.version_exists?(@version)

      unless @jobs_copied
        header("Copying jobs...")
        copy_jobs
        nl
      end
      unless @packages_copied
        header("Copying packages...")
        copy_packages
        nl
      end

      FileUtils.mkdir_p(File.dirname(tarball_path))

      in_build_dir do
        `tar -czf #{tarball_path} . 2>&1`
        raise InvalidRelease, "Cannot create release tarball" unless $?.exitstatus == 0
        say "Generated #{tarball_path}"
      end
    end

    def releases_dir
       File.join(work_dir, final? ? "releases" : "dev_releases")
    end

    def tarball_path
      File.join(releases_dir, "#{release_name}-#{version}.tgz")
    end

    def manifest_path
      File.join(releases_dir, "#{release_name}-#{version}.yml")
    end

    def make_fingerprint(item)
      case item
      when Array
        source = item.map { |e| make_fingerprint(e) }.sort.join("")
      when Hash
        source = item.keys.sort.map{ |k| make_fingerprint(item[k]) }.join("")
      else
        source = item.to_s
      end
      Digest::SHA1.hexdigest(source)
    end

    private

    def version=(version)
      @version = version
    end

    def assign_version
      current_version = @index.latest_version.to_i
      current_version + 1
    end

    def build_dir
      @build_dir ||= Dir.mktmpdir
    end

    def create_release_build_dir
      in_build_dir do
        FileUtils.mkdir("packages")
        FileUtils.mkdir("jobs")
      end
    end

    def in_work_dir(&block)
      Dir.chdir(work_dir) { yield }
    end

    def in_build_dir(&block)
      Dir.chdir(build_dir) { yield }
    end

  end

end
