require 'cli/client/errands_client'

module Bosh::Cli::Command
  class Errand < Base
    usage 'run errand'
    desc 'Run specified errand'
    option '--download-logs', 'download logs'
    option '--logs-dir destination_directory', String, 'logs download directory'
    def run_errand(errand_name)
      auth_required
      deployment_required

      deployment_name = prepare_deployment_manifest['name']

      errands_client = Bosh::Cli::Client::ErrandsClient.new(director)
      status, task_id, errand_result = errands_client.run_errand(deployment_name, errand_name)

      unless errand_result
        task_report(status, task_id, nil, "Errand `#{errand_name}' did not complete")
        return
      end

      nl

      say('[stdout]')
      say(errand_result.stdout.empty?? 'None' : errand_result.stdout)
      nl

      say('[stderr]')
      say(errand_result.stderr.empty?? 'None' : errand_result.stderr)
      nl

      if options[:download_logs] && errand_result.logs_blobstore_id
        logs_downloader = Bosh::Cli::LogsDownloader.new(director, self)
        logs_path = logs_downloader.build_destination_path(errand_name, 0, options[:logs_dir] || Dir.pwd)

        begin
          logs_downloader.download(errand_result.logs_blobstore_id, logs_path)
        rescue Bosh::Cli::CliError => e
          @download_logs_error = e
        end
      end

      title_prefix = "Errand `#{errand_name}'"
      exit_code_suffix = "(exit code #{errand_result.exit_code})"

      if errand_result.exit_code == 0
        say("#{title_prefix} completed successfully #{exit_code_suffix}".make_green)
      elsif errand_result.exit_code > 128
        err("#{title_prefix} was canceled #{exit_code_suffix}")
      else
        err("#{title_prefix} completed with error #{exit_code_suffix}")
      end

      raise @download_logs_error if @download_logs_error
    end
  end
end
