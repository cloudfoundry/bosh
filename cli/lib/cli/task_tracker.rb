# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module Cli
    # This class is responsible for tracking director tasks
    class TaskTracker

      MAX_POLLS = nil # not limited
      POLL_INTERVAL = 1 # second

      attr_reader :output

      # @param [Bosh::Cli::Director] director
      # @param [Integer] task_id
      # @param [Hash] options
      def initialize(director, task_id, options = {})
        @director = director
        @task_id = task_id
        @options = options

        @log_type = options[:log_type] || "event"
        @use_cache = options.key?(:use_cache) ? @options[:use_cache] : true

        @output = nil
        @cache = Config.cache
        @task = Bosh::Cli::DirectorTask.new(@director, @task_id, @log_type)

        if options[:raw_output]
          @renderer = Bosh::Cli::TaskLogRenderer.new
        else
          @renderer = Bosh::Cli::TaskLogRenderer.create_for_log_type(@log_type)
        end
      end

      # Tracks director task. Blocks until task is in one of the 'finished'
      # states (done, error, cancelled). Handles Ctrl+C by prompting to cancel
      # task.
      # @return [Symbol] Task status
      def track
        nl
        @renderer.time_adjustment = @director.get_time_difference
        say("Director task #{@task_id.to_s.yellow}")

        cached_output = get_cached_task_output

        if cached_output
          task_status = @task.state.to_sym
          output_received(cached_output)
          @renderer.refresh
        else
          task_status = poll
        end

        if task_status == :error && interactive? && @log_type != "debug"
          prompt_for_debug_log
        else
          print_task_summary(task_status)
        end

        save_task_output unless cached_output
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

          sleep(POLL_INTERVAL)
        end

        :unknown
      rescue Interrupt # Local ctrl-c handler
        prompt_for_task_cancel
      end

      def prompt_for_debug_log
        return unless interactive?
        nl
        confirm = ask("The task has returned an error status, " +
                        "do you want to see debug log? [Yn]: ")
        if confirm.empty? || confirm =~ /y(es)?/i
          self.class.new(@director, @task_id,
                         @options.merge(:log_type => "debug")).track
        else
          say("Please use 'bosh task #{@task_id}' command ".red +
                "to see the debug log".red)
        end
      end

      def prompt_for_task_cancel
        return unless interactive?
        nl
        confirm = ask("Do you want to cancel task #{@task_id}? [yN] " +
                        "(^C again to detach): ")

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
        say("Task #{@task_id} #{task_status.to_s.yellow}")

        if task_status == :done && @renderer.duration_known?
          say("Started\t\t#{@renderer.started_at.utc.to_s}")
          say("Finished\t#{@renderer.finished_at.utc.to_s}")
          say("Duration\t#{format_time(@renderer.duration).yellow}")
        end
      end

      private

      # @param [String] output Output received from director task
      def output_received(output)
        return if output.nil?
        @output ||= ""
        @output << output
        @renderer.add_output(output)
      end

      def finished?(state)
        %(done error cancelled).include?(state)
      end

      def interactive?
        Bosh::Cli::Config.interactive
      end

      def get_cached_task_output
        return nil unless @use_cache
        @cache.read(task_cache_key)
      end

      def save_task_output
        return nil unless @output && @use_cache
        @cache.write(task_cache_key, @output)
      end

      def task_cache_key
        "task/#{@director.uuid}/#{@task_id}/#{@log_type}"
      end

    end
  end
end