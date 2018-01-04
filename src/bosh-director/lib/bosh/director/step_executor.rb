module Bosh::Director
  class StepExecutor
    def initialize(stage_name, agendas)
      @stage_name = stage_name
      @agendas = agendas
      @logger = Config.logger
    end

    def run
      event_log_stage = Config.event_log.begin_stage(@stage_name, @agendas.length)
      ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
        @agendas.each do |agenda|
          pool.process do
            with_thread_name(agenda.thread_name) do
              event_log_stage.advance_and_track(agenda.task_name) do
                @logger.info(agenda.info)
                agenda.steps.each do |step|
                  step.perform(agenda.report)
                end
              end
            end
          end
        end
      end
    end
  end
end
