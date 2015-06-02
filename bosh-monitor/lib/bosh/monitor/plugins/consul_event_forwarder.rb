# Consul Bosh Monitor Plugin
# Forwards alert and heartbeat messages as events to a consul agent
module Bosh::Monitor
  module Plugins
    class ConsulEventForwarder < Base
      include Bosh::Monitor::Plugins::HttpRequestHelper

      CONSUL_REQUEST_HEADER  = { 'Content-Type' => 'application/javascript' }
      TTL_STATUS_MAP         = { 'running' => :pass, 'failing' => :fail, 'unknown' => :fail, 'default' => :warn }
      REQUIRED_OPTIONS       = ["host", "port", "protocol" ]
      CONSUL_MAX_EVENT_BYTESIZE = 512

      CONSUL_ENDPOINTS = {
        event:     "/v1/event/fire/",              #fire an event
        register:   "/v1/agent/check/register",    #register a check
        deregister: "/v1/agent/check/deregister/", #deregister a check
        pass:       "/v1/agent/check/pass/",       #mark a check as passing
        warn:       "/v1/agent/check/warn/",       #mark a check as warning
        fail:       "/v1/agent/check/fail/"        #mark a check as failing
      }

      def run
        @checklist       = []
        @host            = options['host']
        @namespace       = options['namespace']
        @port            = options['port']
        @protocol        = options['protocol']
        @params          = options['params']
        @ttl             = options['ttl']
        @use_events      = options['events']
        @ttl_note        = options['ttl_note']

        @heartbeats_as_alerts = options['heartbeats_as_alerts']
        @use_ttl              = !@ttl.nil?

        @status_map = Hash.new(:warn)
        @status_map.merge!(TTL_STATUS_MAP)

        logger.info("Consul Event Forwarder plugin is running...")
      end

      def validate_options
        valid_array = REQUIRED_OPTIONS.map{ |o| options[o].to_s.empty? }
        !valid_array.include?(true)
      end

      def process(event)
        validate_options && forward_event(event)
      end

      private

      def consul_uri(event, note_type)
        path = get_path_for_note_type(event, note_type)
        URI.parse("#{@protocol}://#{@host}:#{@port}#{path}?#{@params}")
      end

      #heartbeats get forwarded as ttl checks and alerts get forwarded as events
      #if heartbeat_as_alert is true than a heartbeat gets forwarded as events as well
      def forward_event(event)

        if forward_this_event?(event)
          notify_consul(event, :event)
        end

        if forward_this_ttl?(event)
          event_unregistered?(event) ? notify_consul(event, :register, registration_payload(event)) : notify_consul(event, :ttl)
        end

      end

      #should an individual alert or heartbeat be forwarded as a consul event
      def forward_this_event?(event)
        @use_events && ( event.is_a?(Bosh::Monitor::Events::Alert) || ( event.is_a?(Bosh::Monitor::Events::Heartbeat) && @heartbeats_as_alerts) )
      end

      def forward_this_ttl?(event)
         @use_ttl && event.is_a?(Bosh::Monitor::Events::Heartbeat)
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
            "#{@namespace}#{event.job}"
          when Bosh::Monitor::Events::Alert
            event_label = event.title.downcase.gsub(" ","_")
            "#{@namespace}#{event_label}"
          else
            #Something we haven't encountered yet
            "#{@namespace}event"
        end
      end

      def label_for_ttl(event)
        "#{@namespace}#{event.job}"
      end

      # Notify consul of an event
      # note_type: the type of notice we are sending (:event, :ttl, :register)
      # message:   an optional body for the message, event.json is used by default
      def notify_consul(event, note_type, message=nil)
        body    = message.nil? ? right_sized_body_for_consul(event).to_json : message.to_json
        uri     = consul_uri(event, note_type)

        request = { :body => body }

        send_http_put_request(uri , request)

        #if a registration request returns without error we log it
        #we don't want to send extra registrations
        @checklist << event.job if note_type == :register
      rescue => e
        logger.error("Could not forward event to Consul Cluster @#{@host}: #{e.inspect}")
      end

      #consul limits event payload to < 512 bytes, unfortunately we have to do some pruning so this limit is not as likely to be reached
      #this is suboptimal but otherwise the event post will fail, and how do we decide what data isn't important?
      def right_sized_body_for_consul(event)
        body = event.to_hash
        if event.is_a?(Bosh::Monitor::Events::Heartbeat)
          vitals = body[:vitals]
          #currently assuming the event hash details are always put together in the same order
          #this should yield consistent results from the values method
          {
            :agent  => body[:agent_id],
            :name   => "#{body[:job]}/#{body[:index]}",
            :state  => "#{body[:job_state]}",
            :data   => {
                :cpu => vitals['cpu'].values,
                :dsk => {
                  :eph => vitals['disk']['ephemeral'].values,
                  :sys => vitals['disk']['system'].values,
                },
                :ld  => vitals['load'],
                :mem => vitals['mem'].values,
                :swp => vitals['swap'].values
            }
          }
        else
          body
        end
      end

      #Has this process not encountered a specific ttl check yet?
      #We keep track so we aren't sending superfluous registrations
      #Only register ttl for events that have a job assigned
      def event_unregistered?(event)
        @use_ttl && event.respond_to?(:job) && !@checklist.include?(event.job)
      end

      def registration_payload(event)
        { "name"  => label_for_ttl(event), "notes" => @ttl_note, "ttl" => @ttl }
      end

    end
  end
end
