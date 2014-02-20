module Bosh::Deployer
  class LoggerRenderer
    attr_accessor :stage, :total, :index

    def initialize(logger)
      @logger = logger
      enter_stage('Deployer', 0)
    end

    def enter_stage(stage, total)
      @stage = stage
      @total = total
      @index = 0
    end

    def update(state, task)
      logger.info("#{@stage} - #{state} #{task}")
      @index += 1 if state == :finished
    end

    private

    attr_reader :logger
  end
end
