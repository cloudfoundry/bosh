module Bosh::Monitor
  class EventProcessor
    attr_reader :plugins

    def initialize
      @events = {}
      @plugins = {}

      @lock   = Mutex.new
      @logger = Bhm.logger
    end

    def add_plugin(plugin, event_kinds = [])
      if plugin.respond_to?(:validate_options) && !plugin.validate_options
        raise FatalError, "Invalid plugin options for '#{plugin.class}'"
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
        @events[kind] ||= {}

        if @events[kind].key?(event.id)
          @logger.debug("Ignoring duplicate #{event.kind} '#{event.id}'")
          return true
        end
        # We don't really need to store event itself for the moment,
        # as we only use its id to dedup new events.
        @events[kind][event.id] = { received_at: Time.now.to_i }
      end

      if @plugins[kind].nil? || @plugins[kind].empty?
        @logger.debug("No plugins are interested in '#{event.kind}' event")
        return true
      end

      @plugins[kind].each do |plugin|
        Async do
          plugin_process(plugin, event)
        end
      end

      true
    end

    def events_count
      # Accumulate event counter over all event kinds
      @lock.synchronize do
        @events.inject(0) do |counter, (_, events)|
          counter + events.size
        end
      end
    end

    def enable_pruning(interval)
      @reaper ||= Thread.new do
        loop do
          # Some events might be in the system up to 2 * interval
          # seconds this way, but it seems to be a reasonable trade-off
          prune_events(interval)
          sleep(interval)
        end
      end
    end

    def prune_events(lifetime)
      @lock.synchronize do
        pruned_count = 0
        total_count = 0

        @events.each_value do |list|
          list.delete_if do |_id, data|
            total_count += 1
            if data[:received_at] <= Time.now.to_i - lifetime
              pruned_count += 1
              true
            else
              false
            end
          end
        end

        @logger.debug("Pruned #{pluralize(pruned_count, 'old event')}")
        @logger.debug("Total #{pluralize(total_count, 'event')}")
      end
    rescue StandardError => e
      @logger.error("Error pruning events: #{e}")
      @logger.error(e.backtrace.join("\n"))
    end

    private

    def plugin_process(plugin, event)
      plugin.process(event)
    rescue Bhm::PluginError => e
      @logger.error("Plugin #{plugin.class} failed to process #{event.kind}: #{e}")
    end
  end
end
