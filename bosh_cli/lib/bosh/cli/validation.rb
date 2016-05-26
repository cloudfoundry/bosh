# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
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
      say("%-60s " % [name], "")

      passed = yield

      say("%s" % [passed ? "OK".make_green : "FAILED".make_red])

      unless passed
        errors << error_message
        raise ValidationHalted if kind == :fatal
      end
    end
  end
end
