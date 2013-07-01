require 'rspec/core/formatters/base_formatter'
require_relative 'data_dog_reporter'

module Bosh
  module Helpers
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
end
