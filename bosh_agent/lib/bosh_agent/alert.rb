# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Agent
  class Alert

    ALERT_RETRIES    = 3
    RETRY_PERIOD     = 1 # second
    SEVERITY_CUTOFF  = 5
    DEFAULT_SEVERITY = 2

    # The main area of responsibility for this class is conversion
    # of Monit alert format to BOSH Health Monitor alert format.

    attr_reader :id, :service, :event, :description, :action, :date, :severity

    def self.register(attrs)
      new(attrs).register
    end

    def initialize(attrs)
      unless attrs.is_a?(Hash)
        raise ArgumentError, "#{self.class} expects an attributes Hash as a parameter"
      end

      @logger   = Config.logger
      @nats     = Config.nats
      @agent_id = Config.agent_id
      @state    = Config.state

      @id          = attrs[:id]
      @service     = attrs[:service]
      @event       = attrs[:event]
      @action      = attrs[:action]
      @date        = attrs[:date]
      @description = attrs[:description]
      @severity    = self.calculate_severity
    end

    # As we don't (currently) require ACKs for alerts we might need to
    # send alerts several times in case HM temporarily goes down
    def register
      return if severity >= SEVERITY_CUTOFF || severity <= 0

      ALERT_RETRIES.times do |i|
        EM.add_timer(i * RETRY_PERIOD) do
          send_via_mbus
        end
      end
    end

    def send_via_mbus
      if @state.nil?
        @logger.warn("Unable to send alert: unknown agent state")
        return
      end

      if @state["job"].blank?
        @logger.info("No job, ignoring alert")
        return
      end

      @nats.publish("hm.agent.alert.#{@agent_id}", Yajl::Encoder.encode(converted_alert_data))
    end

    def converted_alert_data
      # INPUT: id, service, event, action, date, description
      # OUTPUT: id, severity, title, summary, created_at (unix timestamp)
      {
        "id"         => @id,
        "severity"   => self.calculate_severity,
        "title"      => self.title,
        "summary"    => @description,
        "created_at" => self.timestamp
      }
    end

    def title
      ips = @state.ips
      service = ips.size > 0 ? "#{@service} (#{ips.sort.join(", ")})" : @service
      "#{service} - #{@event} - #{@action}"
    end

    def timestamp
      Time.rfc822(@date).utc.to_i
    rescue ArgumentError => e
      @logger.warn("Cannot parse monit alert date `#{@date}', using current time instead")
      Time.now.utc.to_i
    end

    def calculate_severity
      known_severity = SEVERITY_MAP[@event.to_s.downcase]
      if known_severity.nil?
        @logger.warn("Unknown monit event name `#{@event}', using default severity #{DEFAULT_SEVERITY}")
        DEFAULT_SEVERITY
      else
        known_severity
      end
    end

    # use same values as syslog
    ALERT = 1
    CRITICAL = 2
    ERROR = 3
    WARNING = 4
    IGNORED = -1
    
    SEVERITY_MAP = {
      "action done" => IGNORED,
      "checksum failed" => CRITICAL,
      "checksum changed" => WARNING,
      "checksum succeeded" => IGNORED,
      "checksum not changed" => IGNORED,
      "connection failed" => ALERT,
      "connection succeeded" => IGNORED,
      "connection changed" => ERROR,
      "connection not changed" => IGNORED,
      "content failed" => ERROR,
      "content succeeded" => IGNORED,
      "content match" => IGNORED,
      "content doesn't match" => ERROR,
      "data access error" => ERROR,
      "data access succeeded" => IGNORED,
      "data access changed" => WARNING,
      "data access not changed" => IGNORED,
      "execution failed" => ALERT,
      "execution succeeded" => IGNORED,
      "execution changed" => WARNING,
      "execution not changed" => IGNORED,
      "filesystem flags failed" => ERROR,
      "filesystem flags succeeded" => IGNORED,
      "filesystem flags changed" => WARNING,
      "filesystem flags not changed" => IGNORED,
      "gid failed" => ERROR,
      "gid succeeded" => IGNORED,
      "gid changed" => WARNING,
      "gid not changed" => IGNORED,
      "heartbeat failed" => ERROR,
      "heartbeat succeeded" => IGNORED,
      "heartbeat changed" => WARNING,
      "heartbeat not changed" => IGNORED,
      "icmp failed" => CRITICAL,
      "icmp succeeded" => IGNORED,
      "icmp changed" => WARNING,
      "icmp not changed" => IGNORED,
      "monit instance failed" => ALERT,
      "monit instance succeeded" => IGNORED,
      "monit instance changed" => IGNORED,
      "monit instance not changed" => IGNORED,
      "invalid type" => ERROR,
      "type succeeded" => IGNORED,
      "type changed" => WARNING,
      "type not changed" => IGNORED,
      "does not exist" => ALERT,
      "exists" => IGNORED,
      "existence changed" => WARNING,
      "existence not changed" => IGNORED,
      "permission failed" => ERROR,
      "permission succeeded" => IGNORED,
      "permission changed" => WARNING,
      "permission not changed" => IGNORED,
      "pid failed" => CRITICAL,
      "pid succeeded" => IGNORED,
      "pid changed" => WARNING,
      "pid not changed" => IGNORED,
      "ppid failed" => CRITICAL,
      "ppid succeeded" => IGNORED,
      "ppid changed" => WARNING,
      "ppid not changed" => IGNORED,
      "resource limit matched" => ERROR,
      "resource limit succeeded" => IGNORED,
      "resource limit changed" => WARNING,
      "resource limit not changed" => IGNORED,
      "size failed" => ERROR,
      "size succeeded" => IGNORED,
      "size changed" => ERROR,
      "size not changed" => IGNORED,
      "timeout" => CRITICAL,
      "timeout recovery" => IGNORED,
      "timeout changed" => WARNING,
      "timeout not changed" => IGNORED,
      "timestamp failed" => ERROR,
      "timestamp succeeded" => IGNORED,
      "timestamp changed" => WARNING,
      "timestamp not changed" => IGNORED,
      "uid failed" => CRITICAL,
      "uid succeeded" => IGNORED,
      "uid changed" => WARNING,
      "uid not changed" => IGNORED
    }
  end
end
