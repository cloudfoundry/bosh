module Bosh::Deployer
  class DeployerRenderer < Bosh::Cli::TaskTracking::EventLogRenderer
    attr_accessor :stage, :total, :index

    DEFAULT_POLL_INTERVAL = 1

    def interval_poll
      Bosh::Cli::Config.poll_interval || DEFAULT_POLL_INTERVAL
    end

    def start
      @thread = Thread.new do
        loop do
          refresh
          sleep(interval_poll)
        end
      end
    end

    def finish(state)
      @thread.kill
      super(state)
    end

    def enter_stage(stage, total)
      @stage = stage
      @total = total
      @index = 0
    end

    def parse_event(event)
      event
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
        'progress' => state == :finished ? 100 : 0
      }

      add_event(event)

      @index += 1 if state == :finished
    end
  end
end
