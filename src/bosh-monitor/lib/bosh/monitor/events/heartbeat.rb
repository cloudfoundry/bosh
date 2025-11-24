module Bosh::Monitor
  module Events
    class Heartbeat < Base
      attr_reader :agent_id, :deployment, :job, :index, :metrics, :instance_id, :teams

      def initialize(attributes = {})
        super
        @kind = :heartbeat
        @metrics = []

        @id = @attributes['id']
        @timestamp = begin
                       Time.at(@attributes['timestamp'])
                     rescue StandardError
                       @attributes['timestamp']
                     end

        @deployment = @attributes['deployment']
        @agent_id = @attributes['agent_id']
        @job = @attributes['job']
        @index = @attributes['index'].to_s
        @instance_id = @attributes['instance_id']
        @job_state = @attributes['job_state']
        @teams = @attributes['teams']

        @tags = {}
        @tags['job'] = @job if @job
        @tags['index'] = @index if @index
        @tags['id'] = @instance_id if @instance_id

        @vitals = @attributes['vitals'] || {}
        @load = @vitals['load'] || []
        @cpu = @vitals['cpu'] || {}
        @mem = @vitals['mem'] || {}
        @swap = @vitals['swap'] || {}
        @disk = @vitals['disk'] || {}
        @system_disk = @disk['system'] || {}
        @ephemeral_disk = @disk['ephemeral'] || {}
        @persistent_disk = @disk['persistent'] || {}

        populate_metrics
      end

      def validate
        add_error('id is missing') if @id.nil?
        add_error('timestamp is missing') if @timestamp.nil?

        add_error('timestamp is invalid') if @timestamp && !@timestamp.is_a?(Time)
      end

      def add_metric(name, value)
        @metrics << Metric.new(name, value, @timestamp.to_i, @tags) if value
      end

      def short_description
        description = "Heartbeat from #{@job}/#{@instance_id} (agent_id=#{@agent_id}"

        description += " index=#{@index}" if @index && !@index.empty?

        description + ") @ #{@timestamp.utc}"
      end

      def to_s
        short_description
      end

      def to_hash
        result = {
          kind: 'heartbeat',
          id: @id,
          timestamp: @timestamp.to_i,
          deployment: @deployment,
          agent_id: @agent_id,
          job: @job,
          index: @index,
          instance_id: @instance_id,
          job_state: @job_state,
          vitals: @vitals,
          teams: @teams,
          metrics: @metrics.map(&:to_hash),
        }
        # Include process_length if present in attributes
        result[:process_length] = @attributes['process_length'] if @attributes.key?('process_length')
        result
      end

      def to_json(*_args)
        JSON.dump(to_hash)
      end

      def to_plain_text
        short_description
      end

      private

      def populate_metrics
        add_metric('system.load.1m', @load[0]) if @load.is_a?(Array)
        add_metric('system.cpu.user', @cpu['user'])
        add_metric('system.cpu.sys', @cpu['sys'])
        add_metric('system.cpu.wait', @cpu['wait'])
        add_metric('system.mem.percent', @mem['percent'])
        add_metric('system.mem.kb', @mem['kb'])
        add_metric('system.swap.percent', @swap['percent'])
        add_metric('system.swap.kb', @swap['kb'])
        add_metric('system.disk.system.percent', @system_disk['percent'])
        add_metric('system.disk.system.inode_percent', @system_disk['inode_percent'])
        add_metric('system.disk.ephemeral.percent', @ephemeral_disk['percent'])
        add_metric('system.disk.ephemeral.inode_percent', @ephemeral_disk['inode_percent'])
        add_metric('system.disk.persistent.percent', @persistent_disk['percent'])
        add_metric('system.disk.persistent.inode_percent', @persistent_disk['inode_percent'])
        add_metric('system.healthy', @job_state == 'running' ? 1 : 0)
      end
    end
  end
end
