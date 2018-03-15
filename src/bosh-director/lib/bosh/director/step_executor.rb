module Bosh::Director
  class StepExecutor
    def initialize(stage_name, agendas, track: true)
      @stage_name = stage_name
      @agendas = agendas
      @logger = Config.logger
      @track = track
    end

    def run
      if @track
        event_log_stage = Config.event_log.begin_stage(@stage_name, @agendas.length)
      end

      ThreadPool.new(max_threads: Config.max_threads).wrap do |pool|
        @agendas.each do |agenda|
          pool.process do
            with_thread_name(agenda.thread_name) do
              if @track
                event_log_stage.advance_and_track(agenda.task_name) do
                  run_agenda(agenda)
                end
              else
                run_agenda(agenda)
              end
            end
          end
        end
      end
    end

    private

    def run_agenda(agenda)
      @logger.info(agenda.info)
      agenda.steps.each do |step|
        start_time = Time.now
        @logger.debug("Agenda step #{step.class} started at: #{start_time}")
        step.perform(agenda.report)
        @logger.debug("Agenda step #{step.class} finished after #{Time.now - start_time}s")
      end
    end
  end
end
