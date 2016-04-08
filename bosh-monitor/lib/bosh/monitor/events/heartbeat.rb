module Bosh::Monitor
  module Events
    class Heartbeat < Base

      CORE_JOBS = Set.new(%w(cloud_controller dea health_manager nats router routerv2 stager uaa))

      SERVICE_JOBS_PREFIXES = %w(mysql mongodb rabbit postgresql vblob).join("|")
      SERVICE_JOBS_GATEWAY_REGEX = /(#{SERVICE_JOBS_PREFIXES})_gateway$/i
      SERVICE_JOBS_NODE_REGEX = /(#{SERVICE_JOBS_PREFIXES})_node(.*)/i

      SERVICE_AUXILIARY_JOBS = Set.new(%w(serialization_data_server backup_manager))

      attr_reader :agent_id, :deployment, :job, :index, :metrics, :node_id

      def initialize(attributes = {})
        super
        @kind = :heartbeat
        @metrics = []

        @id = @attributes["id"]
        @timestamp = Time.at(@attributes["timestamp"]) rescue @attributes["timestamp"]

        @deployment = @attributes["deployment"]
        @agent_id = @attributes["agent_id"]
        @job = @attributes["job"]
        @index = @attributes["index"].to_s
        @node_id = @attributes["node_id"]
        @job_state = @attributes["job_state"]

        @tags = {}
        @tags["job"] = @job if @job
        @tags["index"] = @index if @index
        @tags["id"] = @node_id if @node_id
        @tags["role"] = guess_role

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
        description = "Heartbeat from #{@job}/#{@node_id} (agent_id=#{@agent_id}"

        if @index && !@index.empty?
          description = description + " index=#{@index}"
        end

        description + ") @ #{@timestamp.utc}"
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
          :node_id => @node_id,
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
        add_metric("system.disk.system.inode_percent", @system_disk["inode_percent"])
        add_metric("system.disk.ephemeral.percent", @ephemeral_disk["percent"])
        add_metric("system.disk.ephemeral.inode_percent", @ephemeral_disk["inode_percent"])
        add_metric("system.disk.persistent.percent", @persistent_disk["percent"])
        add_metric("system.disk.persistent.inode_percent", @persistent_disk["inode_percent"])
        add_metric("system.healthy", @job_state == "running" ? 1 : 0)
      end

      def guess_role
        # Dashboard might want to partition jobs
        # into several buckets, so let's help it
        # by applying a couple of heuristics

        return "core" if CORE_JOBS.include?(@job.to_s.downcase)

        return "service" if SERVICE_AUXILIARY_JOBS.include?(@job.to_s.downcase)

        # job name prefixed by "service"
        if @job.to_s.downcase =~ /^service/i
          return "service"
        end

        # job name suffixed by "_gateway"
        if @job.to_s.downcase =~ SERVICE_JOBS_GATEWAY_REGEX
          return "service"
        end

        # job name contains "_node"
        if @job.to_s.downcase =~ SERVICE_JOBS_NODE_REGEX
          return "service"
        end

        return "unknown"
      end

    end
  end
end
