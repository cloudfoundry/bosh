module Bosh::HealthMonitor
  module Events
    class Heartbeat < Base

      attr_reader :metrics

      def initialize(attributes = {})
        super
        @kind = :heartbeat
        @metrics = []

        @id = @attributes["id"]
        @timestamp = Time.at(@attributes["timestamp"]) rescue @attributes["timestamp"]

        @deployment = @attributes["deployment"]
        @agent_id = @attributes["agent_id"]
        @job = @attributes["job"]
        @index = @attributes["index"]
        @job_state = @attributes["job_state"]

        @tags = { "job" => @job, "index" => @index }

        @vitals = @attributes["vitals"] || {}
        @load = @vitals["load"] || []
        @cpu = @vitals["cpu"] || {}
        @mem = @vitals["mem"] || {}
        @swap = @vitals["swap"] || {}
        @disk = @vitals["disk"] || {}
        @system_disk = @disk["system"] || {}
        @ephemeral_disk = @disk["ephemeral"] || {}
        @persistent_disk = @disk["persistent"] || {}

        populate_metrics
      end

      def validate
        add_error("id is missing") if @id.nil?
        add_error("timestamp is missing") if @timestamp.nil?

        if @timestamp && !@timestamp.kind_of?(Time)
          add_error("timestamp is invalid")
        end
      end

      def add_metric(name, value)
        @metrics << Metric.new(name, value, @timestamp.to_i, @tags) if value
      end

      def short_description
        "Heartbeat from #{@job}/#{@index} (#{@agent_id}) @ #{@timestamp.utc}"
      end

      def to_s
        self.short_description
      end

      def to_hash
        {
          :kind => "heartbeat",
          :id => @id,
          :timestamp => @timestamp.to_i,
          :deployment => @deployment,
          :agent_id => @agent_id,
          :job => @job,
          :index => @index,
          :job_state => @job_state,
          :vitals => @vitals
        }
      end

      def to_json
        Yajl::Encoder.encode(self.to_hash)
      end

      def to_plain_text
        self.short_description
      end

      private

      def populate_metrics
        add_metric("system.load.1m", @load[0]) if @load.kind_of?(Array)
        add_metric("system.cpu.user", @cpu["user"])
        add_metric("system.cpu.sys", @cpu["sys"])
        add_metric("system.cpu.wait", @cpu["wait"])
        add_metric("system.mem.percent", @mem["percent"])
        add_metric("system.mem.kb", @mem["kb"])
        add_metric("system.swap.percent", @swap["percent"])
        add_metric("system.swap.kb", @swap["kb"])
        add_metric("system.disk.system.percent", @system_disk["percent"])
        add_metric("system.disk.ephemeral.percent", @ephemeral_disk["percent"])
        add_metric("system.disk.persistent.percent", @persistent_disk["percent"])
        add_metric("system.healthy", @job_state == "running" ? 1 : 0)
      end

    end
  end
end
