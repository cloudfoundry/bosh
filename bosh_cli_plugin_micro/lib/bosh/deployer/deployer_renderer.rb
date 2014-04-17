module Bosh::Deployer
  class DeployerRenderer
    DEFAULT_POLL_INTERVAL = 0.1

    def initialize(event_log_renderer)
      @event_log_renderer = event_log_renderer
      @index = 0
    end

    def start
      @thread = Thread.new do
        loop do
          @event_log_renderer.refresh
          sleep(interval_poll)
        end
      end
    end

    def finish(state)
      @thread.kill
      @event_log_renderer.finish(state)
    end

    def enter_stage(stage, total)
      @stage = stage
      @total = total
      @index = 0
    end

    def update(state, task)
      event = {
        'time'     => Time.now,
        'stage'    => @stage,
        'task'     => task,
        'tags'     => [],
        'index'    => @index + 1,
        'total'    => @total,
        'state'    => state.to_s,
        'progress' => state == :finished ? 100 : 0,
      }

      @event_log_renderer.add_output(JSON.generate(event))

      @index += 1 if state == :finished
    end

    def duration
      @event_log_renderer.duration
    end

    private

    def interval_poll
      Bosh::Cli::Config.poll_interval || DEFAULT_POLL_INTERVAL
    end
  end
end
