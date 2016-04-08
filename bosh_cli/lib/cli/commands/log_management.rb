module Bosh::Cli::Command
  class LogManagement < Base
    # bosh logs
    usage 'logs'
    desc 'Fetch job or agent logs from a BOSH-managed VM'
    option '--agent', 'fetch agent logs'
    option '--job', 'fetch job logs'
    option '--only filter1,filter2,...', Array,
           'only fetch logs that satisfy',
           'given filters (defined in job spec)'
    option '--dir destination_directory', String, 'download directory'
    option '--all', 'deprecated'

    def fetch_logs(job, index_or_id)
      auth_required

      manifest = prepare_deployment_manifest(show_state: true)
      check_arguments

      logs_downloader = Bosh::Cli::LogsDownloader.new(director, self)

      resource_id = fetch_log_resource_id(manifest.name, index_or_id, job)
      logs_path = logs_downloader.build_destination_path(job, index_or_id, options[:dir] || Dir.pwd)
      logs_downloader.download(resource_id, logs_path)
    end

    private

    def fetch_log_resource_id(deployment_name, index_or_id, job)
      resource_id = director.fetch_logs(deployment_name, job, index_or_id, log_type, filters)
      err('Error retrieving logs') if resource_id.nil?

      resource_id
    end

    def agent_logs_wanted?
      options[:agent]
    end

    def job_logs_wanted?
      options[:job]
    end

    def check_arguments
      no_track_unsupported

      if agent_logs_wanted? && options[:only]
        err('Custom filtering is not supported for agent logs')
      end
    end

    def log_type
      err("You can't use --job and --agent together") if job_logs_wanted? && agent_logs_wanted?

      if agent_logs_wanted?
        'agent'
      else
        'job'
      end
    end

    def filters
      if options[:only]
        err("You can't use --only and --all together") if options[:all]
        filter = options[:only].join(',')
      elsif options[:all]
        filter = nil
        say("Warning: --all flag is deprecated and has no effect.".make_red)
      else
        filter = nil
      end
      filter
    end
  end
end
