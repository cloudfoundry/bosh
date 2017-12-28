module Bosh::Director
  class StepExecutor
    def initialize(stage_name, steps_for_state)
      @stage_name = stage_name
      @steps_for_state = steps_for_state
      @logger = Config.logger
    end

    def run
      event_log_stage = Config.event_log.begin_stage(@stage_name, @steps_for_state.length)
      ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
        @steps_for_state.each do |state_object, steps|
          pool.process do
            with_thread_name(state_object.thread_name) do
              event_log_stage.advance_and_track(state_object.task_name) do
                @logger.info(state_object.info)
                steps.each do |step|
                  step.perform(state_object.state)
                end
              end
            end
          end
        end
      end
    end
  end
end
