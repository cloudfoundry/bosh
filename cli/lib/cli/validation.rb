module Bosh
  module Cli

    class ValidationHalted < StandardError; end

    module Validation

      def errors
        @errors ||= []
      end

      def valid?(options = {})
        validate(options) unless @validated
        errors.empty?
      end

      def validate(options = {})
        perform_validation(options)
      rescue ValidationHalted
      ensure
        @validated = true
      end

      def reset_validation
        @validated = nil
        @errors = []
      end

      private

      def step(name, error_message, kind = :non_fatal, &block)
        passed = yield

        say("%-60s %s" % [ name, passed ? "OK".green : "FAILED".red ])

        unless passed
          errors << error_message
          raise ValidationHalted if kind == :fatal
        end
      end

    end
  end
end
