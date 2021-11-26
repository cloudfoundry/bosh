# This health monitor plugin should be used in conjunction with another plugin that
# alerts when a VM is unresponsive, as this plugin will try to automatically fix the
# problem by recreating the VM
module Bosh::Monitor
  module Plugins
    class Resurrector < Base
      include HttpRequestHelper
      include Bosh::Monitor::Events

      def initialize(options = {})
        super(options)
        director = @options['director']
        raise ArgumentError 'director options not set' unless director

        @uri                  = URI(director['endpoint'])
        @director_options     = director
        @processor            = Bhm.event_processor
        @resurrection_manager = Bhm.resurrection_manager
        @alert_tracker        = ResurrectorHelper::AlertTracker.new(@options)
      end

      def run
        unless EM.reactor_running?
          logger.error('Resurrector plugin can only be started when event loop is running')
          return false
        end

        logger.info('Resurrector is running...')
      end

      def process(alert)
        category = alert.attributes['category']
        deployment = alert.attributes['deployment']
        jobs_to_instances = alert.attributes['jobs_to_instance_ids']

        unless category == Alert::CATEGORY_DEPLOYMENT_HEALTH
          logger.debug("(Resurrector) ignoring event of category '#{category}': #{alert}")
          return
        end

        unless deployment && jobs_to_instances
          logger.warn("(Resurrector) event did not have deployment and jobs_to_instance_ids: #{alert}")
          return
        end

        each_job_instance(jobs_to_instances) do |job, id|
          agent_key = ResurrectorHelper::JobInstanceKey.new(deployment, job, id)
          @alert_tracker.record(agent_key, alert)
        end

        unless director_info
          logger.error('(Resurrector) director is not responding with the status')
          return
        end

        state = @alert_tracker.state_for(deployment)

        if state.meltdown?
          alert(deployment,
                severity: 1,
                title: 'We are in meltdown',
                summary: "Skipping resurrection for instances: #{pretty_str(jobs_to_instances)}; #{state.summary}")

        elsif state.managed?
          jobs_to_instances_resurrection_enabled, jobs_to_instances_resurrection_disabled =
            split_by_resurrection_enabled(deployment, jobs_to_instances)

          unless jobs_to_instances_resurrection_enabled.empty?
            payload = { 'jobs' => jobs_to_instances_resurrection_enabled }
            request = {
              head: {
                'Content-Type' => 'application/json',
                'authorization' => auth_provider(director_info).auth_header,
              },
              body: JSON.dump(payload),
            }
            url = @uri.dup
            url.path = "/deployments/#{deployment}/scan_and_fix"
            alert(deployment,
                  severity: 4,
                  title: 'Scan unresponsive VMs',
                  summary: 'Notifying Director to scan instances: '\
                  "#{pretty_str(jobs_to_instances_resurrection_enabled)}; #{state.summary}")

            if options['no_proxy'].nil? || use_proxy?(url, options['no_proxy'])
              request[:proxy] = options['http_proxy'] if options.key?('http_proxy')
            end
            send_http_put_request(url.to_s, request)
          end

          unless jobs_to_instances_resurrection_disabled.empty?
            alert(deployment,
                  severity: 1,
                  title: 'Resurrection is disabled by resurrection config',
                  summary: "Skipping resurrection for instances: #{pretty_str(jobs_to_instances_resurrection_disabled)};"\
                  " #{state.summary} because of resurrection config")
          end
        else
          logger.info('(Resurrector) state is normal')
        end
      end

      private

      def auth_provider(director_info)
        @auth_provider ||= AuthProvider.new(director_info, @director_options, logger)
      end

      def director_info
        return @director_info if @director_info

        url = @uri.dup
        url.path = '/info'
        response = send_http_get_request(url.to_s)
        return nil if response.status_code != 200

        @director_info = JSON.parse(response.body)
      end

      def pretty_str(jobs_to_instances)
        pretty_str = ''
        each_job_instance(jobs_to_instances) do |job, id|
          pretty_str += "#{job}/#{id}, "
        end
        pretty_str.chomp(', ')
      end

      def each_job_instance(jobs_to_instances)
        jobs_to_instances.each do |job, instances|
          instances.each do |id|
            yield(job, id)
          end
        end
      end

      def split_by_resurrection_enabled(deployment, jobs_to_instances)
        resurrection_enabled, resurrection_disabled = jobs_to_instances.partition do |job, _|
          @resurrection_manager.resurrection_enabled?(deployment, job)
        end
        [resurrection_enabled.to_h, resurrection_disabled.to_h]
      end

      def alert(deployment, severity:, title:, summary:)
        @processor.process(
          :alert,
          severity: severity,
          title: title,
          summary: summary,
          source: 'HM plugin resurrector',
          deployment: deployment,
          created_at: Time.now.to_i,
        )
      end
    end
  end
end
