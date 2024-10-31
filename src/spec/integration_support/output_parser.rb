module IntegrationSupport
  class OutputParser
    attr_reader :output

    def initialize(output)
      @output = output
    end

    def task_id(state = 'done')
      if (match = /Task (?<id>\d+) #{state}/.match(@output))
        match[:id]
      else
        raise "No task ID found with state #{state} in output: #{@output}"
      end
    end
  end
end
