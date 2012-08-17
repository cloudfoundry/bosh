# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class LogManagement < Base
    include Bosh::Cli::DeploymentHelper

    # usage  "logs <job> <index>"
    # desc   "Fetch job (default) or agent (if option provided) logs"
    # option "--agent", "fetch agent logs"
    # option "--only <filter1>[...]", "only fetch logs that satisfy " +
    #     "given filters (defined in job spec)"
    # option "--all", "fetch all files in the job or agent log directory"
    # route  :log_management, :fetch_logs
    def fetch_logs(*args)
      auth_required
      target_required

      job = args.shift
      index = args.shift
      filters = nil
      log_type = nil

      for_job = args.delete("--job")
      for_agent = args.delete("--agent")

      if for_job && for_agent
        err("Please specify which logs you want, job or agent")
      elsif for_agent
        log_type = "agent"
      else # default log type is 'job'
        log_type = "job"
      end

      if args.include?("--only")
        pos = args.index("--only")
        filters = args[pos+1]
        if filters.nil?
          err("Please provide a list of filters separated by comma")
        end
        args.delete("--only")
        args.delete(filters)
      elsif args.include?("--all")
        args.delete("--all")
        filters = "all"
      end

      if for_agent && !filters.nil? && filters != "all"
        err("Custom filtering is not supported for agent logs")
      end

      if index !~ /^\d+$/
        err("Job index is expected to be a positive integer")
      end

      if args.size > 0
        err("Unknown arguments: #{args.join(", ")}")
      end

      manifest = prepare_deployment_manifest

      resource_id = director.fetch_logs(manifest["name"], job, index,
                                        log_type, filters)

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

