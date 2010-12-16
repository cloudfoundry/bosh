module Bosh
  module Cli

    class ValidationHalted < StandardError; end
    
    module Validation

      def errors
        @errors ||= []
      end

      def valid?
        validate unless @validated
        errors.empty?        
      end

      def validate
        perform_validation
      rescue ValidationHalted
      ensure
        @validated = true
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
