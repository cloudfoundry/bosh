# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class JobRename < Base
    include Bosh::Cli::DeploymentHelper

    def rename(*args)
      auth_required
      manifest_yaml = prepare_deployment_manifest(:yaml => true)
      manifest = YAML.load(manifest_yaml)

      args = args.dup
      force = args.delete("--force")
      old_name = args.shift
      new_name = args.shift

      say("You are about to rename #{old_name.green} to #{new_name.green}")

      unless confirmed?
        nl
        say("Job rename canceled".green)
        return
      end

      sanity_check_job_rename(manifest_yaml, old_name, new_name)

      status, _, director_msg = director.rename_job(manifest["name"], manifest_yaml,
                                      old_name, new_name, force)

      task_report(status, "Rename successful", director_msg)
    end

    def sanity_check_job_rename(manifest_yaml, old_name, new_name)

      # Makes sure the new deployment manifest contains the renamed job
      manifest = YAML.load(manifest_yaml)
      new_jobs = manifest["jobs"].map { |job| job["name"] }
      unless new_jobs.include?(new_name)
        err("Please update your deployment manifest to include the " +
            "new job name `#{new_name}'")
      end

      if new_jobs.include?(old_name)
        err("Old name `#{old_name}' is still being used in the " +
            "deployment file")
      end

      # Make sure that the old deployment manifest contains the old job
      current_deployment = director.get_deployment(manifest["name"])
      if current_deployment["manifest"].nil?
        err("Director could not find manifest for deployment " +
            "`#{manifest["name"]}'")
      end

      current_manifest = YAML.load(current_deployment["manifest"])
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
      manifest = YAML.load(manifest_yaml)
      if deployment_changed?(current_manifest.dup, manifest.dup)
        err("You cannot have any other changes to your manifest during " +
            "rename. Please revert the above changes and retry.")
      end
    end

  end
end
