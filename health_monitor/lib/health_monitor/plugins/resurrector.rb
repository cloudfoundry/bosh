# This health monitor plugin should be used in conjunction with another plugin that
# alerts when a VM is unresponsive, as this plugin will try to automatically fix the
# problem by recreating the VM
module Bosh::HealthMonitor
  module Plugins
    class Resurrector < Base
      include Bosh::HealthMonitor::Plugins::HttpRequestHelper

      attr_reader :url

      def initialize(options={})
        super(options)
        director = @options['director']
        raise ArgumentError 'director options not set' unless director
        @url = URI(director['endpoint'])
        @user = director['user']
        @password = director['password']
      end

      def run
        unless EM.reactor_running?
          logger.error("Resurrector plugin can only be started when event loop is running")
          return false
        end

        logger.info("Resurrector is running...")
      end

      def process(event)
        deployment = event.attributes['deployment']
        job = event.attributes['job']
        index = event.attributes['index']

        # only when the agent times out do we add deployment, job & index to the alert
        # attributes, so this won't trigger a recreate for other types of alerts
        if deployment && job && index
          payload = {'jobs' => {job => [index]}}
          request = {
              head: {
                  'Content-Type' => 'application/json',
                  'authorization' => [@user, @password]
              },
              body: Yajl::Encoder.encode(payload)
          }

          @url.path = "/deployments/#{deployment}/scan_and_fix"

          # TODO may need to batch recreation, but this gets called once per event since this
          # is async, we will fail on a second call as there already is a deployment running
          logger.warn("notifying director to recreate unresponsive VM: #{deployment} #{job}/#{index}")

          # queue instead, and only queue if it isn't already in the queue
          # what if we can't keep up with the failure rate?
          send_http_put_request(url.to_s, request)
        else
          logger.warn("event did not have deployment, job and index: #{event}")
        end
      end

    end
  end
end

