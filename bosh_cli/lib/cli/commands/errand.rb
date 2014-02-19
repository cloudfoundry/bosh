require 'cli/client/errands_client'

module Bosh::Cli::Command
  class Errand < Base
    usage 'run errand'
    desc 'Run specified errand'
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

      title_prefix = "Errand `#{errand_name}' completed"
      exit_code_suffix = "(exit code #{errand_result.exit_code})"

      if errand_result.exit_code == 0
        say("#{title_prefix} successfully #{exit_code_suffix}".make_green)
      else
        err("#{title_prefix} with error #{exit_code_suffix}")
      end
    end
  end
end
