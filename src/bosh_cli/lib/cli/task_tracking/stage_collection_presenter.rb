module Bosh::Cli::TaskTracking
  class StageCollectionPresenter
    JUSTIFY = 9

    def initialize(printer)
      @printer = printer
      @last_stage = nil
      @last_task = nil
    end

    def start_stage(stage)
      msg_new_line = "  Started #{header_for_stage(stage)}"

      # Assume that duplicate start events are never received
      if stage.similar?(@last_stage)
        @printer.print(:before, msg_new_line)
      else
        @printer.print(:line_before, msg_new_line)
      end

      @last_stage = stage
      @last_task = nil
    end

    def finish_stage(stage)
      end_stage(stage, 'Done')
    end

    def fail_stage(stage)
      end_stage(stage, 'Failed')
    end

    def end_stage(stage, prefix_msg)
      duration = duration_str(stage)
      msg = "#{prefix_msg.rjust(JUSTIFY)} #{header_for_stage(stage)}#{duration}"

      if stage == @last_stage
        if stage.total == 1
          # end_task added inline end message
        else
          @printer.print(:before, msg)
        end
      else
        @printer.print(:line_before, msg)
      end

      @last_stage = stage
      @last_task = nil
    end

    def start_task(task)
      msg = "  Started #{full_header_for_task(task)}"

      if task.stage == @last_stage && task.stage.total == 1
        @printer.print(:none, " > #{task.name.make_green}")
      elsif task.stage.similar?(@last_stage)
        @printer.print(:before, msg)
      else
        @printer.print(:line_before, msg)
      end

      @last_stage = task.stage
      @last_task = task
    end

    def finish_task(task)
      end_task(task, 'Done', nil)
    end

    def fail_task(task)
      error_msg = task.error
      error_msg = ": #{error_msg.make_red}" if error_msg

      end_task(task, 'Failed', error_msg)
    end

    def end_task(task, prefix_msg, suffix_msg)
      duration = duration_str(task)
      msg = "#{prefix_msg.rjust(JUSTIFY)} #{full_header_for_task(task)}#{suffix_msg}#{duration}"

      if task == @last_task
        @printer.print(:none, ". #{prefix_msg}#{suffix_msg}#{duration}")
      elsif task.stage.similar?(@last_stage)
        @printer.print(:before, msg)
      else
        @printer.print(:line_before, msg)
      end

      @last_stage = task.stage
      @last_task = task
    end

    private

    def header_for_stage(stage)
      "#{stage.name.downcase}#{tags_for_stage(stage)}"
    end

    def full_header_for_task(task)
      "#{task.stage.name.downcase}#{tags_for_stage(task.stage)} > #{task.name.make_green}"
    end

    def tags_for_stage(stage)
      stage.tags.size > 0 ? ' ' + stage.tags.sort.join(', ').make_green : ''
    end

    def duration_str(stage_or_task)
      stage_or_task.duration ? " (#{format_time(stage_or_task.duration)})" : ''
    end
  end
end
