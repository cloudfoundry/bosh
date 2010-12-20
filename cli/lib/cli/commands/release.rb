module Bosh::Cli::Command
  class Release < Base

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
      # Release directory expectations:
      # releases/#{version}   Generated releases
      # packages/#{package_name}.pkg
      # packages/#{package_name}/{packaging,migrations,...} Package-specific files (will be bundled with package)
      # src/ Source code for packages

      # For each package:
        # If package has changed since last release, regenerate it (increment version)

      # For each job:
        # Check if all configuration files are present
        # Check if monit file is present
        # Check if update and restart scripts in job spec are present
        # Check if all referenced packages are present

      # Generate manifest
      # Generate bundle

      # Save bundle in releases/#{version}, create a git tag (?)

      Bosh::Cli::ReleaseBuilder.new(work_dir).build
    end
  end
end
