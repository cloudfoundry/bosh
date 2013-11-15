module Bosh::Agent::Message
  class Prepare < Base
    def self.process(args)
      new(*args).run
    end

    def initialize(apply_spec)
      @platform = Bosh::Agent::Config.platform
      @apply_spec = apply_spec

      unless @apply_spec.is_a?(Hash)
        raise ArgumentError, "invalid spec, Hash expected, #{@apply_spec.class} given"
      end
    end

    def run
      plan = Bosh::Agent::ApplyPlan::Plan.new(@apply_spec)
      plan.jobs.each(&:prepare_for_install)
      plan.packages.each(&:prepare_for_install)
      {}
    rescue Exception => e
      raise Bosh::Agent::MessageHandlerError, "#{e.inspect}\n#{e.backtrace}"
    end
  end
end
