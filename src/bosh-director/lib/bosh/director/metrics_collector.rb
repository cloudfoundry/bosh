require 'db_migrator'
require 'rufus-scheduler'
require 'prometheus/client'
require 'bosh/director/dns/canonicalizer'

module Bosh
  module Director
    class MetricsCollector
      def initialize(config)
        @config = config
        @logger = config.metrics_server_logger

        @resurrection_enabled = Prometheus::Client.registry.gauge(
          :bosh_resurrection_enabled,
          docstring: 'Is resurrection enabled? 0 for disabled, 1 for enabled',
        )

        @tasks = Prometheus::Client.registry.gauge(
          :bosh_tasks_total,
          labels: %i[state type],
          docstring: 'Number of BOSH tasks',
        )

        @network_available_ips = Prometheus::Client.registry.gauge(
          :bosh_networks_dynamic_ips_total,
          labels: %i[name],
          docstring: 'Size of network pool for all dynamically allocated IPs',
        )
        @network_free_ips = Prometheus::Client.registry.gauge(
          :bosh_networks_dynamic_free_ips_total,
          labels: %i[name],
          docstring: 'Number of dynamical free IPs left per network',
        )

        @unresponsive_agents = Prometheus::Client.registry.gauge(
          :bosh_unresponsive_agents,
          labels: %i[name],
          docstring: 'Number of unresponsive agents per deployment',
        )
        @scheduler = Rufus::Scheduler.new
      end

      def prep
        ensure_migrations
        Bosh::Director::App.new(@config)
      end

      def start
        @logger.info('starting metrics collector')

        populate_metrics

        @scheduler.interval '30s' do
          populate_metrics
        end
      end

      def stop
        @logger.info('stopping metrics collector')
        @scheduler.shutdown
      end

      private

      def ensure_migrations
        if defined?(Bosh::Director::Models)
          raise 'Bosh::Director::Models were loaded before ensuring migrations are current. ' \
                'Cowardly refusing to start metrics collector.'
        end

        migrator = DBMigrator.new(@config.db, :director)
        unless migrator.finished?
          @logger.error(
            "Migrations not current during metrics collector start after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} attempts.",
          )
          raise "Migrations not current after #{DBMigrator::MAX_MIGRATION_ATTEMPTS} retries"
        end

        require 'bosh/director'
      end

      def populate_metrics
        @logger.info('populating metrics')

        @resurrection_enabled.set(Api::ResurrectorManager.new.pause_for_all? ? 0 : 1)

        metrics = { 'processing' => {}, 'queued' => {} }
        Models::Task.group_and_count(:type).distinct.each do |task|
          metrics['processing'][task.type] = 0
          metrics['queued'][task.type] = 0
        end

        Models::Task.where(state: %w[processing queued]).group_and_count(:type, :state).each do |task|
          state, type, count = task.values[:state], task.values[:type], task.values[:count]

          metrics[state][type] = count
        end

        metrics.each do |state, types|
          types.each do |type, count|
            @tasks.set(count, labels: { state: state, type: type })
          end
        end

        populate_network_metrics

        populate_vm_metrics

        @logger.info('populated metrics')
      end

      def populate_vm_metrics
        response = Net::HTTP.get_response("127.0.0.1:#{@config.health_monitor_port}", '/unresponsive_agents')
        return unless response.is_a?(Net::HTTPSuccess)

        unresponsive_agent_counts = JSON.parse(response.body)
        return unless unresponsive_agent_counts.is_a?(Hash)

        unresponsive_agent_counts.map do |deployment, count|
          @unresponsive_agents.set(count, labels: { name: deployment })
        end
      end

      def populate_network_metrics
        configs = Models::Config.latest_set('cloud')
        cloud_planners = configs.map do |config|
          DeploymentPlan::CloudManifestParser.new(@logger).parse(YAML.safe_load(config.content))
        end
        networks = cloud_planners.flat_map(&:networks)

        networks.each do |network|
          next unless network.manual?

          total, free = calculate_network_metrics(network)
          @network_available_ips.set(total, labels: { name: canonicalize_to_prometheus(network.name) })
          @network_free_ips.set(free, labels: { name: canonicalize_to_prometheus(network.name) })
        end
      end

      def canonicalize_to_prometheus(label)
        # https://prometheus.io/docs/concepts/data_model/#metric-names-and-labels
        # prometheus supports underscores and not dashes, but dns is reversed
        Canonicalizer.canonicalize(label).gsub('-', '_')
      end

      def calculate_network_metrics(network)
        total_available = 0
        total_static = 0
        total_restricted = 0
        total_used = Models::IpAddress.where(network_name: network.name, static: false).count

        network.subnets.each do |subnet|
          total_static += subnet.static_ips.size
          total_restricted += subnet.restricted_ips.size
          total_available += subnet.range.size
        end

        total_available -= total_static
        total_available -= total_restricted
        [total_available, total_available - total_used]
      end
    end
  end
end
