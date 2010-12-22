require "fileutils"
require "yaml"
require "ostruct"

module Bosh::Cli

  class ReleaseBuilder

    attr_reader :work_dir, :version, :packages, :jobs

    def initialize(work_dir, packages, jobs)
      @work_dir = work_dir
      @packages = packages
      @jobs     = jobs
      @version  = assign_version
      create_release_build_dir
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
          "name"    => package.name,
          "version" => package.version,
          "sha1"    => package.tarball_checksum
        }
      end

      manifest["jobs"]    = jobs.map { |job| job.name }
      manifest["name"]    = "appcloud"
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

      in_build_dir do
        `tar -czf #{tarball_path} .`
        raise InvalidRelease, "Cannot create release tarball" unless $?.exitstatus == 0
        say "Generated #{tarball_path}"
      end
    end

    def tarball_path
      File.join(work_dir, "release-#{version}.tgz")
    end

    private

    def build_dir
      @build_dir ||= Dir.mktmpdir
    end

    def counter_file
      File.join(work_dir, "VERSION")
    end

    def save_version
      File.open(counter_file, "w") do |f|
        f.write(version)
      end
    end

    def assign_version
      if File.exists?(counter_file)
        File.read(counter_file).to_i + 1
      else
        1
      end
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
