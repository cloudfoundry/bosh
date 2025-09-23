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

        @deploy_config_enabled = Prometheus::Client.registry.gauge(
          :bosh_deploy_config_enabled,
          docstring: 'Is a config of type deploy uploaded? 0 for no, 1 for yes',
        )

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
          raise "Bosh::Director::Models loaded before ensuring migrations are current. Refusing to start #{self.class}."
        end

        begin
          DBMigrator.new(@config.db).ensure_migrated!
        rescue DBMigrator::MigrationsNotCurrentError => e
          @logger.error("#{self.class} start failed: #{e.message}")
          raise e
        end

        require 'bosh/director'
      end

      def populate_metrics
        @logger.info('populating metrics')

        @deploy_config_enabled.set(Api::ConfigManager.deploy_config_enabled? ? 1 : 0)
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
        response = Net::HTTP.get_response('127.0.0.1', '/unresponsive_agents', @config.health_monitor_port)
        return unless response.is_a?(Net::HTTPSuccess)

        unresponsive_agent_counts = JSON.parse(response.body)
        return unless unresponsive_agent_counts.is_a?(Hash)

        existing_deployment_names = @unresponsive_agents.values.map do |key, _|
          # The keys within the Prometheus::Client::Metric#values method are actually hashes. So the
          # data returned from values looks like:
          # { { name: "deployment_a"} => 10, { name: "deployment_b "} => 0, ... }
          key[:name]
        end

        unresponsive_agent_counts.each do |deployment, count|
          @unresponsive_agents.set(count, labels: { name: deployment })
        end

        removed_deployments = existing_deployment_names - unresponsive_agent_counts.keys
        removed_deployments.each do |deployment|
          @unresponsive_agents.set(0, labels: { name: deployment })
        end
      end

      def populate_network_metrics
        configs = Models::Config.latest_set('cloud')
        @network_available_ips.set(0, labels: { name: canonicalize_to_prometheus('no-networks') })
        @network_free_ips.set(0, labels: { name: canonicalize_to_prometheus('no-networks') })
        return if configs.empty?

        consolidated_configs = Bosh::Director::CloudConfig::CloudConfigsConsolidator.new(configs)
        networks = DeploymentPlan::CloudManifestParser.new(@logger).parse(consolidated_configs.raw_manifest).networks
        networks.flatten!

        return if networks.empty?

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
          subnet.restricted_ips.each do |ip_addr_or_cidr|
            total_restricted += ip_addr_or_cidr.count
          end
          total_available += subnet.range.count
        end

        total_available -= total_static
        total_available -= total_restricted
        [total_available, total_available - total_used]
      end
    end
  end
end
