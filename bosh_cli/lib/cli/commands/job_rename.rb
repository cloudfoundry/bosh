module Bosh::Cli::Command
  class JobRename < Base
    # bosh rename
    usage "rename job"
    desc "Renames a job. NOTE, your deployment manifest must also be " +
         "updated to reflect the new job name."
    option "--force", "Ignore errors"
    def rename(old_name, new_name)
      auth_required
      manifest = prepare_deployment_manifest(show_state: true)

      force = options[:force]
      say("You are about to rename `#{old_name.make_green}' to `#{new_name.make_green}'")

      unless confirmed?
        nl
        say("Job rename canceled".make_green)
        exit(0)
      end

      sanity_check_job_rename(manifest, old_name, new_name)

      status, task_id = director.rename_job(
        manifest.name, manifest.yaml, old_name, new_name, force)

      task_report(status, task_id, "Rename successful")
    end

    def sanity_check_job_rename(manifest, old_name, new_name)
      # Makes sure the new deployment manifest contains the renamed job
      new_jobs = manifest.hash["jobs"].map { |job| job["name"] }
      unless new_jobs.include?(new_name)
        err("Please update your deployment manifest to include the " +
            "new job name `#{new_name}'")
      end

      if new_jobs.include?(old_name)
        err("Old name `#{old_name}' is still being used in the " +
            "deployment file")
      end

      # Make sure that the old deployment manifest contains the old job
      current_deployment = director.get_deployment(manifest.name)
      if current_deployment["manifest"].nil?
        err("Director could not find manifest for deployment " +
            "`#{manifest["name"]}'")
      end

      current_manifest = Psych.load(current_deployment["manifest"])
      jobs = current_manifest["jobs"].map { |job| job["name"] }
      unless jobs.include?(old_name)
        err("Trying to rename a non existent job `#{old_name}'")
      end

      # Technically we could allow this
      if jobs.include?(new_name)
        err("Trying to reuse an existing job name `#{new_name}' " +
            "to rename job `#{old_name}'")
      end

      # Make sure that only one job has been renamed
      added_jobs = new_jobs - jobs

      if added_jobs.size > 1
        err("Cannot rename more than one job, you are trying to " +
            "add #{added_jobs.inspect}")
      end

      if added_jobs.first != new_name
        err("Manifest does not include new job `#{new_name}'")
      end

      renamed_jobs = jobs - new_jobs

      if renamed_jobs.size > 1
        err("Cannot rename more than one job, you have changes to " +
            "#{renamed_jobs}")
      end

      if renamed_jobs.first != old_name
        err("Manifest does not rename old job `#{old_name}'")
      end

      # Final sanity check, make sure that no
      # other properties or anything other than the names
      # have changed. So update current manifest with new name
      # and check that it matches with the old manifest
      current_manifest["jobs"].each do |job|
        if job["name"] == old_name
          job["name"] = new_name
          break
        end
      end

      # Now the manifests should be the same
      if deployment_changed?(current_manifest.dup, manifest.hash.dup)
        err("You cannot have any other changes to your manifest during " +
            "rename. Please revert the above changes and retry.")
      end
    end

  end
end
