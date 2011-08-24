require "fileutils"
require "yaml"

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
      job_order = partial_order_sort(jobs.map{ |job| job.name }, @release.jobs_order)
      @jobs     = jobs.sort_by { |job| job_order.index(job.name) }

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

      header("Copying jobs...")
      copy_jobs
      header("Copying packages...")
      copy_packages
      header("Generating manifest...")
      generate_manifest
      if options[:generate_tarball]
        header("Generating tarball...")
        generate_tarball
      end
      header("Saving new version...")
      @build_complete = true
    ensure
      rollback unless @build_complete || @reused_old_version
    end

    def rollback
      header "Rolling back...".red
      say("\n")
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

      old_release = @index[fingerprint]
      unless old_release.nil?
        old_version = old_release["version"]
        say "Looks like this version is no different from version #{old_version}"
        if @index.version_exists?(old_version)
          @reused_old_version = true
          fn = @index.filename(old_version)
          say("Found matching version %s: %s, size is %s".green % [ old_version, fn, pretty_size(fn) ])
          quit
        else
          self.version = old_version
        end
      end

      manifest["version"] = version
      manifest_yaml = YAML.dump(manifest)

      say "Writing manifest..."
      File.open(File.join(build_dir, "release.MF"), "w") do |f|
        f.write(manifest_yaml)
      end

      File.open(manifest_path, "w") do |f|
        f.write(manifest_yaml)
      end

      @index.add_version(fingerprint, { "version" => version })
      @manifest_generated = true
    end

    def generate_tarball
      copy_packages unless @packages_copied
      copy_jobs unless @jobs_copied
      generate_manifest unless @manifest_generated

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
      @version=version
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
