module Bosh::HealthMonitor
  class EventProcessor
    def initialize
      @event_ids = {}
      @plugins = {}

      @lock   = Mutex.new
      @logger = Bhm.logger
    end

    def add_plugin(plugin, event_kinds = [])
      if plugin.respond_to?(:validate_options) && !plugin.validate_options
        raise FatalError, "Invalid plugin options for `#{plugin.class}'"
      end

      @lock.synchronize do
        event_kinds.each do |kind|
          kind = kind.to_sym
          @plugins[kind] ||= Set.new
          @plugins[kind] << plugin
        end
        plugin.run
      end
    end

    def process(kind, data)
      kind = kind.to_sym
      event = Bhm::Events::Base.create!(kind, data)

      @lock.synchronize do
        @event_ids[kind] ||= Set.new

        if @event_ids[kind].include?(event.id)
          @logger.debug("Ignoring duplicate #{event.kind} `#{event.id}'")
          return true
        end
        @event_ids[kind] << event.id
      end

      if @plugins[kind].nil? || @plugins[kind].empty?
        @logger.debug("No plugins are interested in `#{event.kind}' event")
        return true
      end

      @plugins[kind].each do |plugin|
        plugin_process(plugin, event)
      end

      true
    end

    def processed_events_count
      @event_ids.inject(0) do |counter, (kind, ids)|
        counter += ids.size
      end
    end

    private

    def plugin_process(plugin, event)
      plugin.process(event)
    rescue Bhm::PluginError => e
      @logger.error("Plugin #{plugin.class} failed to process #{event.kind}: #{e}")
    end
  end
end
