# This health monitor plugin should be used in conjunction with another plugin that
# alerts when a VM is unresponsive, as this plugin will try to automatically fix the
# problem by recreating the VM
module Bosh::Monitor
  module Plugins
    class Resurrector < Base
      include Bosh::Monitor::Plugins::HttpRequestHelper

      attr_reader :url

      def initialize(options={})
        super(options)
        director = @options['director']
        raise ArgumentError 'director options not set' unless director

        @url              = URI(director['endpoint'])
        @director_options = director
        @processor        = Bhm.event_processor
        @alert_tracker    = ResurrectorHelper::AlertTracker.new(@options)
      end

      def run
        unless EM.reactor_running?
          logger.error("Resurrector plugin can only be started when event loop is running")
          return false
        end

        logger.info("Resurrector is running...")
      end

      def process(alert)
        deployment = alert.attributes['deployment']
        job = alert.attributes['job']
        id = alert.attributes['instance_id']

        # deployment, job, and id are only present for 'agent timed out' and 'vm missing for instance'
        # on the alert so this won't trigger a recreate for other types of alerts
        if deployment && job && id
          agent_key = ResurrectorHelper::JobInstanceKey.new(deployment, job, id)
          @alert_tracker.record(agent_key, alert.created_at)

          payload = {'jobs' => {job => [id]}}

          unless director_info
            logger.error("(Resurrector) director is not responding with the status")
            return
          end

          request = {
              head: {
                  'Content-Type' => 'application/json',
                  'authorization' => auth_provider(director_info).auth_header
              },
              body: Yajl::Encoder.encode(payload)
          }

          @url.path = "/deployments/#{deployment}/scan_and_fix"
          state, details = @alert_tracker.state_for(deployment)

          if state == ResurrectorHelper::AlertTracker::STATE_MELTDOWN
            # freak out
            summary = "Skipping resurrection for instance: '#{job}/#{id}'; deployment: #{deployment}; alerts: #{details['alerts'].inspect}"
            ts = Time.now.to_i
            @processor.process(:alert,
                               severity: 1,
                               title: "We are in meltdown.",
                               summary: summary,
                               source: "HM plugin resurrector",
                               deployment: deployment,
                               created_at: ts)

            logger.error("(Resurrector) we are in meltdown. #{summary}")
          else
            # queue instead, and only queue if it isn't already in the queue
            # what if we can't keep up with the failure rate?
            # - maybe not, maybe the meltdown detection takes care of the rate issue
            logger.warn("(Resurrector) notifying director to recreate unresponsive VM: #{deployment} #{job}/#{id}")

            send_http_put_request(url.to_s, request)
          end

        else
          logger.warn("(Resurrector) event did not have deployment, job and id: #{alert}")
        end
      end

      private

      def auth_provider(director_info)
        @auth_provider ||= AuthProvider.new(director_info, @director_options, logger)
      end

      def director_info
        return @director_info if @director_info

        director_info_url = @url.dup
        director_info_url.path = '/info'
        response = send_http_get_request(director_info_url.to_s)
        return nil if response.status_code != 200

        @director_info = Yajl::Parser.parse(response.body)
      end
    end
  end
end
