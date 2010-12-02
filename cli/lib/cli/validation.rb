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

      def validate(&block)
        @step_callback = block if block_given?
        perform_validation
      rescue ValidationHalted
      ensure
        @validated = true
      end

      def perform_validation
      end

      private

      def step(name, error_message, kind = :non_fatal, &block)
        passed = yield
        if !passed
          errors << error_message
          raise ValidationHalted if kind == :fatal
        end
      ensure
        @step_callback.call(name, passed) if @step_callback
      end
      
    end
  end
end
