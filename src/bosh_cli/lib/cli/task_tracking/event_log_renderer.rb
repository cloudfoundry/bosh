require 'forwardable'
require 'json'

module Bosh::Cli::TaskTracking
  class EventLogRenderer < TaskLogRenderer
    class InvalidEvent < StandardError; end

    extend Forwardable
    def_delegators :@total_duration, :duration, :duration_known?, :started_at, :finished_at

    def initialize
      super

      @printer = SmartWhitespacePrinter.new
      @total_duration = TotalDuration.new

      presenter = StageCollectionPresenter.new(@printer)

      @stage_collection = StageCollection.new(
        stage_started:  presenter.method(:start_stage),
        stage_finished: presenter.method(:finish_stage),
        stage_failed:   presenter.method(:fail_stage),

        task_started:   presenter.method(:start_task),
        task_finished:  presenter.method(:finish_task),
        task_failed:    presenter.method(:fail_task),
      )
    end

    alias_method :add_raw_output, :add_output

    def add_output(output)
      output.to_s.split("\n").each do |line|
        begin
          event = parse_event(line)
          add_event(event) if event
        rescue InvalidEvent => e
          @printer.print(:line_around, "Received invalid event: #{e.message}".make_red)
        end
      end

      add_raw_output(@printer.output)
    end

    def finish(state)
      @printer.finish
      add_raw_output(@printer.output)
      super
    end

    private

    def parse_event(event_line)
      return if event_line.start_with?('#')

      JSON.parse(event_line).tap do |result|
        unless result.kind_of?(Hash)
          raise InvalidEvent, "Hash expected, #{result.class} given"
        end
      end

    rescue JSON::JSONError => e
      raise InvalidEvent, "Invalid JSON: #{e.message}"
    end

    def add_event(event)
      unless event['time'] == 0
        @total_duration.started_at = event['time']
        @total_duration.finished_at = event['time']
      end

      if event['type'] == 'deprecation'
        show_deprecation(event)
      elsif event['type'] == 'warning'
        show_warning(event)
      elsif event['error']
        show_error(event)
      else
        show_stage_or_task(event)
      end
    end

    def show_warning(event)
      msg = "  Warning: #{event['message']}"
      @printer.print(:line_around, msg.make_yellow)
    end

    def show_deprecation(event)
      msg = "Deprecation: #{event['message']}"
      @printer.print(:line_around, msg.make_red)
    end

    def show_error(event)
      error   = event['error'] || {}
      code    = error['code']
      message = error['message']

      msg  = 'Error'
      msg += " #{code}" if code
      msg += ": #{message}" if message

      @printer.print(:line_around, msg.make_red)
    end

    REQUIRED_STAGE_EVENT_KEYS = %w(time stage task index total state).freeze

    def show_stage_or_task(event)
      REQUIRED_STAGE_EVENT_KEYS.each do |key|
        unless event.has_key?(key)
          raise InvalidEvent, "Missing event key: #{key}"
        end
      end

      @stage_collection.update_with_event(event)
    end
  end
end
