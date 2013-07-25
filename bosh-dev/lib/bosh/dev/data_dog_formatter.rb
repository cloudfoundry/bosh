require 'rspec/core/formatters/base_formatter'
require 'bosh/dev/data_dog_reporter'

module Bosh::Dev
  class DataDogFormatter < RSpec::Core::Formatters::BaseFormatter
    def initialize(output, reporter = DataDogReporter.new)
      super(output)
      @reporter = reporter
    end

    def example_passed(example)
      reporter.report_on(example)
    end

    private

    attr_reader :reporter
  end
end
