module IntegrationSupport
  class OutputMatcher
    def initialize(expected_output)
      @expected_output = expected_output
    end

    def matches?(runner)
      raise Errors::InvalidInputError unless runner.respond_to?(:expect)
      @matched = runner.expect(@expected_output)
      @full_output = runner.output
      !!@matched
    end

    def failure_message
      "expected '#{@expected_output}' to be printed, but it wasn't. full output:\n#{@full_output}"
    end

    def failure_message_when_negated
      "expected '#{@expected_output}' to not be printed, but it was. full output:\n#{@full_output}"
    end
  end

  module HaveOutputMatcher
    def have_output(string_or_regexp)
      pattern =
        case string_or_regexp
        when String
          Regexp.new(Regexp.quote(string_or_regexp))
        when Regexp
          string_or_regexp
        else
          raise TypeError, "unsupported pattern class: #{string_or_regexp.class}"
        end

      OutputMatcher.new(pattern)
    end
  end
end

RSpec.configure do |c|
  c.include(IntegrationSupport::HaveOutputMatcher)
end
