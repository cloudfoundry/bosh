module Bosh::Monitor
  module Plugins
    class EventLogger < Base
      include Bosh::Monitor::Plugins::HttpRequestHelper

      attr_reader :url

      def initialize(options = {})
        super(options)
        director = @options['director']
        raise ArgumentError 'director options not set' unless director

        @url              = URI(director['endpoint'])
        @director_options = director
        @processor        = Bhm.event_processor
        #  @director         = Bhm.director
      end

      def run
        unless ::Async::Task.current?
          logger.error('Event logger plugin can only be started when event loop is running')
          return false
        end

        logger.info('Event logger is running...')
      end

      def process(alert)
        deployment  = alert.attributes['deployment']
        job         = alert.attributes['job']
        id          = alert.attributes['instance_id']
        instance    = job.nil? || id.nil? ? nil : "#{job}/#{id}"
        timestamp   = alert.attributes['created_at'] || Time.new
        action      = 'create'
        object_type = 'alert'
        object_name = alert.id
        context     = { message: "#{alert.title}. #{alert}" }

        payload =
          {
            'timestamp' => timestamp.to_i.to_s,
            'action' => action,
            'object_type' => object_type,
            'object_name' => object_name,
            'deployment' => deployment,
            'instance' => instance,
            'context' => context,
          }

        unless director_info
          logger.error('(Event logger) director is not responding with the status')
          return
        end

        request = {
          head: {
            'Content-Type' => 'application/json',
            'authorization' => auth_provider(director_info).auth_header,
          },
          body: JSON.dump(payload),
        }

        @url.path = '/events'

        logger.info("(Event logger) notifying director about event: #{alert}")

        request[:proxy] = options['http_proxy'] if options['http_proxy']

        send_http_post_request(@url.to_s, request)
      end

      private

      def auth_provider(director_info)
        @auth_provider ||= AuthProvider.new(director_info, @director_options, logger)
      end

      def director_info
        return @director_info if @director_info

        director_info_url = @url.dup
        director_info_url.path = '/info'
        body, status = send_http_get_request_synchronous(director_info_url.to_s)
        return nil if status != 200

        @director_info = JSON.parse(body)
      end
    end
  end
end
