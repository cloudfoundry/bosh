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
        index = alert.attributes['index']

        # only when the agent times out do we add deployment, job & index to the alert
        # attributes, so this won't trigger a recreate for other types of alerts
        if deployment && job && index
          agent_key = ResurrectorHelper::JobInstanceKey.new(deployment, job, index)
          @alert_tracker.record(agent_key, alert.created_at)

          payload = {'jobs' => {job => [index]}}

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

          if @alert_tracker.melting_down?(deployment)
            # freak out
            ts = Time.now.to_i
            @processor.process(:alert,
                               severity: 1,
                               source: "HM plugin resurrector",
                               title: "We are in meltdown.",
                               created_at: ts)

            logger.error("(Resurrector) we are in meltdown.")
          else
            # queue instead, and only queue if it isn't already in the queue
            # what if we can't keep up with the failure rate?
            # - maybe not, maybe the meltdown detection takes care of the rate issue
            logger.warn("(Resurrector) notifying director to recreate unresponsive VM: #{deployment} #{job}/#{index}")

            send_http_put_request(url.to_s, request)
          end

        else
          logger.warn("(Resurrector) event did not have deployment, job and index: #{alert}")
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

