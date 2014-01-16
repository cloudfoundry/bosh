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
      fire_started_callback(event)
      found_task.update_with_event(event)
      fire_finished_callback(event)
      fire_failed_callback(event)
      found_task
    end

    def duration
      total_duration = TotalDuration.new

      task_start_times = @tasks.map(&:started_at)
      task_end_times = @tasks.map(&:finished_at)

      # If any task start time is nil, the start time for the entire stage is unknown.
      total_duration.started_at = task_start_times.min unless task_start_times.include?(nil)
      total_duration.finished_at = task_end_times.max unless task_end_times.include?(nil)

      total_duration.duration
    end

    private

    def fire_started_callback(event)
      if event['state'] == 'started' && event['index'] == 1
        callback = @callbacks[:stage_started]
        callback.call(self) if callback
      end
    end

    def fire_finished_callback(event)
      if event['state'] == 'finished' && ((event['index'] == event['total']) || event['total'].nil?)
        callback = @callbacks[:stage_finished]
        callback.call(self) if callback
      end
    end

    def fire_failed_callback(event)
      if event['state'] == 'failed'
        # If there are multiple failures do we need to only fire on the first one?
        callback = @callbacks[:stage_failed]
        callback.call(self) if callback
      end
    end
  end

  class Task
    attr_reader :stage, :name, :state, :progress, :error

    extend Forwardable
    def_delegators :@total_duration, :duration, :started_at, :finished_at

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
      @total_duration.finished_at = event['time'] if @state == 'finished' || @state == 'failed'

      call_state_callback
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
