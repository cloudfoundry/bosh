module Bosh::Cli::TaskTracking
  class StageCollection
    attr_reader :stages

    def initialize(callbacks)
      @stages = []
      @callbacks = callbacks
    end

    def update_with_event(event)
      new_stage = Stage.new(event['stage'], event['tags'], event['total'], @callbacks)
      unless found_stage = @stages.find { |s| s.name == new_stage.name && s.tags == new_stage.tags }
        found_stage = new_stage
        @stages << new_stage
      end
      found_stage.update_with_event(event)
      found_stage
    end
  end

  class Stage
    attr_reader :name, :tags, :total, :tasks

    def initialize(name, tags, total, callbacks)
      @name = name
      @tags = Array(tags)
      @total = total
      @callbacks = callbacks
      @tasks = []
    end

    def update_with_event(event)
      new_task = Task.new(self, event['task'], event['progress'], @callbacks)
      unless found_task = @tasks.find { |t| t.name == new_task.name }
        found_task = new_task
        @tasks << new_task
      end
      found_task.update_with_event(event)
      found_task
    end
  end

  class Task
    attr_reader :stage, :name, :state, :progress, :error

    def initialize(stage, name, progress, callbacks)
      @stage = stage
      @name = name
      @progress = progress
      @callbacks = callbacks
      @total_duration = TotalDuration.new
    end

    def update_with_event(event)
      @state    = event['state']
      @progress = event['progress']
      @error    = (event['data'] || {})['error']

      @total_duration.started_at  = event['time'] if @state == 'started'
      @total_duration.finished_at = event['time'] if @state == 'finished'

      call_state_callback
    end

    def duration
      @total_duration.duration
    end

    private

    def call_state_callback
      callback = case @state
        when 'started'  then @callbacks[:task_started]
        when 'finished' then @callbacks[:task_finished]
        when 'failed'   then @callbacks[:task_failed]
      end
      callback.call(self) if callback
    end
  end
end
