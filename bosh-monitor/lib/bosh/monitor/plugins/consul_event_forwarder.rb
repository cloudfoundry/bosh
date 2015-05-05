# Consul Bosh Monitor Plugin
# Forwards alert and heartbeat messages as events to a consul agent
module Bosh::Monitor
  module Plugins
    class ConsulEventForwarder < Base
      include Bosh::Monitor::Plugins::HttpRequestHelper

      DEFAULT_PORT           = '8500'
      DEFAULT_PROTOCOL       = 'http'
      DEFAULT_TTL_NOTE       = "Automatically Registered by BOSH-MONITOR"
      CONSUL_REQUEST_HEADER  = { 'Content-Type' => 'application/javascript' }
      TTL_STATUS_MAP         = { 'running' => :pass, 'failing' => :fail, 'unknown' => :fail, 'default' => :warn }

      CONSUL_ENDPOINTS = {
        event:     "/v1/event/fire/",              #fire and event
        register:   "/v1/agent/check/register",    #register a check
        deregister: "/v1/agent/check/deregister/", #deregister a check
        pass:       "/v1/agent/check/pass/",       #mark a check as passing
        warn:       "/v1/agent/check/warn/",       #mark a check as warning
        fail:       "/v1/agent/check/fail/"        #mark a check as failing
      }

      def run
        @checklist       = []
        @host            = options['host']            || ""
        @namespace       = options['namespace']       || ""
        @port            = options['port']            || DEFAULT_PORT
        @protocol        = options['protocol']        || DEFAULT_PROTOCOL
        @params          = options['params']
        @ttl             = options['ttl']
        @use_events      = options['events']          || false
        @ttl_note        = options['ttl_note']        || DEFAULT_TTL_NOTE

        @use_ttl            = !@ttl.nil?

        @status_map = Hash.new(:warn)
        @status_map.merge!(TTL_STATUS_MAP)

        logger.info("Consul Event Forwarder plugin is running...")
      end

      def validate_options
        !(options['host'].nil? || options['host'].empty?)
      end

      def process(event)
        validate_options && forward_event(event)
      end

      private

      def consul_uri(event, note_type)
        path = get_path_for_note_type(event, note_type)
        URI.parse("#{@protocol}://#{@host}:#{@port}#{path}?#{@params}")
      end

      def forward_event(event)
        notify_consul(event, :event)  if @use_events

        if event_unregistered?(event)
          notify_consul(event, :register, registration_payload(event))
        elsif @use_ttl
          notify_consul(event, :ttl)
        end
      end

      def get_path_for_note_type(event, note_type)
        case note_type
        when :event
          CONSUL_ENDPOINTS[:event] + label_for_event(event)
        when :ttl
          job_state = event.attributes['job_state']
          status_id = @status_map[job_state]
          CONSUL_ENDPOINTS[status_id] + label_for_ttl(event)
        when :register
          CONSUL_ENDPOINTS[:register]
        end
      end

      def label_for_event(event)
        case event
          when Bosh::Monitor::Events::Heartbeat
            "#{event.job}_heartbeat"
          when Bosh::Monitor::Events::Alert
            event_label = event.title.downcase.gsub(" ","_")
            "#{event_label}_alert"
          else
            "event"
        end
      end

      def label_for_ttl(event)
        "#{@namespace}#{event.job}"
      end

      # Notify consul of an event
      # note_type: the type of notice we are sending (:event, :ttl, :register)
      # message:   an optional body for the message, event.json is used by default
      def notify_consul(event, note_type, message=nil)
        body    = message.nil? ? event.to_json : message.to_json
        uri     = consul_uri(event, note_type)
        request = { :body => body }
        send_http_put_request(uri , request)

        #if a registration request returns without error we log it
        #we don't want to send extra registrations
        @checklist << event.job if note_type == :register
      rescue => e
        logger.error("Could not forward event to Consul Cluster @#{@host}: #{e.inspect}")
      end

      #Has this process not encountered a specific ttl check yet?
      #We keep track so we aren't sending superfluous registrations
      #Only register ttl for events that have a job assigned
      def event_unregistered?(event)
        @use_ttl && event.respond_to?(:job) && !@checklist.include?(event.job)
      end

      def registration_payload(event)
        name = "#{@namespace}#{event.job}"
        { "name"  => name, "notes" => @ttl_note, "ttl" => @ttl }
      end

    end
  end
end
