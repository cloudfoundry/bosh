module Bosh::Director

  class CloudCheckManager
    include TaskHelper

    def scan_cloud(user, component)
      task = create_task(user, "Scan cloud for inconcistencies")
      Resque.enqueue(Jobs::CloudScan, task.id, component, :scan)
      task
    end

    def clean_cloud_errors(user, component)
      task = create_task(user, "Reset list of incidents")
      Resque.enqueue(Jobs::CloudScan, task.id, component, :reset)
      task
    end

    def list_avail_fix(user, error_id)
      task = create_task(user, "Evaluate possible solutions for error #{error_id}")
      Resque.enqueue(Jobs::CloudFix, task.id, 'list_solutions', error_id)
      task
    end

    def apply_fix(user, error_id, fix = nil)
      fix = 'fix_default' if fix.nil?

      # best effor to avoid calling random methods. Only allow methods that
      # starts with 'fix_'
      if fix[0,4] != 'fix_'
        raise InvalidRequest.new("Invalid fix #{fix}")
      end

      task = create_task(user, "Apply fix: #{fix} to error: #{error_id}")
      Resque.enqueue(Jobs::CloudFix, task.id, fix, error_id)
      task
    end
  end
end
