module Bosh::HealthMonitor
  module Plugins
    class Reaper < Base
      include Bosh::HealthMonitor::Plugins::HttpRequestHelper

      attr_reader :url

      def initialize(options={})
        super(options)
        @url = URI(@options['director']['endpoint'])
        @url.user = @options['director']['user']
        @url.password = @options['director']['password']
      end

      def run
        unless EM.reactor_running?
          logger.error("Reaper plugin can only be started when event loop is running")
          return false
        end

        logger.info("Reaper is running...")
      end

      def process(event)
        deployment = event.attributes['deployment']
        job = event.attributes['job']
        index = event.attributes['index']

        if deployment && job && index
          payload = {}
          request = { body: Yajl::Encoder.encode(payload) }

          @url.path = "/deployments/#{deployment}/jobs/#{job}/#{index}"
          @url.query = "state=recreate"

          # may need to batch recreation, but this gets called once per event
          # since this is async, we will fail on a second call as there already is a deployment running
          send_http_request('reaper', url.to_s, request)
        else
          logger.warn("event did not have deployment, job and index: #{event}")
        end
      end

    end
  end
end

