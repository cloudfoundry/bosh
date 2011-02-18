require "fileutils"
require "yaml"

module Bosh::Cli

  class ReleaseBuilder
    include Bosh::Cli::DependencyHelper

    DEFAULT_RELEASE_NAME = "bosh_release"

    attr_reader :work_dir, :release, :packages, :jobs

    def initialize(work_dir, packages, jobs, final = false)
      @work_dir  = work_dir

      @release   = final ? Release.final(@work_dir) : Release.dev(@work_dir)
      @packages  = packages

      job_order  = partial_order_sort(jobs.map{ |job| job.name }, @release.jobs_order)

      @jobs      = jobs.sort_by { |job| job_order.index(job.name) }
      @final     = final

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

    def build
      header("Copying jobs...")
      copy_jobs
      header("Copying packages...")
      copy_packages
      header("Generating manifest...")
      generate_manifest
      header("Generating tarball...")
      generate_tarball
      header("Saving new version...")
      save_version
      @build_complete = true
    ensure
      rollback unless @build_complete
    end

    def rollback
      header "Rolling back...".red
      say("\n")
    end

    def copy_packages
      packages.each do |package|
        say "Copying #{package.tarball_path}..."
        FileUtils.cp(package.tarball_path, File.join(build_dir, "packages", "#{package.name}.tgz"))
      end
      @packages_copied = true
    end

    def copy_jobs
      jobs.each do |job|
        say "Copying #{job.tarball_path}..."
        FileUtils.cp(job.tarball_path, File.join(build_dir, "jobs", "#{job.name}.tgz"))
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

      manifest["version"] = version

      say "Writing manifest..."
      File.open(File.join(build_dir, "release.MF"), "w") do |f|
        f.write(YAML.dump(manifest))
      end

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

    def tarball_path
      dirname = final? ? "releases" : "dev_releases"
      File.join(work_dir, dirname, "#{release_name}-#{version}.tgz")
    end

    private

    def assign_version
      current_version = @release.version
      current_version.to_i + 1
    end

    def build_dir
      @build_dir ||= Dir.mktmpdir
    end

    def save_version
      @release.update_config(:version => version)
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
