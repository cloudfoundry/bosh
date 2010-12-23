module Bosh::Cli::Command
  class Release < Base
    include Bosh::Cli::DependencyHelper

    def verify(tarball_path)
      release = Bosh::Cli::Release.new(tarball_path)

      say("\nVerifying release...")
      release.validate
      say("\n")

      if release.valid?
        say("'%s' is a valid release" % [ tarball_path] )
      else
        say("'%s' is not a valid release:" % [ tarball_path] )
        for error in release.errors
          say("- %s" % [ error ])
        end
      end      
    end

    def upload(tarball_path)
      err("Please log in first") unless logged_in?
      err("Please choose target") unless target
      
      release = Bosh::Cli::Release.new(tarball_path)

      say("\nVerifying release...")
      release.validate
      say("\n")

      if !release.valid?
        err("Release is invalid, please fix, verify and upload again")
      end

      say("\nUploading release...\n")

      status, message = director.upload_release(tarball_path)

      responses = {
        :done          => "Release uploaded and updated",
        :non_trackable => "Uploaded release but director at #{target} doesn't support update tracking",
        :track_timeout => "Uploaded release but timed out out while tracking status",
        :error         => "Uploaded release but received an error while tracking status"
      }

      say responses[status] || "Cannot upload release: #{message}"
    end

    def create
      packages = []
      jobs = []

      if !in_release_dir?
        err "Sorry, your current directory doesn't look like release directory"
      end
      
      header "Building packages"
      Dir[File.join(work_dir, "packages", "*", "spec")].each do |package_spec|

        package = Bosh::Cli::PackageBuilder.new(package_spec, work_dir)
        say "Building #{package.name}..."
        package.build

        if package.new_version?
          say "Package '#{package.name}' generated"
          say "New version is #{package.version}"
        else
          say "Found previously generated version of '#{package.name}'"
          say "Version is #{package.version}"
        end
        
        packages << package
      end

      if packages.size > 0
        sorted_packages = tsort_packages(packages.inject({}) { |h, p| h[p.name] = p.dependencies; h })
        header "Resolving dependencies"
        say "Dependencies resolved, correct build order is:"
        for package_name in sorted_packages
          say("- %s" % [ package_name ])
        end
      end

      built_package_names = packages.map { |package| package.name }

      header "Building jobs"
      Dir[File.join(work_dir, "jobs", "*", "spec")].each do |job_spec|
        job = Bosh::Cli::JobBuilder.new(job_spec, work_dir, built_package_names)
        say "Building #{job.name}..."
        job.build
        jobs << job
      end

      release = Bosh::Cli::ReleaseBuilder.new(work_dir, packages, jobs)
      release.build

      say("Built release #{release.version} at '#{release.tarball_path}'")
    end

    private

    def in_release_dir?
      File.directory?("packages") && File.directory?("jobs") && File.directory?("src")
    end

  end
end
