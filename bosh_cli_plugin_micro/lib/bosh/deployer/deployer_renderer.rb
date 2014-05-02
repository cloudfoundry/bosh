module Bosh::Deployer
  class DeployerRenderer
    def initialize(event_log_renderer)
      @event_log_renderer = event_log_renderer
      @index = 0
    end

    def finish(state)
      @event_log_renderer.finish(state)
    end

    def enter_stage(stage, total)
      @stage = stage
      @total = total
      @index = 0
    end

    def update(state, task)
      event = {
        'time'     => Time.now.to_i,
        'stage'    => @stage,
        'task'     => task,
        'tags'     => [],
        'index'    => @index + 1,
        'total'    => @total,
        'state'    => state.to_s,
        'progress' => state == :finished ? 100 : 0,
      }

      @event_log_renderer.add_output(JSON.generate(event))
      @event_log_renderer.refresh

      @index += 1 if state == :finished
    end

    def duration
      @event_log_renderer.duration
    end
  end
end
