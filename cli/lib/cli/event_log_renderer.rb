# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class EventLogRenderer < TaskLogRenderer

    class InvalidEvent < StandardError; end

    class Task
      attr_accessor :name
      attr_accessor :progress
      attr_accessor :start_time
      attr_accessor :finish_time

      def initialize(name)
        @name = name
        @progress = 0
      end
    end

    attr_reader :current_stage
    attr_reader :events_count
    attr_reader :started_at, :finished_at

    def initialize
      @lock = Monitor.new
      @events_count = 0
      @seen_stages = Set.new
      @out = Bosh::Cli::Config.output || $stdout
      @out.sync = true
      @buffer = StringIO.new
      @progress_bars = { }
      @pos = 0
      @time_adjustment = 0
    end

    def add_output(output)
      output.to_s.split("\n").each do |line|
        add_event(line)
      end
    end

    def add_event(event)
      event = parse_event(event)

      @lock.synchronize do
        # One way to handle old stages is to prevent them
        # from appearing on screen altogether. That means
        # that we can always render the current stage only
        # and that simplifies housekeeping around progress
        # bars and messages. However we could always support
        # resuming the older stages rendering if we feel
        # that it's valuable.

        tags = event["tags"].is_a?(Array) ? event["tags"] : []
        stage_header = event["stage"]
        if tags.size > 0
          stage_header += " " + tags.sort.join(", ").green
        end

        unless @seen_stages.include?(stage_header)
          done_with_stage if @current_stage
          begin_stage(event, stage_header)
        end

        if @current_stage == stage_header
          append_event(event)
        end
      end

    rescue InvalidEvent => e
      # Swallow for the moment
    end

    def begin_stage(event, header)
      @current_stage = header
      @seen_stages << @current_stage

      @stage_start_time = Time.at(event["time"]) rescue Time.now
      @local_start_time = adjusted_time(@stage_start_time)

      @tasks = {}
      @done_tasks = []

      @eta = nil
      # Tracks max_in_flight best guess
      @tasks_batch_size = 0
      @batches_count = 0

      # Running average of task completion time
      @running_avg = 0

      append_stage_header
    end

    def render
      @lock.synchronize do
        @buffer.seek(@pos)
        output = @buffer.read
        @out.print output
        @pos = @buffer.tell
        output
      end
    end

    def refresh
      # This is primarily used to refresh timer
      # without advancing rendering buffer
      @lock.synchronize do
        if @in_progress
          progress_bar.label = time_with_eta(Time.now - @local_start_time, @eta)
          progress_bar.refresh
        end
        render
      end
    end

    def finish(state)
      return if @events_count == 0

      @lock.synchronize do
        @done = true
        done_with_stage(state)
        render
      end
    end

    def duration_known?
      @started_at && @finished_at
    end

    def duration
      return unless duration_known?
      @finished_at - @started_at
    end

    private

    def append_stage_header
      @buffer.print "\n#{@current_stage}\n"
    end

    def done_with_stage(state = "done")
      if @last_event
        completion_time = Time.at(@last_event["time"]) rescue Time.now
      else
        completion_time = Time.now
      end

      case state.to_s
      when "done"
        progress_bar.title = "Done".green
        progress_bar.finished_steps = progress_bar.total
      when "error"
        progress_bar.title = "Error".red
      else
        progress_bar.title = "Not done".yellow
      end

      progress_bar.bar_visible = false
      progress_bar.label = format_time(completion_time - @stage_start_time)
      progress_bar.refresh
      @buffer.print "\n"
      @in_progress = false
    end

    def progress_bar
      @progress_bars[@current_stage] ||= StageProgressBar.new(@buffer)
    end

    # We have to trust the first event in each stage
    # to have correct "total" and "current" fields.
    def append_event(event)
      progress = 0
      total = event["total"].to_i

      if event["state"] == "started"
        task = Task.new(event["task"])
      else
        task = @tasks[event["index"]]
      end

      event_data = event["data"] || {}
      # Ignoring out-of-order events
      return if task.nil?

      @events_count += 1
      @last_event = event

      case event["state"]
      when "started"
        begin
          task.start_time = Time.at(event["time"])
          # Treat first "started" event as task start time
          @started_at = task.start_time if @started_at.nil?
        rescue
          task.start_time = Time.now
        end

        task.progress = 0

        @tasks[event["index"]] = task

        if @tasks.size > @tasks_batch_size
          # Heuristics here: we assume that local maximum of
          # tasks number is a "max_in_flight" value and batches count
          # should only be recalculated once we refresh this maximum.
          # It's unlikely that the first task in a batch will be finished
          # before the last one is started so @done_tasks is expected
          # to only have canaries.
          @tasks_batch_size = @tasks.size
          @non_canary_event_start_time = task.start_time
          @batches_count = ((total - @done_tasks.size) /
              @tasks_batch_size.to_f).ceil
        end
      when "finished", "failed"
        @tasks.delete(event["index"])
        @done_tasks << task

        begin
          task.finish_time = @finished_at = Time.at(event["time"])
        rescue
          task.finish_time = Time.now
        end

        task_time = task.finish_time - task.start_time

        n_done_tasks = @done_tasks.size.to_f
        @running_avg = @running_avg * (n_done_tasks - 1) / n_done_tasks +
            task_time.to_f / n_done_tasks

        progress = 1
        progress_bar.finished_steps += 1
        progress_bar.label = time_with_eta(task_time, @eta)

        progress_bar.clear_line

        task_name = task.name.to_s
        if task_name !~ /^[A-Z]{2}/
          task_name = task_name[0..0].to_s.downcase + task_name[1..-1].to_s
        end

        if event["state"] == "failed"
          # TODO: truncate?
          status = [task_name.red, event_data["error"]].compact.join(": ")
        else
          status = task_name.yellow
        end
        @buffer.puts("  #{status} (#{format_time(task_time)})")
      when "in_progress"
        progress = [event["progress"].to_f / 100, 1].min
      end

      if @batches_count > 0 && @non_canary_event_start_time
        @eta = adjusted_time(@non_canary_event_start_time +
                                 @running_avg * @batches_count)
      end

      progress_bar_gain = progress - task.progress
      task.progress = progress

      progress_bar.total = total
      progress_bar.title = @tasks.values.map {|t| t.name }.sort.join(", ")

      progress_bar.current += progress_bar_gain
      progress_bar.refresh

      @in_progress = true
    end

    def parse_event(event_line)
      event = JSON.parse(event_line)

      if event["time"] && event["stage"] && event["task"] &&
          event["index"] && event["total"] && event["state"]
        event
      else
        raise InvalidEvent, "Invalid event structure: stage, time, task, " +
            "index, total, state are all required"
      end

    rescue JSON::JSONError
      raise InvalidEvent, "Cannot parse event, invalid JSON"
    end

    # Expects time and eta to be adjusted
    def time_with_eta(time, eta)
      time_fmt = format_time(time)
      eta_fmt = eta && eta > Time.now ? format_time(eta - Time.now) : "--:--:--"

      "#{time_fmt}  ETA: #{eta_fmt}"
    end

    def adjusted_time(time)
      time + @time_adjustment.to_f
    end
  end

  class StageProgressBar
    attr_accessor :total
    attr_accessor :title
    attr_accessor :current
    attr_accessor :label
    attr_accessor :bar_visible
    attr_accessor :finished_steps
    attr_accessor :terminal_width

    def initialize(output)
      @output = output
      @current = 0
      @total = 100
      @bar_visible = true
      @finished_steps = 0
      @filler = "o"
      @terminal_width = calculate_terminal_width
      @bar_width = (0.24 * @terminal_width).to_i # characters
    end

    def refresh
      clear_line
      bar_repr = @bar_visible ? bar : ""
      title_width = (0.35 * @terminal_width).to_i
      title = @title.truncate(title_width).ljust(title_width)
      @output.print "#{title} #{bar_repr} #{@finished_steps}/#{@total}"
      @output.print " #{@label}" if @label
    end

    def bar
      n_fillers = @total == 0 ? 0 : [(@bar_width *
          (@current.to_f / @total.to_f)).floor, 0].max

      fillers = "#{@filler}" * n_fillers
      spaces = " " * [(@bar_width - n_fillers), 0].max
      "|#{fillers}#{spaces}|"
    end

    def clear_line
      @output.print("\r")
      @output.print(" " * @terminal_width)
      @output.print("\r")
    end

    def calculate_terminal_width
      if !ENV["TERM"].blank?
        width = `tput cols`
        $?.exitstatus == 0 ? [width.to_i, 100].min : 80
      else
        80
      end
    rescue
      80
    end

  end

end
