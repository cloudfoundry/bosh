module Bosh::HealthMonitor

  class AlertProcessor

    def self.plugin_available?(plugin)
      [ "email", "silent" ].include?(plugin.to_s)
    end

    def self.find(plugin, options = { })
      impl = \
      case plugin.to_s
      when "email"
        Bosh::HealthMonitor::EmailAlertProcessor
      else
        Bosh::HealthMonitor::SilentAlertProcessor
      end

      processor = impl.new(options)

      if processor.respond_to?(:validate_options) && !processor.validate_options
        raise AlertProcessingError, "Invalid options for `#{processor.class}'"
      end

      processor

    end

  end

end
