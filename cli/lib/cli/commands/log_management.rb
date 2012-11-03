# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class LogManagement < Base
    include Bosh::Cli::DeploymentHelper

    # bosh logs
    usage "logs"
    desc "Fetch job or agent logs from a BOSH-managed VM"
    option "--agent", "fetch agent logs"
    option "--job", "fetch job logs"
    option "--only filter1,filter2,...", Array,
           "only fetch logs that satisfy",
           "given filters (defined in job spec)"
    option "--all", "fetch all files in the job or agent log directory"
    def fetch_logs(job, index)
      auth_required
      target_required
      no_track_unsupported

      if index !~ /^\d+$/
        err("Job index is expected to be a positive integer")
      end

      if options[:agent]
        if options[:job]
          err("You can't use --job and --agent together")
        end
        log_type = "agent"
      else
        log_type = "job"
      end

      if options[:only]
        if options[:all]
          err("You can't use --only and --all together")
        end
        filters = options[:only].join(",")
      elsif options[:all]
        filters = "all"
      else
        filters = nil
      end

      if options[:agent] && filters && filters != "all"
        err("Custom filtering is not supported for agent logs")
      end

      manifest = prepare_deployment_manifest

      resource_id = director.fetch_logs(
        manifest["name"], job, index, log_type, filters)

      if resource_id.nil?
        err("Error retrieving logs")
      end

      nl
      say("Downloading log bundle (#{resource_id.to_s.green})...")

      begin
        time = Time.now.strftime("%Y-%m-%d@%H-%M-%S")
        log_file = File.join(Dir.pwd, "#{job}.#{index}.#{time}.tgz")

        tmp_file = director.download_resource(resource_id)

        FileUtils.mv(tmp_file, log_file)
        say("Logs saved in `#{log_file.green}'")
      rescue Bosh::Cli::DirectorError => e
        err("Unable to download logs from director: #{e}")
      ensure
        FileUtils.rm_rf(tmp_file) if File.exists?(tmp_file)
      end

    end

  end
end

