module Bosh::Cli::TaskTracking
  # This class is responsible for tracking director tasks
  class TaskTracker
    MAX_POLLS = nil # not limited
    DEFAULT_POLL_INTERVAL = 1 # second

    attr_reader :output
    attr_reader :renderer

    # @param [Bosh::Cli::Client::Director] director
    # @param [Integer] task_id
    # @param [Hash] options
    def initialize(director, task_id, options = {})
      @director = director
      @task_id = task_id
      @task_finished_states = 'done error cancelled'
      if(options[:task_success_state])
        @task_finished_states << options[:task_success_state].to_s
      end
      @options = options

      @quiet = !!options[:quiet]
      default_log_type = @quiet ? 'none' : 'event'

      @log_type = options[:log_type] || default_log_type

      @output = nil
      @task = Bosh::Cli::DirectorTask.new(@director, @task_id, @log_type)

      if options[:renderer]
        @renderer = options[:renderer]
      elsif options[:raw_output]
        @renderer = TaskLogRenderer.new
      else
        @renderer = TaskLogRenderer.create_for_log_type(@log_type)
      end

      @poll_interval = Bosh::Cli::Config.poll_interval || DEFAULT_POLL_INTERVAL
    end

    # Tracks director task. Blocks until task is in one of the 'finished'
    # states (done, error, cancelled). Handles Ctrl+C by prompting to cancel
    # task.
    # @return [Symbol] Task status
    def track
      nl
      @renderer.time_adjustment = @director.get_time_difference
      say("Director task #{@task_id.to_s.make_yellow}")
      task_status = poll

      print_task_summary(task_status)

      task_status
    end

    def poll
      polls = 0

      while true
        polls += 1
        state = @task.state
        output = @task.output

        output_received(output)
        @renderer.refresh

        if finished?(state)
          return state.to_sym
        elsif MAX_POLLS && polls >= MAX_POLLS
          return :track_timeout
        end

        sleep(@poll_interval)
      end

      :unknown
    rescue Interrupt # Local ctrl-c handler
      prompt_for_task_cancel
    end

    def prompt_for_debug_log
      return unless interactive?
      nl
      confirm = ask('The task has returned an error status, ' +
        'do you want to see debug log? [Yn]: ')
      if confirm.empty? || confirm =~ /y(es)?/i
        self.class.new(@director, @task_id,
                       @options.merge(:log_type => 'debug')).track
      else
        say("Please use 'bosh task #{@task_id}' command ".make_red +
              'to see the debug log'.make_red)
      end
    end

    def prompt_for_task_cancel
      return unless interactive?
      nl
      confirm = ask("Do you want to cancel task #{@task_id}? [yN] " +
        '(^C again to detach): ')

      if confirm =~ /y(es)?/i
        say("Cancelling task #{@task_id}...")
        @director.cancel_task(@task_id)
      end

      poll
    rescue Interrupt
      nl
      err("Task #{@task_id} is still running")
    end

    def print_task_summary(task_status)
      output_received(@task.flush_output)
      @renderer.finish(task_status)

      nl
      say("Task #{@task_id} #{task_status.to_s.make_yellow}")

      if task_status == :done && @renderer.duration_known?
        nl
        say("Started\t\t#{@renderer.started_at.utc.to_s}")
        say("Finished\t#{@renderer.finished_at.utc.to_s}")
        say("Duration\t#{format_time(@renderer.duration).make_yellow}")
      end
    end

    private

    def nl
      super unless @quiet
    end

    def say(*args)
      super unless @quiet
    end

    # @param [String] output Output received from director task
    def output_received(output)
      return if output.nil?
      @output ||= ''
      @output << output
      @renderer.add_output(output)
    end

    def finished?(state)
      @task_finished_states.include?(state)
    end

    def interactive?
      Bosh::Cli::Config.interactive
    end
  end
end
