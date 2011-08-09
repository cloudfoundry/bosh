module Bosh::Cli
  class EventLogRenderer < TaskLogRenderer

    class InvalidEvent < StandardError; end

    attr_reader :current_stage
    attr_reader :events_count

    def initialize
      @lock = Monitor.new
      @events_count = 0
      @seen_stages = Set.new
      @out = Bosh::Cli::Config.output || $stdout
      @out.sync = true
      @buffer = StringIO.new
      @progress_bars = { }
      @pos = 0
      @tasks = Set.new
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
          stage_header += " %s" % [ tags.join(", ").green ]
        end

        unless @seen_stages.include?(stage_header)
          done_with_stage if @current_stage
          @current_stage = stage_header
          @event_start_time = Time.at(event["time"]) rescue Time.now
          @local_start_time = Time.now
          @seen_stages << @current_stage
          append_stage_header
        end

        if @current_stage == stage_header
          @events_count += 1
          @tasks << event["task"]
          append_event(event)
        end
      end

    rescue InvalidEvent => e
      # Swallow for the moment
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
          progress_bar.label = format_time(Time.now - @local_start_time)
          progress_bar.refresh
        end
        render
      end
    end

    def done
      return if @events_count == 0

      @lock.synchronize do
        @done = true
        done_with_stage
        render
      end
    end

    private

    def append_stage_header
      @buffer.print "\n#{@current_stage}\n"
    end

    def done_with_stage
      completion_time = \
      if @last_event
        Time.at(@last_event["time"]) rescue Time.now
      else
        Time.now
      end

      progress_bar.current = progress_bar.total
      progress_bar.title = "Done".green
      progress_bar.bar_visible = false
      progress_bar.label = format_time(completion_time - @event_start_time)
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
      @last_event = event
      progress_bar.total = event["total"]
      progress_bar.title = @tasks.to_a.join(", ").truncate(40)
      progress_bar.label = format_time(Time.now - @local_start_time)
      if event["state"] == "finished"
        @tasks.delete(event["task"])
        progress_bar.current += 1
        progress_bar.clear_line
        @buffer.puts("  #{event["task"].downcase.yellow}")
      end
      progress_bar.refresh

      @in_progress = true
    end

    def parse_event(event_line)
      event = JSON.parse(event_line)

      if event["time"] && event["stage"] && event["task"] && event["index"] && event["total"] && event["state"]
        event
      else
        raise InvalidEvent, "Invalid event structure: stage, time, task, index, total, state are all required"
      end

    rescue JSON::JSONError
      raise InvalidEvent, "Cannot parse event, invalid JSON"
    end

    def format_time(time)
      ts = time.to_i
      sprintf("%02d:%02d:%02d", ts / 3600, (ts / 60) % 60, ts % 60);
    end

  end

  class StageProgressBar
    attr_accessor :total
    attr_accessor :title
    attr_accessor :current
    attr_accessor :label
    attr_accessor :bar_visible

    def initialize(output, width = 100)
      @output = output
      @current = 0
      @total = 100
      @bar_visible = true
      @bar_width = 30 # characters
      @filler = "o"
    end

    def refresh
      clear_line
      bar_repr = @bar_visible ? bar : ""
      @output.print "#{@title.ljust(40)} #{bar_repr} #{@current}/#{@total}"
      @output.print " #{@label}" if @label
    end

    def bar
      n_fillers = (@bar_width * (@current.to_f / @total.to_f)).ceil
      fillers = "#{@filler}" * n_fillers
      spaces = " " * (@bar_width - n_fillers)
      "|#{fillers}#{spaces}|"
    end

    def clear_line
      @output.print("\r")
      @output.print(" " * 100)
      @output.print("\r")
    end

  end

end
