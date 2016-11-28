module Bosh::Cli
  class Resurrection
    def initialize(state)
      @state = state

      validate_state!
    end

    def paused?
      !enabled?
    end

    def enabled?
      %w[true yes on enable].include?(state)
    end

    def disabled?
      %w[false no off disable].include?(state)
    end

    def validate_state!
      unless enabled? || disabled?
        err("Resurrection paused state should be on/off, true/false, yes/no or enable/disable received #{state.inspect}")
      end
    end

    private

    attr_reader :state
  end
end
