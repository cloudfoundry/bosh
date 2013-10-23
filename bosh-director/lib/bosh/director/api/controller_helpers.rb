module Bosh::Director
  module Api::ControllerHelpers
    def task_timeout?(task)
      # Some of the old task entries might not have the checkpoint_time
      unless task.checkpoint_time
        task.checkpoint_time = Time.now
        task.save
      end

      # If no checkpoint update in 3 cycles --> timeout
      (task.state == 'processing' || task.state == 'cancelling') &&
        (Time.now - task.checkpoint_time > Config.task_checkpoint_interval * 3)
    end

    def protected!
      unless authorized?
        response['WWW-Authenticate'] = 'Basic realm="BOSH Director"'
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && authenticate(*@auth.credentials)
    end

    def convert_job_instance_hash(hash)
      hash.reduce([]) do |jobs, kv|
        job, indicies = kv
        jobs + indicies.map { |index| [job, index] }
      end
    end
  end
end
