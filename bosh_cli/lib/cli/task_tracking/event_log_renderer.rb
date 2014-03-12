require 'forwardable'
require 'stringio'
require 'json'

module Bosh::Cli::TaskTracking
  class EventLogRenderer < TaskLogRenderer
    class InvalidEvent < StandardError; end

    extend Forwardable
    def_delegators :@total_duration, :duration, :duration_known?, :started_at, :finished_at

    def initialize
      super
      @total_duration = TotalDuration.new
    end

    def add_output(output)
      @buffer = StringIO.new

      output.to_s.split("\n").each do |line|
        begin
          event = parse_event(line)
          add_event(event) if event
        rescue InvalidEvent => e
          @buffer.puts("Received invalid event: #{e.message}\n\n")
        end
      end

      super(@buffer.string)
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
      @total_duration.started_at = event['time']
      @total_duration.finished_at = event['time']

      if event['type'] == 'deprecation'
        show_deprecation(event)
      elsif event['error']
        show_error(event)
      else
        show_stage_or_task(event)
      end
    end

    def show_deprecation(event)
      msg = "Deprecation: #{event['message']}"
      @buffer.print("#{msg.make_red}\n\n")
    end

    def show_error(event)
      error   = event['error'] || {}
      code    = error['code']
      message = error['message']

      msg  = 'Error'
      msg += " #{code}" if code
      msg += ": #{message}" if message

      @buffer.print("#{msg.make_red}\n\n")
    end

    def show_stage_or_task(event)
      validate_stage_event(event)
      stage_collection.update_with_event(event)
    end

    REQUIRED_STAGE_EVENT_KEYS = %w(time stage task index total state).freeze

    def validate_stage_event(event)
      REQUIRED_STAGE_EVENT_KEYS.each do |key|
        unless event.has_key?(key)
          raise InvalidEvent, "Missing event key: #{key}"
        end
      end
    end

    def stage_collection
      @stage_collection ||= StageCollection.new(
        stage_started: ->(stage){
          @buffer.print("  Started #{header_for_stage(stage)}\n")
        },
        stage_finished: ->(stage){
          duration = stage.duration ? " (#{format_time(stage.duration)})" : ''
          @buffer.print("     Done #{header_for_stage(stage)}#{duration}\n\n")
        },
        stage_failed: ->(stage){
          duration = stage.duration ? " (#{format_time(stage.duration)})" : ''
          @buffer.print("   Failed #{header_for_stage(stage)}#{duration}\n")
        },

        task_started: ->(task){
          @buffer.print("  Started #{header_for_task(task)}\n")
        },
        task_finished: ->(task){
          duration = task.duration ? " (#{format_time(task.duration)})" : ''
          @buffer.print("     Done #{header_for_task(task)}#{duration}\n")
        },
        task_failed: ->(task){
          error_msg = task.error
          error_msg = ": #{error_msg.make_red}" if error_msg
          duration = task.duration ? " (#{format_time(task.duration)})" : ''
          @buffer.print("   Failed #{header_for_task(task)}#{duration}#{error_msg}\n")
        },
      )
    end

    def header_for_stage(stage)
      tags = stage.tags
      tags_str = tags.size > 0 ? ' ' + tags.sort.join(', ').make_green : ''
      "#{stage.name.downcase}#{tags_str}"
    end

    def header_for_task(task)
      tags = task.stage.tags
      tags_str = tags.size > 0 ? ' ' + tags.sort.join(', ').make_green : ''
      "#{task.stage.name.downcase}#{tags_str}: #{task.name}"
    end
  end
end
