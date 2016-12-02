module Bosh::Dev
  class EmitableExample
    def initialize(example)
      @example = example
    end

    def metric
      'ci.bosh.bat.duration'
    end

    def value
      run_time
    end

    def options
      { tags: %W[infrastructure:#{ENV.fetch('BAT_INFRASTRUCTURE')} example:#{description}] }
    end

    def to_a
      [metric, value, options]
    end

    private

    attr_reader :example

    def run_time
      example.metadata.fetch(:execution_result).fetch(:run_time)
    end

    def description
      example.metadata.fetch(:full_description).downcase.gsub(/[^a-z0-9]/, '-').squeeze('-').gsub(/^-?(.*?)-?$/, '\1')
    end
  end
end
